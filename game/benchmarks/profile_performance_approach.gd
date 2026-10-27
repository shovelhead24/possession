extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/"
const Ring=preload("res://world/terrain_drive_ring.gd")
const START=Vector2(120,145)
const TARGET=Vector2(-4,252)
var arena: Node3D
var times: Array=[]
var results={"start":[120,145],"target":[-4,252],"route":"Diagonal gap between construction and trees"}
func _initialize():
	create_timer(600).timeout.connect(func():push_error("APPROACH_TIMEOUT");quit(1))
	run.call_deferred()
func lock_input(node: Node):
	node.set_process_input(false);node.set_process_unhandled_input(false);node.set_process_unhandled_key_input(false)
	for child in node.get_children():lock_input(child)
func capture(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func stats(samples: Array) -> Dictionary:
	var sorted=samples.duplicate();sorted.sort();var total=0.0
	for value in sorted:total+=value
	return {"frames":sorted.size(),"mean_ms":total/maxi(1,sorted.size()),"p95_ms":sorted[int(sorted.size()*.95)] if not sorted.is_empty() else 0}
func clear_ahead() -> bool:
	var car=arena.vehicle_kit.car;var q=PhysicsShapeQueryParameters3D.new();var box=BoxShape3D.new();box.size=Vector3(3.4,2.2,5)
	q.shape=box;q.transform=car.global_transform;q.transform.origin+=car.global_basis.y*1.4;q.collision_mask=6;q.exclude=[car.get_rid(),arena.on_foot.get_rid()]
	q.motion=-car.global_basis.z*maxf(9.0,car.linear_velocity.length()*2.5)
	var space=arena.get_world_3d().direct_space_state
	var overlap=space.intersect_shape(q,1)
	if not overlap.is_empty():
		results.blocker=str(overlap[0].collider.get_path());return false
	var safe=space.cast_motion(q)[0]
	if safe<.999:
		q.transform.origin+=q.motion*minf(1.0,safe+.02);q.motion=Vector3.ZERO
		var hits=space.intersect_shape(q,4);var names=[]
		for hit in hits:names.append(str(hit.collider.get_path()))
		results.blocker=names;return false
	return true
func run():
	root.size=Vector2i(1366,768);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	arena=load("res://world/performance_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter:await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path and "sky-test" in arena.destruction.save_path)
	await capture("performance-briefing")
	arena.loading.close();lock_input(arena);arena.controller.set_physics_process(false)
	arena.on_foot.deactivate();var kit=arena.vehicle_kit;kit.driving=true;kit.test_controls=true;kit.test_throttle=0;kit.test_brake=true
	kit.driver_look=Vector2.ZERO;kit.menu.settings.camera_mode=0
	var heading=TARGET-START
	assert(await kit.place(START,atan2(heading.x,heading.y)))
	for i in 240:await process_frame
	await capture("approach-start")
	var last=Time.get_ticks_usec()
	for i in 180:
		await process_frame;var now=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
	results.open_ground=stats(times);times.clear()
	results.open_ground.draws=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	results.open_ground.primitives=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	results.low_poly_tanks=kit.vehicles.filter(func(vehicle):return vehicle.get_script()==preload("res://world/performance_tank.gd")).size()
	assert(results.low_poly_tanks>0,"Performance scene must restore the low-poly tank")
	var began=Time.get_ticks_msec();var reason="timeout";var minimum_distance=INF
	while Time.get_ticks_msec()-began<60000:
		await process_frame
		assert(kit.driving and not arena.on_foot.active)
		var now=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
		var p=Ring.coordinates(kit.car.global_position);var offset=TARGET-Vector2(p.x,p.z);minimum_distance=minf(minimum_distance,offset.length())
		if offset.length()<22:reason="arrived";break
		if not clear_ahead():reason="obstacle stop";break
		var target_yaw=atan2(offset.x,offset.y);var yaw=Ring.tangent_yaw(kit.car.global_position,-kit.car.global_basis.z)
		kit.test_steer=clampf(wrapf(target_yaw-yaw,-PI,PI)*1.8,-.5,.5)
		var desired_speed=9.0 if offset.length()>45 else 5.0
		var speed=kit.car.linear_velocity.length()
		kit.test_throttle=clampf((desired_speed-speed)*.2,0,.55);kit.test_brake=speed>desired_speed+1.0
	kit.test_throttle=0;kit.test_steer=0;kit.test_brake=true
	results.approach=stats(times);results.approach.reason=reason;results.approach.valid=reason=="arrived";results.approach.minimum_distance=minimum_distance
	results.approach.draws=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	results.approach.primitives=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	for i in 120:await process_frame
	await capture("approach-stop")
	FileAccess.open(OUT+"performance-approach.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("APPROACH_RESULT ",JSON.stringify(results));quit(0 if reason=="arrived" else 2)

