extends SceneTree
var arena: Node3D
var output := "C:/Users/Bran the builder/Documents/Codex/2026-10-08/we-x20/outputs/shadow-cascade-review"
func _initialize() -> void:
	create_timer(240).timeout.connect(func(): quit(1))
	run.call_deferred()
func vec(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
func run() -> void:
	arena=load("res://world/tree_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	arena.loading.close();arena.vehicle_kit.driving=false;arena.vehicle_kit.car.freeze=true;arena.diagnostic=true
	await physics_frame
	var pose: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("C:/Users/Bran the builder/Documents/Codex/2026-10-08/we-x20/work/shadow-cascade-review/pose.json"))
	arena.vehicle_kit.car.position=vec(pose.car_position);arena.vehicle_kit.car.rotation=vec(pose.car_rotation);arena.vehicle_kit.car.reset_physics_interpolation()
	arena.camera.position=vec(pose.camera_position);arena.camera.rotation=vec(pose.camera_rotation)
	arena.daylight.shadows=true;arena.daylight.shadow_distance=121;arena.daylight.near_split_percent=12;arena.daylight.apply()
	Engine.max_fps=0
	await create_timer(4).timeout
	var results := {}
	for mode in ["recorded", "four", "four_blend", "four_4096", "two_4096", "recorded_repeat"]:
		var sun: DirectionalLight3D=arena.daylight.sun
		sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if mode.begins_with("four") else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_split_1=.12;sun.directional_shadow_split_2=.30;sun.directional_shadow_split_3=.60
		sun.directional_shadow_blend_splits=mode=="four_blend"
		RenderingServer.directional_shadow_atlas_set_size(4096 if mode.ends_with("4096") else 2048,false)
		await create_timer(1).timeout
		var times: Array[float]=[]
		for i in 180:
			var started := Time.get_ticks_usec();await process_frame;times.append((Time.get_ticks_usec()-started)/1000.0)
		times.sort()
		results[mode]={"median_ms":times[90],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(mode+".png"))
		print(mode," ",results[mode])
	var file := FileAccess.open(output.path_join("results.json"),FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("SHADOW_CASCADE_REVIEW_PASS");quit()
