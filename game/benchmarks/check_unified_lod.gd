extends SceneTree
const Field=preload("res://world/unified_terrain_field.gd")
const LOD=preload("res://world/workshop_terrain_lod.gd")
const Satellite=preload("res://world/workshop_satellite.gd")
const Cache=preload("res://world/sdf_field_cache.gd")
const Recipe=preload("res://world/sdf_recipe.gd")
const Backdrop=preload("res://world/arena_ring_background.gd")
func _initialize() -> void:
	create_timer(120).timeout.connect(func(): push_error("Unified LOD unit timeout");quit(1))
	run.call_deferred()

func require(value: bool, message: String) -> bool:
	if not value: push_error(message);quit(1)
	return value

func run() -> void:
	var script=load("res://world/sdf_authoring.gd")
	if not require(script.can_instantiate(),"Workshop script failed compilation"): return
	var workshop=script.new()
	workshop.features=[Recipe.feature("hill",Vector3.ZERO)]
	workshop.revision=1
	var old_snapshot: Array=workshop.chunk_sampler().get_bound_arguments()[0]
	workshop.features[0].x=100.0;workshop.revision+=1
	var next_snapshot: Array=workshop.chunk_sampler().get_bound_arguments()[0]
	if not require(old_snapshot[0].x==0 and next_snapshot[0].x==100,"Worker recipe snapshots were mutated or not invalidated"): return
	# This unit creates the script without _ready(), so its eagerly allocated
	# helper nodes have not yet been parented and must be released explicitly.
	for name in ["terrain","collision","camera","player","hud","marker","brush_cursor","chunk_overlay","endpoint_guide","endpoint_handle","surface_cursor"]:
		workshop.get(name).free()
	workshop.free()
	var source := Field.new()
	if not require(source.setup([]),"DEM setup"): return
	var indexed_recipe: Array=preload("res://world/stress_course.gd").features()
	for point in [Vector3(-638,0,-768),Vector3(638,0,768),Vector3(2048,0,0),Vector3(-2048,0,0)]: indexed_recipe.append(Recipe.feature("hill",point))
	var indexed := LOD.index_features(indexed_recipe)
	if not require(indexed.size()==220,"Exterior feature index coverage"): return
	for key in indexed:
		var expected := Recipe.relevant(indexed_recipe,Rect2(Vector2(key)*256,Vector2.ONE*256).grow(130))
		if not require(indexed[key]==expected,"Feature index changed order or membership at "+str(key)): return
	var neighbors := {}
	for z in range(-6,-2):
		for x in range(-2,3): neighbors[Vector2i(x,z)]=16 if x<0 else 64
	var left := {"key":Vector2i(-1,-4),"step":16,"neighbors":neighbors}
	var right := {"key":Vector2i(0,-4),"step":64,"neighbors":neighbors}
	for z in range(-1024,-767,16):
		var point := Vector2(0,z)
		var actual := LOD.vertex_height(source,point,left)
		var lo := floorf(z/64.0)*64
		var hi := minf(-768,lo+64)
		var expected := LOD.vertex_height(source,Vector2(0,lo),right)
		if hi>lo: expected=lerpf(expected,LOD.vertex_height(source,Vector2(0,hi),right),(z-lo)/(hi-lo))
		if not require(absf(actual-expected)<.0001,"LOD shared edge mismatch at "+str(z)): return
	var cache := Cache.new()
	var edge_spec := {"key":Vector2i(7,-4),"step":32,"neighbors":{}}
	for z in range(-1024,-767,32):
		var p := Vector2(2048,z)
		if not require(absf(LOD.vertex_height(source,p,edge_spec)-Backdrop.aligned_edge_height(source,p,true))<.0001,"Backdrop edge lattice mismatch"): return
	var origin := Vector3(-16,source.surface_height(Vector2(-16,-1000))-8,-1000)
	var a := cache.build(origin,Vector3i(4,8,4),2,[],3,.2,true,source.base_field,source.base_hash)
	var b := cache.build(origin,Vector3i(4,8,4),2,[],3,.2,true,source.base_field,source.base_hash)
	if not require(a.vertices==b.vertices and b.profile.warm_field,"Warm base sampler identity"): return
	var c := cache.build(origin,Vector3i(4,8,4),2,[],3,.2)
	if not require(not c.profile.warm_field,"Different base reused stale RAM field"): return
	var snapshot := source.snapshot([Recipe.feature("carve",Vector3(-14,10,-900))])
	if not require(snapshot.base_hash==source.base_hash and snapshot.source_hash!=source.source_hash,"Snapshot identity"): return
	var tile := LOD.new()
	DirAccess.make_dir_recursive_absolute(LOD.FOLDER)
	var spec := {"key":Vector2i(0,-4),"step":64,"neighbors":neighbors,"features":[],"id":(source.base_hash+FileAccess.get_file_as_string("res://world/workshop_terrain_lod.gd")+"unit-tile").sha256_text()}
	var built: Dictionary=tile.build(spec,source,3,.2)
	var restored: Dictionary=tile.build(spec,source,3,.2)
	if not require(restored.cached and restored.vertices==built.vertices and restored.normal_data==built.normal_data,"Terrain mesh and normal disk cache reuse"): return
	var edge_a: Vector3=built.vertices[built.indices[1]]-built.vertices[built.indices[0]]
	var edge_b: Vector3=built.vertices[built.indices[2]]-built.vertices[built.indices[0]]
	if not require(edge_a.cross(edge_b).y<0,"Godot clockwise top-face winding"): return
	tile.free()
	var maps := Satellite.load_pages([{"key":Vector2i(14,21),"level":0},{"key":Vector2i(14,21),"level":1}],"")
	if not require(maps.pages.size()==2 and maps.pages[0].image.get_width()==258 and maps.pages[1].image.get_width()==130,"Satellite resolution tiers"): return
	if not require(maps.pages[0].image.has_mipmaps() and maps.pages[1].image.has_mipmaps(),"Satellite filtering mips"): return
	var warm := Satellite.load_pages([{"key":Vector2i(14,21),"level":0},{"key":Vector2i(14,21),"level":1}],maps.source_hash)
	if not require(warm.cache_hits==2 and warm.pages[0].image.get_data()==maps.pages[0].image.get_data(),"Satellite cache did not reuse identical pixels"): return
	print("UNIFIED_LOD_UNIT_PASS seams=true base_identity=true satellite_tiers=true")
	quit()
