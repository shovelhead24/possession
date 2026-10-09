extends SceneTree
var arena: Node3D
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-output="): output=arg.trim_prefix("--tree-output=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	create_timer(240).timeout.connect(func(): push_error("On-foot integration timeout");quit(1))
	run.call_deferred()
func key(code: int) -> void:
	var event := InputEventKey.new();event.keycode=code;event.pressed=true;arena._input(event)
func run() -> void:
	arena=load("res://world/tree_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	arena.loading.close();arena.vehicle_kit.car.freeze=true
	await physics_frame
	key(KEY_E);assert(arena.on_foot.active and not arena.vehicle_kit.driving)
	arena.on_foot.test_controls=true
	for i in 20: await physics_frame
	assert(arena.on_foot.is_on_floor())
	var feet: Vector3=arena.on_foot.position
	key(KEY_F1);assert(arena.editor.opened)
	arena.camera.position+=Vector3(50,30,50)
	await create_timer(.3).timeout;assert(arena.on_foot.position.distance_to(feet)<.01)
	key(KEY_F1);assert(not arena.editor.opened and arena.on_foot.active)
	await process_frame
	assert(arena.camera.position.distance_to(arena.on_foot.position)<2)
	var context: Dictionary=arena.jitter_trace.frame_context();assert(context.movement_mode=="on_foot")
	arena.on_foot.test_move=Vector2(0,-1)
	for i in 12: await physics_frame
	arena.on_foot.test_move=Vector2.ZERO
	assert(arena.on_foot.position.distance_to(feet)>.6)
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("on-foot.png"))
	key(KEY_E);assert(arena.vehicle_kit.driving and not arena.on_foot.active)
	key(KEY_F1);key(KEY_F1);assert(arena.vehicle_kit.driving)
	assert(arena.jitter_trace.frame_context().movement_mode=="driving")
	print("ON_FOOT_EDITOR_PASS: E exit/enter, WASD camera ownership, F1 return to walking/driving, F8 modes")
	quit()
