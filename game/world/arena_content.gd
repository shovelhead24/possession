extends "res://world/content_gallery.gd"
## Retains the proven source importer and pose/bounds preparation.
var tree_count := 0
var tree_batches: Array[Dictionary] = []
var tree_clock := 0.0
var trees_visible := true

func setup(tile: Node3D) -> void:
	patch = tile
	# The gallery allocates this helper before setup; give it scene ownership.
	add_child(contact_debug)
	contact_debug.visible = false
	load_arena.call_deferred()

func source_specs() -> Array:
	return [
		["Warthog","res://../assets/halo_warthog.zip",Vector2(-28,-34),4.8,false],
		["Alien","res://../prototypes/first-operation/lizard_rig.glb",Vector2(18,-22),2.2,true],
		["T-Rex","res://../assets/rigged-t-rex-fabulous/source/rigged_t-rex_fabulous.glb",Vector2(43,-2),24.0,false],
	]

func include_relay() -> bool:
	return false

func load_arena() -> void:
	await load_gallery()
	finished = false
	for entry in entries.duplicate():
		if entry.name == "Alien":
			for coord in [Vector2(26,-16),Vector2(31,-27)]:
				var clone := entry.model.duplicate() as Node3D
				add_entry("Alien",clone,coord,entry.height)
	await get_tree().process_frame
	if patch.has_method("loading_event"):
		patch.loading_event("Importing trees and preparing foliage LODs")
		await RenderingServer.frame_post_draw
	load_trees()
	finished = true
	print("ARENA_CONTENT ready actors=",entries.size()," trees=",tree_count)

func ground_at(coord: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(coord.x,44,coord.y),Vector3(coord.x,-10,coord.y),1)
	query.exclude = [patch.player.get_rid()]
	return patch.get_world_3d().direct_space_state.intersect_ray(query)

func add_entry(title: String, model: Node3D, coord: Vector2, height: float) -> void:
	var hit := ground_at(coord)
	assert(not hit.is_empty(), "Arena actor has no terrain support: " + title)
	var root := Node3D.new()
	root.name = title.replace("-", "")
	patch.add_child(root)
	root.position = hit.position
	root.add_child(model)
	model.show()
	model.process_mode = Node.PROCESS_MODE_DISABLED
	if title == "Warthog":
		var up: Vector3 = hit.normal
		var forward := Vector3.FORWARD.slide(up).normalized()
		root.basis = Basis(forward.cross(up).normalized(),up,-forward)
		# Fit the visual vehicle footprint against the rendered collision triangles.
		var lift := 0.0
		for x in [-1.0,0.0,1.0]:
			for z in [-1.55,0.0,1.55]:
				var point := root.position + root.basis * Vector3(x,0,z)
				var support := ground_at(Vector2(point.x,point.z))
				if not support.is_empty(): lift = maxf(lift,(support.position-point).dot(up))
		root.position += up * lift
	var label := Label3D.new()
	label.text = title
	label.position.y = height+0.8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.visibility_range_end = 70
	root.add_child(label)
	var body := StaticBody3D.new()
	body.collision_layer = 2 # Placement rays sample terrain (layer 1) only.
	root.add_child(body)
	var collision_shape := CollisionShape3D.new()
	if title == "Warthog":
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.3,2.2,4.5)
		collision_shape.shape = shape
		collision_shape.position.y = 1.1
	else:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4 if title == "Alien" else 1.4
		shape.height = height
		collision_shape.shape = shape
		collision_shape.position.y = height*0.5
	body.add_child(collision_shape)
	entries.append({"name":title,"root":root,"model":model,"coord":coord,"height":height,"label":label})

func load_trees() -> void:
	var variants := prepared_tree_meshes()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261001
	var names := variants.keys()
	names.sort()
	for name in names:
		var lods: Array=variants[name]
		add_tree_variant(lods,rng)
	update_tree_lod()

func prepared_tree_meshes() -> Dictionary:
	var archive := ProjectSettings.globalize_path("res://../assets/realistic_fir_trees_pack_lods_gameready.zip").simplify_path()
	var identity := FileAccess.get_sha256(archive)+str(Engine.get_version_info().hex)
	for path in ["res://world/arena_content.gd","res://world/content_gallery.gd","res://mocks/ring_vibes.gd","res://mocks/tree_foliage.gdshader"]:
		identity+=FileAccess.get_sha256(path)
	var cache_path := "user://tree-lods-"+identity.sha256_text()+".res"
	if FileAccess.file_exists(cache_path):
		var cached := ResourceLoader.load(cache_path,"",ResourceLoader.CACHE_MODE_IGNORE)
		if cached and cached.has_meta("variants"):
			print("TREE_LOD_CACHE hit ",cache_path)
			return cached.get_meta("variants")
	var source := import_source(archive)
	assert(source != null,"Arena fir archive unavailable")
	var ring: Node3D = patch.ring_background
	ring._foliage_shader = load("res://mocks/tree_foliage.gdshader")
	var regex := RegEx.new()
	regex.compile("(?i)^(.+?)_LOD(\\d)")
	var variants := {}
	ring._walk_lod_meshes(source,source,regex,variants)
	source.free()
	assert(not variants.is_empty(),"Fir archive contains no LOD meshes")
	var prepared := {}
	var names := variants.keys()
	names.sort()
	for name in names:
		var lods: Array[Mesh] = []
		for lod in [0,1,2]:
			var mesh: ArrayMesh = ring._normalize_mesh(variants[name].get(lod,variants[name].get(0)))
			assert(mesh != null)
			lods.append(mesh)
		# Match tactical's atlas-safe far tier: generic full-UV billboards show
		# the entire atlas as floating trees. Retain the pack's cheap LOD2 mesh.
		lods.append(lods[2])
		prepared[name]=lods
	var cached := Resource.new();cached.set_meta("variants",prepared)
	var error := ResourceSaver.save(cached,cache_path)
	if error!=OK: push_warning("Tree LOD cache write failed: "+str(error))
	print("TREE_LOD_CACHE built variants=",prepared.size()," saved=",error==OK)
	return prepared

func add_tree_variant(lods: Array, rng: RandomNumberGenerator) -> void:
	var transforms: Array[Transform3D] = []
	for index in 8:
		# Small clusters along the arena sides leave its centre and actors readable.
		var side := -1.0 if (index % 2 == 0) else 1.0
		var coord := Vector2(side*rng.randf_range(58,82),rng.randf_range(-78,78))
		var hit := ground_at(coord)
		if hit.is_empty() or hit.normal.y < 0.75: continue
		var height := rng.randf_range(7,13)
		var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*height)
		transforms.append(Transform3D(basis,hit.position))
		tree_count += 1
		var trunk := StaticBody3D.new()
		trunk.collision_layer = 2
		trunk.position = hit.position
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.2
		cylinder.height = height*0.45
		shape.shape = cylinder
		shape.position.y = cylinder.height*0.5
		trunk.add_child(shape)
		patch.add_child(trunk)
	var batches: Array[MultiMeshInstance3D] = []
	for level in lods.size():
		var mesh: Mesh=lods[level]
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = MultiMesh.new()
		instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		instance.multimesh.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visible=trees_visible
		patch.add_child(instance)
		batches.append(instance)
	tree_batches.append({"transforms":transforms,"batches":batches})

func set_trees_visible(value: bool) -> void:
	trees_visible=value
	for group in tree_batches:
		for batch in group.batches: batch.visible=value
	if value: update_tree_lod()

func update_tree_lod() -> void:
	if not trees_visible: return
	for group in tree_batches:
		var buckets := [[],[],[],[]]
		for transform: Transform3D in group.transforms:
			var distance: float = patch.camera.position.distance_to(transform.origin)
			buckets[tree_lod(distance)].append(transform)
		if group.get("uploaded",[])==buckets: continue
		group.uploaded=buckets
		for i in buckets.size():
			var mm: MultiMesh = group.batches[i].multimesh
			mm.instance_count = buckets[i].size()
			for j in buckets[i].size(): mm.set_instance_transform(j,buckets[i][j])

static func tree_lod(distance: float) -> int:
	return 0 if distance<22 else (1 if distance<65 else (2 if distance<110 else 3))

func _process(delta: float) -> void:
	tree_clock -= delta
	if tree_clock <= 0:
		tree_clock = 0.25
		update_tree_lod()

func _unhandled_input(_event: InputEvent) -> void:
	pass
