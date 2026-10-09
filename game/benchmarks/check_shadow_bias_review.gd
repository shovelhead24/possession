extends SceneTree
var arena: Node3D
var output := "C:/Users/Bran the builder/Documents/Codex/2026-10-08/we-x20/outputs/shadow-cascade-review/bias"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(output)
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
	for view in ["car","trees"]:
		if view=="trees": arena.set_tree_view(0)
		await create_timer(2).timeout
		for mode in ["original", "bias_half", "bias_one", "less_blur", "four_bias", "original_repeat"]:
			var sun: DirectionalLight3D=arena.daylight.sun
			sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if mode=="four_bias" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_split_1=.12;sun.directional_shadow_split_2=.30;sun.directional_shadow_split_3=.60
			sun.directional_shadow_blend_splits=false
			sun.shadow_normal_bias=0.5 if mode=="bias_half" else (1.0 if mode in ["bias_one","less_blur","four_bias"] else 3.0)
			sun.shadow_blur=0.5 if mode=="less_blur" else 1.0
			RenderingServer.directional_shadow_atlas_set_size(2048,false)
			await create_timer(.5).timeout
			var times: Array[float]=[]
			for i in 120:
				var started := Time.get_ticks_usec();await process_frame;times.append((Time.get_ticks_usec()-started)/1000.0)
			times.sort()
			var label: String=view+"_"+mode
			results[label]={"median_ms":times[60],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(label+".png"))
			print(label," ",results[label])
	var file := FileAccess.open(output.path_join("results.json"),FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("SHADOW_CASCADE_REVIEW_PASS");quit()
