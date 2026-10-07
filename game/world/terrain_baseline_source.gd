extends "res://world/unified_terrain_field.gd"
## Fresh DEM recipe for the staged demo; old workshop recipes are never loaded.
const EXTENT := 1600
const TILE := 200
const STEP := 8
const Mesher = preload("res://world/tetra_mesher.gd")
const Lods = preload("res://world/terrain_render_lods.gd")
const Ring = preload("res://world/terrain_drive_ring.gd")
var centre_height := 0.0
var identity := ""
var curve_to_ring := false

func initialize() -> bool:
	if not setup([]): return false
	centre_height=dem_height(0,0)
	# Resolve both deck faces exactly on this stage's 8 m volume lattice.
	var bridge := Recipe.feature("bridge",Vector3(100,ceilf(surface_height(Vector2(100,100))/STEP)*STEP+32,100))
	bridge.merge({"length":120.0,"width":24.0,"thickness":16.0,"height":56.0},true)
	var hill := Recipe.feature("hill",Vector3(100,surface_height(Vector2(100,-100)), -100))
	hill.radius=72.0;hill.height=48.0
	var tunnel := Recipe.feature("tunnel",Vector3(10,hill.y+10,-100))
	tunnel.merge({"end_x":190.0,"end_y":hill.y+10,"end_z":-100.0,"radius":12.0},true)
	features=[bridge,hill,tunnel]
	identity=(base_hash+FileAccess.get_file_as_string("res://world/terrain_baseline_source.gd")+FileAccess.get_file_as_string("res://world/terrain_render_lods.gd")+FileAccess.get_file_as_string("res://world/terrain_drive_ring.gd")+str(curve_to_ring)+JSON.stringify(features)).sha256_text()
	return true

func surface_height(point: Vector2, _spacing := 0.0) -> float:
	# Same home DEM coordinates and native bilinear elevation, local height origin.
	return dem_height(point.x,point.y)-centre_height

func base_field(p: Vector3, _radius: float, _rough: float) -> float:
	return p.y-surface_height(Vector2(p.x,p.z))

func build_tile(key: Vector2i) -> Dictionary:
	var folder := "user://terrain-baseline/"+identity+"/"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder+"%d_%d.bin" % [key.x,key.y]
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		var cached: Variant=file.get_var(false) if file else null
		if cached is Dictionary and cached.get("identity")==identity and cached.get("vertices") is PackedVector3Array and cached.get("indices") is PackedInt32Array and cached.has("render_lods"):
			cached.cached=true;return cached
	var origin2 := Vector2(key)*TILE
	var local := Recipe.relevant(features,Rect2(origin2,Vector2.ONE*TILE).grow(STEP))
	var count := TILE/STEP+1
	var heights := PackedFloat32Array();heights.resize(count*count)
	var bottom := INF;var top := -INF
	for z in count:
		for x in count:
			var h := surface_height(origin2+Vector2(x,z)*STEP)
			heights[z*count+x]=h;bottom=minf(bottom,h);top=maxf(top,h)
	for feature in local:
		bottom=minf(bottom,float(feature.y)-float(feature.height)-float(feature.radius))
		top=maxf(top,float(feature.y)+float(feature.height)+float(feature.radius))
	bottom=floorf(bottom/STEP)*STEP-STEP;top=ceilf(top/STEP)*STEP+STEP
	var cells := Vector3i(TILE/STEP,roundi((top-bottom)/STEP),TILE/STEP)
	var origin := Vector3(origin2.x,bottom,origin2.y)
	var supplied := PackedFloat32Array();supplied.resize(count*(cells.y+1)*count)
	for z in count:
		for y in cells.y+1:
			for x in count:
				var p := origin+Vector3(x,y,z)*STEP
				supplied[(z*(cells.y+1)+y)*count+x]=Recipe.compose(p,p.y-heights[z*count+x],local)
	var sampler := Recipe.field.bind(3.0,0.0,local,self)
	var result := Mesher.build(sampler,origin,cells,STEP,supplied)
	if curve_to_ring: Ring.warp_mesh(result)
	Lods.prepare(result,identity+str(key))
	result.identity=identity;result.cached=false
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_var(result,false);file.close();DirAccess.rename_absolute(path+".tmp",path)
	return result
