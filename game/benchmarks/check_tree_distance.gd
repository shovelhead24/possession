extends SceneTree
var arena: Node3D
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-output="): output=arg.trim_prefix("--tree-output=")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(360).timeout.connect(func(): push_error("Distance test timed out");quit(1))
	run.call_deferred()
func settle() -> void:
	await create_timer(.6).timeout
	while arena.streamer.worker or not arena.streamer.pending.is_empty() or not arena.streamer.stage.is_empty() or not arena.streamer.publish.is_empty() or arena.edited_render_lods.worker:
		await process_frame
	await create_timer(3).timeout
func measure(label: String, results: Array) -> void:
	await create_timer(1).timeout
	var samples: Array[float]=[]
	for i in range(180):
		var started := Time.get_ticks_usec();await process_frame;samples.append((Time.get_ticks_usec()-started)/1000.0)
	samples.sort()
	var data := {"label":label,"median_ms":samples[90],"p95_ms":samples[171],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"pending":arena.streamer.pending.size(),"tree_lods":arena.painted_trees.counts.duplicate(),"edited_lods":arena.edited_render_lods.published}
	results.append(data);print("DISTANCE_SAMPLE ",JSON.stringify(data))
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run() -> void:
	arena=load("res://world/tree_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	arena.loading.close();arena.vehicle_kit.driving=false;arena.vehicle_kit.car.freeze=true;Engine.max_fps=0
	var results: Array=[]
	# First view retains edited mountain tiles while looking back from beyond tree range.
	arena.camera.position=Vector3(900,150,180);arena.camera.look_at(Vector3(100,45,260),Vector3.UP)
	await settle()
	var bodies := {};var vertices := {}
	for key in arena.tile_entries:
		var entry: Dictionary=arena.tile_entries[key]
		bodies[key]=entry.body.get_instance_id();vertices[key]=entry.visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	arena.daylight.shadows=false;arena.daylight.apply()
	arena.edited_render_lods.enabled=false
	await measure("mountain-full",results)
	arena.edited_render_lods.enabled=true
	await measure("mountain-lods",results)
	for key in bodies:
		if arena.tile_entries.has(key):
			assert(bodies[key]==arena.tile_entries[key].body.get_instance_id())
			assert(vertices[key]==arena.tile_entries[key].visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	arena.daylight.shadows=true;arena.daylight.apply();await measure("mountain-balanced",results)
	# Reproduce the last recorded camera pose, then wait until all stream work is done.
	arena.camera.position=Vector3(2090.81494,116.34547,153.80762);arena.camera.rotation=Vector3(-.3306658,2.70522475,0)
	arena.vehicle_kit.car.position=Vector3(2088.35498,112.94085,159.09645)
	await settle()
	arena.daylight.shadows=false;arena.daylight.apply();await measure("capture-settled",results)
	arena.trees.set_enabled(false);arena.painted_trees.set_enabled(false);await measure("capture-no-trees",results)
	# Isolate diagnostic overhead and distant presentation after settling.
	arena.jitter_trace.set_process(false);arena.jitter_trace.set_physics_process(false)
	await measure("capture-no-recorder",results)
	arena.backdrop.visible=false;arena.backdrop.set_process(false)
	await measure("capture-no-backdrop",results)
	arena.backdrop.visible=true;arena.backdrop.set_process(true)
	arena.jitter_trace.set_process(true);arena.jitter_trace.set_physics_process(true)
	await measure("capture-repeat",results)
	var context: Dictionary=arena.jitter_trace.frame_context()
	assert(context.has("lighting") and context.has("trees") and context.has("edited_lods"))
	var file := FileAccess.open(output.path_join("results.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"runs":results,"lod_full":arena.edited_render_lods.triangles_full,"lod_coarse":arena.edited_render_lods.triangles_coarse,"trace":context},"\t"));file.close()
	print("DISTANCE_PASS: collision identities and vertex arrays unchanged; F8 settings present");quit()
