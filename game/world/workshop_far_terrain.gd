extends Node3D
## Non-colliding SDF scenery. Detailed published chunks own rendering/physics.
const Recipe=preload("res://world/sdf_recipe.gd")
const Cache=preload("res://world/sdf_field_cache.gd")
const EXTENT := 768.0
const TILE := 256
const CELLS := Vector3i(16,6,16)
const STEP := 16.0
const FOLDER := "user://sdf-authoring-meshes/scenery/"
var arena: Node
var field_cache := Cache.new() # Never pollute the fine editor's picking cache.
var worker: Thread
var job := {}
var tiles := {}
var pending: Array=[]
var seen_revision := -1
var mask: Image
var texture: ImageTexture
var material: ShaderMaterial
var mask_signature := ""
var source_tag := ""

func setup(owner_arena: Node) -> void:
	arena=owner_arena
	DirAccess.make_dir_recursive_absolute(FOLDER)
	source_tag=(FileAccess.get_file_as_string("res://world/workshop_far_terrain.gd")+FileAccess.get_file_as_string("res://world/sdf_field_cache.gd")).sha256_text()
	mask=Image.create(48,48,false,Image.FORMAT_R8);mask.fill(Color.BLACK)
	texture=ImageTexture.create_from_image(mask)
	material=arena.terrain.material_override.duplicate()
	material.set_shader_parameter("coarse_surface",true)
	material.set_shader_parameter("detail_surface",false)
	material.set_shader_parameter("detail_mask",texture)
	material.set_shader_parameter("local_extent",EXTENT)

func stop() -> void:
	if worker: worker.wait_to_finish();worker=null

func _exit_tree() -> void:
	stop()

func finished() -> bool:
	return tiles.size()==36 and pending.is_empty() and worker==null and seen_revision==arena.revision

func _process(_delta: float) -> void:
	if arena==null: return
	material.set_shader_parameter("textured",arena.terrain.material_override.get_shader_parameter("textured"))
	var keys: Array=arena.chunks.keys();keys.sort()
	var signature := str(keys)
	if mask_signature!=signature:
		mask_signature=signature;mask.fill(Color.BLACK)
		for key in keys:
			if key.x>=-24 and key.x<24 and key.y>=-24 and key.y<24: mask.set_pixel(key.x+24,key.y+24,Color.WHITE)
		texture.update(mask)
	# Finish one upload per frame. Never cancel a running job or delete a cache.
	if worker and not worker.is_alive():
		var result: Dictionary=worker.wait_to_finish();worker=null
		var mesh := ArrayMesh.new()
		if not result.vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arena.mesh_arrays(result))
		if not tiles.has(job.key):
			var node := MeshInstance3D.new();node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
			tiles[job.key]={"node":node,"signature":""}
		tiles[job.key].node.mesh=mesh;tiles[job.key].signature=job.signature
	# Edits get priority. Coarse replacements follow after fine meshes catch up.
	if arena.brushing or arena.brush_dirty or not arena.preview_expected.is_empty(): return
	if seen_revision!=arena.revision:
		pending.clear();seen_revision=arena.revision
		for z in range(-3,3):
			for x in range(-3,3):
				var key := Vector2i(x,z)
				var local := Recipe.relevant(arena.features,Rect2(Vector2(key)*TILE,Vector2.ONE*TILE).grow(STEP+.1))
				var id := JSON.stringify(local).sha256_text()
				if not tiles.has(key) or tiles[key].signature!=id: pending.append({"key":key,"signature":id,"features":local})
		pending.sort_custom(func(a: Dictionary,b: Dictionary): return (Vector2(a.key)*TILE+Vector2.ONE*TILE*.5).distance_squared_to(Vector2(arena.camera.position.x,arena.camera.position.z))<(Vector2(b.key)*TILE+Vector2.ONE*TILE*.5).distance_squared_to(Vector2(arena.camera.position.x,arena.camera.position.z)))
	if worker==null and not pending.is_empty() and arena.stream_jobs.size()<2:
		job=pending.pop_front()
		# A job completed across a revision change may already satisfy this entry.
		if tiles.has(job.key) and tiles[job.key].signature==job.signature: return
		worker=Thread.new()
		var err := worker.start(build.bind(job.key,job.features,arena.tunnel_radius,arena.roughness,arena.get("terrain_source")))
		if err!=OK: worker=null;pending.push_front(job);push_error("Could not start SDF scenery worker")

func build(key: Vector2i, features: Array, radius: float, rough: float, source: RefCounted=null) -> Dictionary:
	var origin := Vector3(key.x*TILE,-24,key.y*TILE)
	var identity: String=source.base_hash if source else ""
	var path := FOLDER+(source_tag+identity+Recipe.cache_key(features,origin,CELLS,STEP,radius,rough)).sha256_text()+".bin"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		if file:
			var data: Variant=file.get_var(false)
			if data is Dictionary and data.get("_field_state") is Dictionary and Cache.valid_state(data._field_state,CELLS):
				data.cached=true;return data
	var result := field_cache.build(origin,CELLS,STEP,features,radius,rough,true,source.base_field if source else Callable(),identity)
	# Store full-field normals with the coarse 3D mesh. A 2D normal drape cannot
	# represent the different normals of a deck, its underside and a tunnel wall.
	var normal_regions := {}
	for i in result.vertices.size():
		var p: Vector3=result.vertices[i]
		var region := Vector2i(floori(p.x/32),floori(p.z/32))
		if not normal_regions.has(region): normal_regions[region]=Recipe.relevant(features,Rect2(Vector2(region)*32,Vector2.ONE*32).grow(1.1))
		var local: Array=normal_regions[region]
		var n := Vector3.ZERO
		for axis in 3:
			var e := Vector3.ZERO;e[axis]=1
			n[axis]=Recipe.field(p+e,radius,rough,local,source)-Recipe.field(p-e,radius,rough,local,source)
		if n.length_squared()>.000001: result.normals[i]=n.normalized()
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_var(result,false);file.close();DirAccess.rename_absolute(path+".tmp",path)
	return result
