extends RefCounted
## Frozen pre-optimization reference for profile_drive_brush.gd; not runtime code.
## The fine lattice preserves the coarse tetrahedral surface at patch boundaries.
const Ring = preload("res://world/terrain_drive_ring.gd")
const Mesher = preload("res://world/tetra_mesher.gd")
const Recipe = preload("res://world/sdf_recipe.gd")
var source: RefCounted
var cuts: Array=[]
var samples := {}

func lattice(p: Vector3) -> float:
	var key := Vector3i(p)
	if not samples.has(key): samples[key]=Recipe.compose(p,source.base_field(p,3,0),source.features)
	return samples[key]

func base_sample(p: Vector3) -> float:
	var cell := (p/8).floor()*8
	var f := (p-cell)/8
	var axes := [0,1,2]
	axes.sort_custom(func(a,b): return f[a]>f[b])
	var a := cell;var b := cell;b[axes[0]]+=8
	var c := b;c[axes[1]]+=8
	return lattice(a)*(1-f[axes[0]])+lattice(b)*(f[axes[0]]-f[axes[1]])+lattice(c)*(f[axes[1]]-f[axes[2]])+lattice(cell+Vector3.ONE*8)*f[axes[2]]

func sample(p: Vector3) -> float:
	return Recipe.compose(p,base_sample(p),cuts)

func rebuild(data: Dictionary, key: Vector2i) -> Dictionary:
	cuts=Recipe.relevant(cuts,Rect2(Vector2(key)*200,Vector2.ONE*200).grow(1))
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
	var vertices: PackedVector3Array=data.vertices
	var indices := PackedInt32Array()
	for i in range(0,data.indices.size(),3):
		var centre := Vector3.ZERO
		for j in 3:
			var p: Vector3=vertices[data.indices[i+j]]
			centre+=Ring.coordinates(p) if source.curve_to_ring else p
		var cell := Vector3i((centre/24).floor())
		if not cells.has(cell):
			for j in 3: indices.append(data.indices[i+j])
	var normals: PackedVector3Array=data.normals
	for cell in cells:
		var patch: Dictionary=Mesher.build(sample,Vector3(cell)*8,Vector3i.ONE*4,2.0)
		if source.curve_to_ring: Ring.warp_mesh(patch)
		var offset := vertices.size()
		vertices.append_array(patch.vertices);normals.append_array(patch.normals)
		for index in patch.indices: indices.append(index+offset)
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
	var columns := {}
	for feature in cuts:
		var bounds := edit_bounds(feature)
		var lo := Vector2i((bounds.position/8).floor());var hi := Vector2i((bounds.end/8).floor())
		for z in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				if floori(x*8.0/200)==key.x and floori(z*8.0/200)==key.y: columns[Vector2i(x,z)]=Vector2(INF,-INF)
	var vertices: PackedVector3Array=data.vertices
	var flat := PackedVector3Array();flat.resize(vertices.size())
	for i in vertices.size(): flat[i]=Ring.coordinates(vertices[i]) if source.curve_to_ring else vertices[i]
	var indices := PackedInt32Array()
	for i in range(0,data.indices.size(),3):
		var a := flat[data.indices[i]];var b := flat[data.indices[i+1]];var c := flat[data.indices[i+2]]
		var centre := (a+b+c)/3
		var column := Vector2i(floori(centre.x/8),floori(centre.z/8))
		if columns.has(column):
			var extent: Vector2=columns[column]
			columns[column]=Vector2(minf(extent.x,minf(a.y,minf(b.y,c.y))),maxf(extent.y,maxf(a.y,maxf(b.y,c.y))))
		else:
			for j in 3: indices.append(data.indices[i+j])
	var normals: PackedVector3Array=data.normals
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
		var bottom := floorf((extent.x-displacement-8)/8)*8
		var top := ceilf((extent.y+displacement+8)/8)*8
		var patch: Dictionary=Mesher.build(sample,Vector3(column.x*8,bottom,column.y*8),Vector3i(4,roundi((top-bottom)/2),4),2.0)
		if source.curve_to_ring: Ring.warp_mesh(patch)
		var offset := vertices.size()
		vertices.append_array(patch.vertices);normals.append_array(patch.normals)
		for index in patch.indices: indices.append(index+offset)
	cuts=ordered
	var result := data.duplicate()
	result.vertices=vertices;result.normals=normals;result.indices=indices;result.render_lods={};result.cached=false
	return result

