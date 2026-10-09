extends SceneTree
const Ring = preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-output="): output=arg.trim_prefix("--tree-output=")
	assert(not output.is_empty())
	assert(Array(OS.get_cmdline_user_args()).any(func(arg): return arg.begins_with("--drive-edits-file=")))
	assert(Array(OS.get_cmdline_user_args()).any(func(arg): return arg.begins_with("--tree-paint-file=")))
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(300).timeout.connect(func(): push_error("Shadow benchmark timed out");quit(1))
	run.call_deferred()
func run() -> void:
	arena=load("res://world/tree_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play: await process_frame
	while not arena.loading.ready_to_enter: await process_frame
	arena.loading.close();arena.vehicle_kit.driving=false;arena.vehicle_kit.car.freeze=true
	var ground: Vector3=arena.tree_view_ground(Vector2(120,265))
	arena.camera.position=ground+Ring.up_at(ground)*4
	var target: Vector3=arena.tree_view_ground(Vector2(120,355))
	arena.camera.look_at(target+Ring.up_at(target)*3,Ring.up_at(ground));Engine.max_fps=0
	await create_timer(8).timeout
	var results := {"painted_trees":arena.painted_trees.store.records.size(),"runs":[]}
	for mode in ["off","detailed","balanced","fast","detailed","balanced","off"]:
		arena.daylight.shadow_quality=2 if mode=="detailed" else (1 if mode=="fast" else 0)
		arena.daylight.shadows=mode!="off";arena.daylight.apply();arena.daylight.refresh_casters()
		await create_timer(1.5).timeout
		var samples: Array[float]=[]
		for frame in range(240):
			var started := Time.get_ticks_usec();await process_frame
			samples.append((Time.get_ticks_usec()-started)/1000.0)
		samples.sort()
		var data := {"mode":mode,"median_ms":samples[120],"p95_ms":samples[228],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"proxy_update_ms":arena.daylight.proxies.update_ms}
		results.runs.append(data);print("SHADOW_SAMPLE ",JSON.stringify(data))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(mode+".png"))
		assert(arena.daylight.proxies.visible==(mode in ["balanced","fast"]))
		for patch in [arena.trees,arena.painted_trees]:
			for key in patch.batches:
				assert((patch.batches[key].cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON)==(mode=="detailed" and key.w<2))
	# Edge view exposes the shadow silhouette and ground contact rather than leaf overdraw.
	ground=arena.tree_view_ground(Vector2(120,180));arena.camera.position=ground+Ring.up_at(ground)*6
	target=arena.tree_view_ground(Vector2(120,275));arena.camera.look_at(target+Ring.up_at(target)*3,Ring.up_at(ground))
	for quality in [2,0,1]:
		arena.daylight.shadows=true;arena.daylight.shadow_quality=quality;arena.daylight.apply()
		await create_timer(2).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("edge-%d.png" % quality))
	# F6-style visibility, baseline comparison and transform refresh must remove ghost shadows.
	arena.daylight.shadows=true;arena.daylight.shadow_quality=0;arena.daylight.apply()
	arena.trees.set_enabled(false);arena.painted_trees.set_enabled(false);arena.daylight.refresh_casters()
	assert(arena.daylight.proxies.tree_count==0 and arena.daylight.proxies.batches.is_empty())
	arena.trees.set_enabled(true);arena.painted_trees.set_enabled(true);arena.daylight.refresh_casters()
	assert(arena.daylight.proxies.tree_count>0)
	arena.daylight.baseline=true;arena.daylight.apply();arena.daylight.refresh_casters()
	assert(not arena.daylight.proxies.visible and not arena.daylight.sun.shadow_enabled)
	arena.daylight.baseline=false;arena.daylight.apply();arena.daylight.refresh_casters()
	arena.editor.toggle();arena.daylight.dialog.popup_centered()
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("panel.png"))
	var file := FileAccess.open(output.path_join("results.json"),FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("SHADOW_OPT_PASS");quit()
