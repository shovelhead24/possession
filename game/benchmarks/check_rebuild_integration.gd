extends SceneTree
var arena: Node3D
var output := "C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rebuild-output="): output=arg.trim_prefix("--rebuild-output=")
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(240).timeout.connect(func(): push_error("Rebuild integration timeout");quit(1))
	run.call_deferred()
func summary(samples: Array) -> Dictionary:
	var sorted := samples.duplicate();sorted.sort();var total := 0.0
	for v in samples: total+=v
	return {"frames":samples.size(),"mean_ms":total/samples.size(),"average_fps":1000.0/(total/samples.size()),"p95_ms":sorted[int(sorted.size()*.95)],"p99_ms":sorted[int(sorted.size()*.99)]}
func measure(moving: bool) -> Dictionary:
	for i in 90: await process_frame
	var values := [];var draws := [];var triangles := [];var prev := Time.get_ticks_usec()
	var start: Transform3D=arena.camera.transform
	for i in 240:
		if moving: arena.camera.position=start.origin+start.basis.x*(sin(float(i)/240*TAU)*8)
		await process_frame
		var now := Time.get_ticks_usec();values.append((now-prev)/1000.0);prev=now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		triangles.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	arena.camera.transform=start
	var result := summary(values);result["draws_last"]=draws.back();result["primitives_last"]=triangles.back();return result
func run() -> void:
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	arena.loading.close();arena.vehicle_kit.car.freeze=true
	for i in 60: await physics_frame
	for attempt in 100:
		if arena.rebuild_content.building: break
		await create_timer(.25).timeout
	assert(arena.rebuild_content.building!=null,"Building must place on actual saved terrain")
	var building: Node3D=arena.rebuild_content.building
	arena.vehicle_kit.driving=false;arena.diagnostic=true
	arena.camera.position=building.global_transform*Vector3(12,7,16)
	arena.camera.look_at(building.global_transform*Vector3(0,1.5,0),building.basis.y)
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("rebuild-building.png"))
	var results := {"device":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),"target_ms":8.333,"notes":"Matched camera; stationary and camera strafe. No claim of driving-route performance."}
	# Alternate component off/on at the identical camera path.
	arena.rebuild_content.set_physics_process(false);building.visible=false
	results["baseline_stationary"]=await measure(false)
	building.visible=true
	results["building_stationary"]=await measure(false)
	building.visible=false
	results["baseline_camera_route"]=await measure(true)
	building.visible=true
	results["building_camera_route"]=await measure(true)
	arena.rebuild_content.set_physics_process(true)
	# Place the real player in the preserved doorway and walk into the interior.
	arena.on_foot.activate_at(building.global_transform*Vector3(0,-arena.rebuild_content.entrance_rise*.875+.15,10.5))
	arena.on_foot.yaw=0
	arena.on_foot.test_controls=true
	for i in 60: await physics_frame
	arena.on_foot.test_move=Vector2(0,-1)
	for i in 70: await physics_frame
	arena.on_foot.test_move=Vector2.ZERO
	for i in 10: await physics_frame
	assert(arena.on_foot.is_on_floor(),"Player must stand on original building floor")
	var local: Vector3=building.global_transform.affine_inverse()*arena.on_foot.global_position
	assert(absf(local.x)<1 and local.y<.3 and local.z<6.5,"Player must walk up ramp and through doorway")
	var event := InputEventKey.new();event.keycode=KEY_F1;event.pressed=true
	arena._input(event);assert(arena.editor.opened)
	arena._input(event);assert(not arena.editor.opened and arena.on_foot.active)
	results["foot_ramp_doorway_floor_editor"]="passed"
	var file := FileAccess.open(output.path_join("rebuild-performance.json"),FileAccess.WRITE);file.store_string(JSON.stringify(results,"	"));file.close()
	print("REBUILD_INTEGRATION_PASS ",JSON.stringify(results));quit()



