extends SceneTree
var arena: Node3D
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-output="): output=arg.trim_prefix("--tree-output=")
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(240).timeout.connect(func(): quit(1))
	run.call_deferred()
func run() -> void:
	arena=load("res://world/tree_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play: await process_frame
	while not arena.loading.ready_to_enter: await process_frame
	arena.loading.close()
	arena.vehicle_kit.driving=false;arena.vehicle_kit.car.freeze=true
	arena.set_tree_view(0);Engine.max_fps=0
	await create_timer(3).timeout
	var results := {}
	for mode in ["baseline","daylight","shadows","daylight_repeat"]:
		arena.daylight.shadow_quality=2;arena.daylight.baseline=mode=="baseline";arena.daylight.shadows=mode=="shadows"
		arena.daylight.apply();arena.daylight.refresh_casters()
		await create_timer(2).timeout
		var samples: Array[float]=[]
		for frame in range(360):
			var started := Time.get_ticks_usec()
			await process_frame;samples.append((Time.get_ticks_usec()-started)/1000.0)
		samples.sort();results[mode]={"median_ms":samples[180],"p95_ms":samples[342],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(mode+".png"))
		assert(arena.daylight.sun.shadow_enabled==(mode=="shadows"))
		for patch in [arena.trees,arena.painted_trees]:
			for key in patch.batches:
				assert((patch.batches[key].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON)==(mode=="shadows" and key.w<2))
	arena.editor.toggle();arena.daylight.dialog.popup_centered()
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("panel.png"))
	var file := FileAccess.open(output.path_join("results.json"),FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("DAYLIGHT_PASS ",JSON.stringify(results));quit()
