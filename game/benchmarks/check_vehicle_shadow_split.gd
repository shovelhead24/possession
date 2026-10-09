extends SceneTree
var arena: Node3D
var output := ""
var pose_path := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-output="): output=arg.trim_prefix("--tree-output=")
		if arg.begins_with("--shadow-pose="): pose_path=arg.trim_prefix("--shadow-pose=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	create_timer(240).timeout.connect(func(): quit(1))
	run.call_deferred()
func vec(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
func shot(label: String) -> void:
	await create_timer(.5).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
	arena=load("res://world/tree_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	arena.loading.close();arena.vehicle_kit.driving=false;arena.vehicle_kit.car.freeze=true
	await physics_frame
	var pose: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(pose_path))
	arena.vehicle_kit.car.position=vec(pose.car_position);arena.vehicle_kit.car.rotation=vec(pose.car_rotation);arena.vehicle_kit.car.reset_physics_interpolation()
	arena.camera.position=vec(pose.camera_position);arena.camera.rotation=vec(pose.camera_rotation)
	arena.daylight.energy=2;arena.daylight.shadows=true;arena.daylight.shadow_quality=0;arena.daylight.apply()
	await create_timer(3).timeout
	var lights := arena.find_children("*","Light3D",true,false);print("SHADOW_LIGHT_COUNT ",lights.size())
	for light in lights: print("LIGHT ",light.get_path()," shadow=",light.shadow_enabled)
	await shot("original-split")
	arena.daylight.sun.directional_shadow_split_1=.22
	await shot("wider-near-split")
	arena.daylight.sun.directional_shadow_split_1=.1;arena.daylight.sun.directional_shadow_blend_splits=true
	await shot("blended-split")
	arena.daylight.sun.directional_shadow_blend_splits=false
	for node in arena.vehicle_kit.car.find_children("*","GeometryInstance3D",true,false): node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await shot("vehicle-casters-off")
	arena.editor.toggle();arena.daylight.dialog.popup_centered();await shot("editor-pass-panel")
	print("VEHICLE_SHADOW_CHECK_PASS");quit()
