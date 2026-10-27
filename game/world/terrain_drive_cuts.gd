extends RefCounted
## Refine only blasted 8 m cells, sampling the original piecewise-linear field.
## The fine lattice preserves the coarse tetrahedral surface at patch boundaries.
const Ring = preload("res://world/terrain_drive_ring.gd")
const Mesher = preload("res://world/tetra_mesher.gd")
const Recipe = preload("res://world/sdf_recipe.gd")
var source: RefCounted
var cuts: Array=[]
var samples := {}
var field_cache := preload("res://world/sdf_field_cache.gd").new()
var flat_vertices := PackedVector3Array()
var column_parts := {}
var column_recipes := {}
var profile := {}
var triangle_cells: Array[Vector3i]=[]
var triangle_columns: Array[Vector2i]=[]
var base_extents := {}
var cell_parts := {}
var cell_recipes := {}

func prepare_base(data: Dictionary) -> void:
	if not triangle_cells.is_empty(): return
	var vertices: PackedVector3Array=data.vertices
	flat_vertices.resize(vertices.size())
	for i in vertices.size(): flat_vertices[i]=Ring.Frame.coordinates(vertices[i]) if source.curve_to_ring else vertices[i]
	for i in range(0,data.indices.size(),3):
		var a := flat_vertices[data.indices[i]];var b := flat_vertices[data.indices[i+1]];var c := flat_vertices[data.indices[i+2]]
		var cell := Vector3i(((a+b+c)/24).floor())
		var column := Vector2i(cell.x,cell.z)
		triangle_cells.append(cell);triangle_columns.append(column)
		var extent: Vector2=base_extents.get(column,Vector2(INF,-INF))
		base_extents[column]=Vector2(minf(extent.x,minf(a.y,minf(b.y,c.y))),maxf(extent.y,maxf(a.y,maxf(b.y,c.y))))

func lattice(p: Vector3) -> float:
	var key := Vector3i(p)
	if not samples.has(key): samples[key]=Recipe.compose(p,source.base_field(p,3,0),source.features)
	return samples[key]

func base_sample(p: Vector3) -> float:
	var cell := (p/8).floor()*8
	var f := (p-cell)/8
	var first := 0;var middle := 1;var last := 2
	if f[first]<f[middle]: var swap := first;first=middle;middle=swap
	if f[middle]<f[last]: var swap := middle;middle=last;last=swap
	if f[first]<f[middle]: var swap := first;first=middle;middle=swap
	var b := cell;b[first]+=8
	var c := b;c[middle]+=8
	return lattice(cell)*(1-f[first])+lattice(b)*(f[first]-f[middle])+lattice(c)*(f[middle]-f[last])+lattice(cell+Vector3.ONE*8)*f[last]

func cached_base(p: Vector3, _radius: float, _rough: float) -> float:
	return base_sample(p)

func sample(p: Vector3) -> float:
	return Recipe.compose(p,base_sample(p),cuts)

func rebuild(data: Dictionary, key: Vector2i) -> Dictionary:
	var relevant := []
	for feature in cuts:
		if edit_bounds(feature).intersects(Rect2(Vector2(key)*200,Vector2.ONE*200).grow(1)): relevant.append(feature)
	cuts=relevant
	if cuts.is_empty(): return data
	for cut in cuts:
		if cut.kind!="carve": return rebuild_columns(data,key)
	var cells := {}
	for cut in cuts:
		var centre := Vector3(cut.x,cut.y,cut.z)
		var lo := Vector3i(((centre-Vector3.ONE*(cut.radius+.5))/8).floor())
		var hi := Vector3i(((centre+Vector3.ONE*(cut.radius+.5))/8).floor())
		for z in range(lo.z,hi.z+1):
			for x in range(lo.x,hi.x+1):
				if floori(x*8.0/200)!=key.x or floori(z*8.0/200)!=key.y: continue
				for y in range(lo.y,hi.y+1): cells[Vector3i(x,y,z)]=true
	if cells.is_empty(): return data
	prepare_base(data)
	var vertices: PackedVector3Array=data.vertices.duplicate()
	var indices := PackedInt32Array()
	for i in range(0,data.indices.size(),3):
		var cell := triangle_cells[i/3]
		if not cells.has(cell):
			for j in 3: indices.append(data.indices[i+j])
	var normals: PackedVector3Array=data.normals.duplicate()
	var ordered := cuts
	for cell in cells:
		var area := Rect2(Vector2(cell.x,cell.z)*8,Vector2.ONE*8).grow(.1)
		cuts=[]
		for feature in ordered:
			if not feature.get("localized",false) or Recipe.bounds(feature).intersects(area): cuts.append(feature)
		var patch: Dictionary
		if cell_parts.has(cell) and cell_recipes[cell]==cuts:
			patch=cell_parts[cell]
		else:
			patch=Mesher.build(sample,Vector3(cell)*8,Vector3i.ONE*4,2.0)
			if source.curve_to_ring: Ring.warp_mesh(patch)
			cell_parts[cell]=patch;cell_recipes[cell]=cuts.duplicate(true)
		var offset := vertices.size()
		vertices.append_array(patch.vertices);normals.append_array(patch.normals)
		for index in patch.indices: indices.append(index+offset)
	cuts=ordered
	for cell in cell_parts.keys():
		if not cells.has(cell): cell_parts.erase(cell);cell_recipes.erase(cell)
	var result := data.duplicate()
	result.vertices=vertices;result.normals=normals;result.indices=indices
	# Simplification must not fill a small crater back in at distance.
	result.render_lods={};result.cached=false
	return result

static func edit_bounds(feature: Dictionary) -> Rect2:
	if feature.kind in ["hill","lower","mountain","carve"]:
		return Rect2(Vector2(feature.x,feature.z)-Vector2.ONE*(feature.radius+2),Vector2.ONE*(feature.radius+2)*2)
	return Recipe.bounds(feature)

func rebuild_columns(data: Dictionary, key: Vector2i) -> Dictionary:
	var started := Time.get_ticks_usec()
	var rebuilt := 0;var reused := 0;var base_calls := 0
	var columns := {}
	for feature in cuts:
		var bounds := edit_bounds(feature)
		var lo := Vector2i((bounds.position/8).floor());var hi := Vector2i((bounds.end/8).floor())
		for z in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				if floori(x*8.0/200)==key.x and floori(z*8.0/200)==key.y: columns[Vector2i(x,z)]=Vector2(INF,-INF)
	var vertices: PackedVector3Array=data.vertices.duplicate()
	prepare_base(data)
	var indices := PackedInt32Array()
	for i in range(0,data.indices.size(),3):
		var column := triangle_columns[i/3]
		if columns.has(column):
			columns[column]=base_extents[column]
		else:
			for j in 3: indices.append(data.indices[i+j])
	var normals: PackedVector3Array=data.normals.duplicate()
	var ordered := cuts
	for column in columns:
		var area := Rect2(Vector2(column)*8,Vector2.ONE*8).grow(.1)
		cuts=[]
		for feature in ordered:
			if edit_bounds(feature).intersects(area): cuts.append(feature)
		var extent: Vector2=columns[column]
		if not is_finite(extent.x):
			var height: float=source.surface_height(Vector2(column)*8+Vector2.ONE*4)
			extent=Vector2(height-8,height+8)
		var displacement := 0.0
		for feature in cuts:
			if feature.kind in ["hill","lower"]: displacement+=float(feature.get("amount",feature.height))
			elif feature.kind=="mountain": displacement+=float(feature.height)
			else:
				extent.x=minf(extent.x,minf(feature.y,feature.get("end_y",feature.y))-feature.radius)
				extent.y=maxf(extent.y,maxf(feature.y,feature.get("end_y",feature.y))+feature.radius)
		# Stable vertical bands reuse sampled base fields across changing doses.
		var bottom := floorf((extent.x-displacement-8)/32)*32
		var top := ceilf((extent.y+displacement+8)/32)*32
		var patch: Dictionary
		if column_parts.has(column) and column_recipes[column]==cuts:
			patch=column_parts[column];reused+=1
		else:
			patch=field_cache.build(Vector3(column.x*8,bottom,column.y*8),Vector3i(4,roundi((top-bottom)/2),4),2.0,cuts,3,0,true,cached_base,source.identity)
			base_calls+=patch.profile.base_evaluations
			patch.erase("_field_state")
			if source.curve_to_ring: Ring.warp_mesh(patch)
			column_parts[column]=patch;column_recipes[column]=cuts.duplicate(true);rebuilt+=1
		var offset := vertices.size()
		vertices.append_array(patch.vertices);normals.append_array(patch.normals)
		for index in patch.indices: indices.append(index+offset)
	cuts=ordered
	for column in column_parts.keys():
		if not columns.has(column): column_parts.erase(column);column_recipes.erase(column)
	var result := data.duplicate()
	result.vertices=vertices;result.normals=normals;result.indices=indices;result.render_lods={};result.cached=false
	profile={"ms":(Time.get_ticks_usec()-started)/1000.0,"rebuilt_columns":rebuilt,"reused_columns":reused,"base_evaluations":base_calls}
	result.profile=profile
	return result

