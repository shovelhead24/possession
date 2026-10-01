extends "res://world/sdf_expanse.gd"
## Walkable local implicit terrain in the tangent frame of the real-size ring.
var ring_background: Node3D
var arena_content: Node
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var content_started := false
var arena_frames := 0
var arena_checked := false
var arena_verification_done := false
var capture_requested := false

static func arena_field(p: Vector3, radius: float, detail: float) -> float:
	var edge := smoothstep(52,90,maxf(absf(p.x),absf(p.z)))
	var height := 0.35*sin(p.x*0.04)*cos(p.z*0.05) + edge*(4.0+2.0*sin(p.x*0.07+p.z*0.04))
	var ground := p.y-height
	var ridge := (((p-Vector3(-10,2,14))/Vector3(19,10,8)).length()-1)*8
	ridge += detail*sin(p.x*0.65)*sin(p.y*0.8)*cos(p.z*0.5)
	ridge = maxf(ridge,-(Vector2(p.x+10,p.y-3).length()-radius))
	var cover := (((p-Vector3(25,1,8))/Vector3(8,5,6)).length()-1)*5
	var ledge := box(p-Vector3(-39,1.5,33),Vector3(10,1.5,8))
	return minf(ground,minf(ridge,minf(cover,ledge)))

func chunk_sampler() -> Callable:
	return arena_field

func desired() -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	var center := key_at(camera.position)
	for z in range(-3,3):
		for x in range(-3,3): keys.append(Vector2i(x,z))
	keys.sort_custom(func(a: Vector2i,b: Vector2i): return (a-center).length_squared() < (b-center).length_squared())
	return keys

func neighborhood_ready(p: Vector3) -> bool:
	var center := key_at(p)
	for z in range(-1,2):
		for x in range(-1,2):
			var key := center+Vector2i(x,z)
			if key.x < -3 or key.x >= 3 or key.y < -3 or key.y >= 3: continue
			if not chunks.has(key) or chunks[key].revision != revision: return false
	return true

func rebuild() -> void:
	# Arena controls edit its ridge only; retain all other terrain and grounded actors.
	revision += 1
	for key in chunks:
		var area := Rect2(Vector2(key)*CHUNK,Vector2(CHUNK,CHUNK))
		if not area.intersects(Rect2(-31,4,42,20)): chunks[key].revision = revision
	walking = false
	ready_frames = 0
	frame_times.clear()

func _ready() -> void:
	super._ready()
	DisplayServer.window_set_title("SDF arena / Ringworld")
	terrain.material_override.set_shader_parameter("bridge_enabled",false)
	for child in get_children():
		if child is Label3D: child.queue_free()
		if child is WorldEnvironment: world_environment = child
		if child is DirectionalLight3D: sun = child
	camera.position = Vector3(-55,18,-60)
	camera.look_at(Vector3(18,4,5))
	look = Vector2(camera.rotation.y,camera.rotation.x)
	camera.near = 0.2
	camera.far = 3000000.0
	camera.make_current()
	player.collision_mask = 3 # Terrain plus the actors/trunks obstacle layer.
	ring_background = preload("res://world/arena_ring_background.gd").new()
	add_child(ring_background)
	ring_background.setup.call_deferred(self)

func _input(event: InputEvent) -> void:
	if OS.get_cmdline_user_args().has("--arena-capture"): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			var positions := [Vector3(-55,18,-60),Vector3(-38,4,-45),Vector3(5,4,-38),Vector3(23,9,-24)]
			var targets := [Vector3(18,4,5),Vector3(-28,1,-34),Vector3(23,1,-22),Vector3(43,5,-2)]
			var index: int = event.keycode-KEY_1
			walking = false
			camera.position = positions[index]
			camera.look_at(targets[index])
			look = Vector2(camera.rotation.y,camera.rotation.x)
			return
		if event.keycode == KEY_C:
			if ring_background.background_ready: ring_background._clouds.toggle_visible()
			return
	super._input(event)

func _physics_process(delta: float) -> void:
	if OS.get_cmdline_user_args().has("--arena-capture"): return
	super._physics_process(delta)
	camera.position.x = clampf(camera.position.x,-movement_limit(),movement_limit())
	camera.position.z = clampf(camera.position.z,-movement_limit(),movement_limit())
	if walking:
		player.position.x = clampf(player.position.x,-movement_limit(),movement_limit())
		player.position.z = clampf(player.position.z,-movement_limit(),movement_limit())

func movement_limit() -> float:
	return 90.0

func _process(delta: float) -> void:
	super._process(delta)
	if not content_started and ready_frames > 2 and ring_background.background_ready:
		content_started = true
		arena_content = preload("res://world/arena_content.gd").new()
		add_child(arena_content)
		arena_content.setup(self)
	var actors: int = arena_content.entries.size() if is_instance_valid(arena_content) else 0
	var trees: int = arena_content.tree_count if is_instance_valid(arena_content) else 0
	hud.text = "SDF ARENA / 192m clearing / 3000km ring x 50km\n1 overview | 2 Warthog | 3 aliens | 4 T-Rex | F walk/fly\nWASD + mouse | Space/Ctrl | Shift faster | T textures | C clouds | [ ] tunnel | R rock detail\n%s | terrain %d/36 | actors %d | trees %d | ring imagery %d/%d | %.0f FPS" % [
		"WALK" if walking else "FLY",chunks.size(),actors,trees,ring_background.previews_loaded,ring_background.preview_total,Engine.get_frames_per_second()]
	var complete: bool = ready_frames > 2 and is_instance_valid(arena_content) and arena_content.finished and ring_background.background_ready and ring_background._preview_thread == null and ring_background._preview_queue.is_empty() and not ring_background.home_pending
	if complete:
		arena_frames += 1
		if OS.get_cmdline_user_args().has("--arena-check") and not arena_checked:
			arena_checked = true
			check_arena.call_deferred()
		if OS.get_cmdline_user_args().has("--arena-capture") and arena_frames >= 120 and not capture_requested and (not OS.get_cmdline_user_args().has("--arena-check") or arena_verification_done):
			capture_requested = true
			capture_arena.call_deferred()

func check_arena() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(chunks.size() == 36)
	assert(neighborhood_ready(Vector3(89,0,89)))
	assert(arena_content.entries.size() == 5 and arena_content.tree_count > 0)
	assert(ring_background.previews_loaded == ring_background.preview_total)
	assert(is_equal_approx(ring_background._radius()*TAU,3000000.0))
	assert(ring_background._band.mesh.get_surface_count() > 0)
	for entry in arena_content.entries:
		var hit: Dictionary = arena_content.ground_at(entry.coord)
		assert(not hit.is_empty())
		assert(absf(entry.root.position.y-hit.position.y) < 0.4)
		# Verify the obstacle layer independently from the grounding layer.
		var centre: Vector3 = entry.root.position + Vector3.UP*entry.height*0.5
		var query := PhysicsRayQueryParameters3D.create(centre-Vector3(20,0,0),centre+Vector3(20,0,0),2)
		assert(not get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	assert(arena_field(Vector3(-10,3,14),tunnel_radius,roughness) > 0)
	var floor_hit: Dictionary = arena_content.ground_at(Vector2(-45,-45))
	player.position = floor_hit.position + Vector3.UP*0.1
	for frame in 30:
		player.velocity = Vector3(0,-2,3)
		player.move_and_slide()
		await get_tree().physics_frame
	assert(player.is_on_floor() and player.position.z > -44.0)
	floor_hit = arena_content.ground_at(Vector2(-28,-40))
	player.position = floor_hit.position + Vector3.UP*0.1
	for frame in 120:
		player.velocity = Vector3(0,-2,3)
		player.move_and_slide()
		await get_tree().physics_frame
	assert(player.position.z < -36.0, "Player passed through the Warthog")
	arena_verification_done = true
	print("PASS: arena and edge collision readiness, player floor contact and Warthog obstruction, five grounded actors, tree LOD batches, complete ring imagery and real ring dimensions")
	if not OS.get_cmdline_user_args().has("--arena-capture"): get_tree().quit()

func capture_arena() -> void:
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png("user://sdf-arena.png") == OK)
	print("ARENA_CAPTURE fps=",Engine.get_frames_per_second()," actors=",arena_content.entries.size()," trees=",arena_content.tree_count," ring_textures=",ring_background.previews_loaded)
	get_tree().quit()
