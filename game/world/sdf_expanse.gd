extends "res://world/sdf_demo.gd"
## Uniform-resolution streaming proof; not adaptive LOD or ring integration.
const CHUNK := 32
const RANGE := 2
const LIMIT := 8 # -256..256 m in both horizontal axes
const SITES := [Vector3(19,12,-29),Vector3(90,22,-15),Vector3(-42,23,12),Vector3(45,16,-105)]
var chunks: Dictionary = {}
var active_key := Vector2i.ZERO
var active_revision := 0
var revision := 0
var install_ms := 0
var max_resident := 0
var checks_started := false
var textured := true
var stream_jobs: Array[Dictionary] = []

func stream_worker_limit() -> int:
	return 1

func stream_install_budget_usec() -> int:
	return 5000

func chunk_generated(_result: Dictionary) -> void:
	pass

static func landscape(p: Vector3, radius: float, rough: float) -> float:
	var distance_from_home := Vector2(p.x,p.z).length()
	var broad := smoothstep(28,60,distance_from_home)*(1.5*sin(p.x*0.035)*cos(p.z*0.028))
	var basin := 5*exp(-Vector2((p.x-45)/24,(p.z+80)/28).length_squared())
	var ground := p.y-broad+basin
	var home := field(p,radius,rough)
	var ridge := (((p-Vector3(70,5,25))/Vector3(35,26,11)).length()-1)*11
	ridge += rough*sin(p.x*0.4)*cos(p.y*0.5)*cos(p.z*0.4)
	ridge = maxf(ridge,-(Vector2(p.x-70,p.y-6).length()-(radius+3.5)))
	var bridge := box(p-Vector3(-65,6,45),Vector3(28,10,10))
	var arch := (Vector2((p.x+65)/18,(p.y-1)/11).length()-1)*11
	bridge = maxf(bridge,-arch)
	return minf(minf(home,ground),minf(ridge,bridge))

func _ready() -> void:
	super._ready()
	terrain.material_override = preload("res://world/materials/expanse_material.gd").create()
	hud.add_theme_color_override("font_outline_color", Color(0,0,0,0.8))
	hud.add_theme_constant_override("outline_size", 4)
	# The original grey diagnostic material tolerated lighting that clips pale
	# limestone to white in Compatibility. Leave headroom for the actual albedo.
	for child in get_children():
		if child is DirectionalLight3D:
			child.light_energy = 0.85
		if child is WorldEnvironment:
			child.environment.ambient_light_energy = 0.35
	DisplayServer.window_set_title("SDF expanse / 512m streamed landscape")
	for child in get_children():
		if child is Label3D: child.queue_free()
	camera.far = 220
	if OS.get_cmdline_user_args().has("--expanse-bridge"):
		camera.position = SITES[2]
		camera.look_at(Vector3(-65,7,45))
		look = Vector2(camera.rotation.y,camera.rotation.x)
	if OS.get_cmdline_user_args().has("--material-close"):
		camera.position = Vector3(-53,5,25)
		camera.look_at(Vector3(-65,7,45))
		look = Vector2(camera.rotation.y,camera.rotation.x)
	for spec in [["1 / HOME TUNNEL",Vector3(0,15,0)],["2 / HIGH PASS",Vector3(70,35,25)],
		["3 / STONE BRIDGE",Vector3(-65,22,45)],["4 / BASIN",Vector3(45,4,-80)]]:
		var label := Label3D.new()
		label.text = spec[0]
		label.position = spec[1]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.025
		label.visibility_range_end = 125
		add_child(label)

func rebuild() -> void:
	revision += 1
	# Both live controls affect only the home ridge and high pass. Other chunks
	# keep their mesh/collision; padded bounds include normal sampling margins.
	for key in chunks:
		var area := Rect2(Vector2(key)*CHUNK,Vector2(CHUNK,CHUNK))
		if not area.intersects(Rect2(-26,-22,52,44)) and not area.intersects(Rect2(33,12,74,26)):
			chunks[key].revision = revision
	walking = false # No walking across mixed old/new collision during edits.
	ready_frames = 0
	frame_times.clear()

func key_at(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x/CHUNK),floori(p.z/CHUNK))

func desired() -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	var center := key_at(camera.position)
	for z in range(-RANGE,RANGE+1):
		for x in range(-RANGE,RANGE+1):
			var key := center+Vector2i(x,z)
			if key.x >= -LIMIT and key.x < LIMIT and key.y >= -LIMIT and key.y < LIMIT:
				keys.append(key)
	keys.sort_custom(func(a: Vector2i,b: Vector2i): return (a-center).length_squared() < (b-center).length_squared())
	return keys

func chunk_sampler() -> Callable:
	return landscape

func chunk_layout() -> Dictionary:
	return {"bottom":-12.0,"cells":Vector3i(16,28,16),"spacing":2.0}

func movement_limit() -> float:
	return 254.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			textured = not textured
			terrain.material_override.set_shader_parameter("textured", textured)
			return
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			var i: int = event.keycode-KEY_1
			walking = false
			camera.position = SITES[i]
			var targets := [Vector3(0,3,0),Vector3(70,8,25),Vector3(-65,7,45),Vector3(45,-2,-80)]
			camera.look_at(targets[i])
			look = Vector2(camera.rotation.y,camera.rotation.x)
			ready_frames = 0
			frame_times.clear()
			return
		if event.keycode == KEY_F:
			if walking:
				walking = false
				return
			if not neighborhood_ready(camera.position): return
			var query := PhysicsRayQueryParameters3D.create(Vector3(camera.position.x,44,camera.position.z),Vector3(camera.position.x,-10,camera.position.z))
			query.exclude = [player.get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				player.position = hit.position+Vector3.UP*0.15
				player.velocity = Vector3.ZERO
				walking = true
			return
	super._input(event)

func neighborhood_ready(p: Vector3) -> bool:
	var center := key_at(p)
	for z in range(-1,2):
		for x in range(-1,2):
			var key := center+Vector2i(x,z)
			if not chunks.has(key) or chunks[key].revision != revision: return false
	return true

func _physics_process(delta: float) -> void:
	if walking and not neighborhood_ready(player.position):
		player.velocity = Vector3.ZERO
		return # Hold safely while the next collision neighborhood streams.
	super._physics_process(delta)
	camera.position.x = clampf(camera.position.x,-movement_limit(),movement_limit())
	camera.position.z = clampf(camera.position.z,-movement_limit(),movement_limit())
	if camera.position.y < -8:
		walking = false
		camera.position.y = 12

func _process(delta: float) -> void:
	var wanted := desired()
	# Workers only produce primitive arrays. Start at most one costly install
	# after the budget is exhausted; a single indivisible upload may exceed it.
	var install_started := Time.get_ticks_usec()
	var installed := false
	for job in stream_jobs.duplicate():
		if not job.has("result") and not job.thread.is_alive():
			job.result=job.thread.wait_to_finish();chunk_generated(job.result)
		if not job.has("result"): continue
		if job.revision!=revision or job.key not in wanted:
			stream_jobs.erase(job);continue
		if installed and Time.get_ticks_usec()-install_started>=stream_install_budget_usec(): continue
		active_key=job.key;active_revision=job.revision
		install(job.key,job.result);installed=true;stream_jobs.erase(job)
	for key in chunks.keys():
		if key not in wanted:
			retire_chunk(key)
	var missing := 0
	for key in wanted:
		if chunks.has(key) and chunks[key].revision == revision: continue
		missing += 1
		var pending := false
		for job in stream_jobs:
			if job.key==key: pending=true;break
		if not pending and stream_jobs.size()<stream_worker_limit():
			active_key = key
			active_revision = revision
			var thread := Thread.new()
			var layout := chunk_layout()
			var error := thread.start(generate.bind(tunnel_radius,roughness,
				Vector3(key.x*CHUNK,layout.bottom,key.y*CHUNK),layout.cells,layout.spacing,chunk_sampler()))
			if error==OK: stream_jobs.append({"thread":thread,"key":key,"revision":revision})
			else: push_error("Chunk generation worker failed")
	worker=stream_jobs[0].thread if not stream_jobs.is_empty() else null
	triangles = 0
	for entry in chunks.values(): triangles += entry.triangles
	max_resident = maxi(max_resident,chunks.size())
	hud.text = "SDF EXPANSE / 512 x 512m / 2m samples / %s\n1 home | 2 high pass | 3 stone bridge | 4 basin | F walk/fly | T textures\nWASD + mouse | Space/Ctrl vertical | Shift faster | [ ] tunnels | R detail\n%d/%d chunks | %d queued | %d triangles | worker %dms / install %dms | %.0f FPS%s" % [
		"WALK" if walking else "FLY",chunks.size(),wanted.size(),missing,triangles,generation_ms,install_ms,Engine.get_frames_per_second(),
		"\nWaiting for nearby collision" if walking and not neighborhood_ready(player.position) else ""]
	if missing == 0 and worker == null:
		ready_frames += 1
		if OS.get_cmdline_user_args().has("--expanse-check") and not checks_started:
			checks_started = true
			check_expanse.call_deferred()
		if OS.get_cmdline_user_args().has("--expanse-capture"):
			if ready_frames > 30: frame_times.append(delta)
			if ready_frames == 150: capture_expanse.call_deferred()
	else:
		ready_frames = 0
		frame_times.clear()

func retire_chunk(key: Vector2i) -> void:
	chunks[key].node.queue_free()
	chunks.erase(key)

func _exit_tree() -> void:
	for job in stream_jobs:
		if not job.has("result"): job.thread.wait_to_finish()
	stream_jobs.clear();worker=null
	super._exit_tree()

func install(key: Vector2i,result: Dictionary) -> void:
	var started := Time.get_ticks_msec()
	var node := Node3D.new()
	add_child(node)
	if result.vertices.size() > 0:
		var mesh := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = result.vertices
		arrays[Mesh.ARRAY_NORMAL] = result.normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = terrain.material_override
		node.add_child(instance)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		node.add_child(body)
		body.add_child(shape)
	if chunks.has(key): chunks[key].node.queue_free()
	chunks[key] = {"node":node,"triangles":result.vertices.size()/3,"revision":active_revision}
	generation_ms = result.ms
	install_ms = Time.get_ticks_msec()-started
	print("SDF_CHUNK ",key," generation_ms=",generation_ms," install_ms=",install_ms," triangles=",result.vertices.size()/3)

func check_expanse() -> void:
	assert(chunks.size() <= 25 and neighborhood_ready(camera.position))
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Raycast across a chunk edge on the shared global lattice.
	var space := get_world_3d().direct_space_state
	for x in [-0.01,0.01,31.99,32.01]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(x,20,-16),Vector3(x,-10,-16))
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		assert(not hit.is_empty())
	assert(landscape(Vector3(70,6,25),tunnel_radius,roughness)>0)
	assert(landscape(Vector3(-65,6,45),tunnel_radius,roughness)>0)
	assert(landscape(Vector3(-65,15,45),tunnel_radius,roughness)<0)
	var old := chunks.keys()
	camera.position = SITES[2]
	while not neighborhood_ready(camera.position): await get_tree().process_frame
	assert(chunks.size() <= 25)
	var removed := false
	for key in old:
		if not chunks.has(key): removed = true
	assert(removed)
	print("PASS: chunk edge collision, landmark cavities, camera-driven generation and eviction; max resident=",max_resident)
	if OS.get_cmdline_user_args().has("--expanse-edit-check"):
		var unaffected: Node3D = chunks[Vector2i(-3,1)].node
		tunnel_radius = 4.4
		rebuild()
		while worker != null or ready_frames == 0: await get_tree().process_frame
		assert(chunks[Vector2i(-3,1)].node == unaffected)
		for entry in chunks.values(): assert(entry.revision == revision)
		# Travel under the bridge and across z=32/64 streaming boundaries.
		camera.position = Vector3(-65,4,24)
		while not neighborhood_ready(camera.position): await get_tree().process_frame
		player.position = Vector3(-65,3,24)
		player.velocity = Vector3.ZERO
		walking = true
		auto_walk = true
		for frame in 600: await get_tree().physics_frame
		auto_walk = false
		walking = false
		assert(player.position.z > 65 and player.position.y > -6)
		print("PASS: localized edit retains unaffected chunk; streamed bridge traversal ",player.position)
	if not OS.get_cmdline_user_args().has("--expanse-capture"): get_tree().quit()

func capture_expanse() -> void:
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("user://sdf-expanse.png") == OK)
	var seconds := 0.0
	for frame in frame_times: seconds += frame
	print("EXPANSE_CAPTURE stationary_fps=",frame_times.size()/maxf(seconds,0.001)," resident=",chunks.size()," triangles=",triangles)
	get_tree().quit()
