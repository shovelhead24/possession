extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/"
var arena: Node3D
var results={}
var guard_drive := false
var route_blocked := false
func _initialize():
	create_timer(600).timeout.connect(func(): push_error("PERFORMANCE_TIMEOUT");quit(1))
	run.call_deferred()
func sample(label: String, frames: int=360):
	for i in 120:
		await process_frame
		if guard_drive and not drive_clear():
			route_blocked=true;arena.vehicle_kit.test_throttle=0;arena.vehicle_kit.test_brake=true
	var times=[];var cpu=[];var physics=[];var last=Time.get_ticks_usec()
	for i in frames:
		await process_frame
		if guard_drive:
			if not drive_clear():
				route_blocked=true;arena.vehicle_kit.test_throttle=0;arena.vehicle_kit.test_brake=true
		var now=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
	times.sort();cpu.sort();physics.sort()
	var total=0.0
	for t in times: total+=t
	var d=arena.destruction
	results[label]={"mean_ms":total/times.size(),"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"p99_ms":times[int(times.size()*.99)],"max_ms":times[-1],"cpu_p95_ms":cpu[int(cpu.size()*.95)],"physics_p95_ms":physics[int(physics.size()*.95)],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"warmed_tiles":d.warmed_tiles,"terrain_busy":d.busy(),"trees":arena.painted_trees.counts,"forge_ms":arena.forge.update_ms,"ai_us":arena.aliens.physics_usec}
	print("PERF ",label," ",JSON.stringify(results[label]))
	FileAccess.open(OUT+"performance-isolation.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
func run():
	root.size=Vector2i(1366,768);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	arena=load("res://world/performance_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path and "sky-test" in arena.destruction.save_path)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"performance-briefing.png")
	arena.loading.close();lock_input(arena);arena.on_foot.deactivate();arena.vehicle_kit.driving=true;arena.vehicle_kit.test_controls=true;arena.vehicle_kit.test_throttle=0;arena.vehicle_kit.test_brake=true;arena.controller.set_physics_process(false)
	for i in 360: await process_frame
	await sample("final_live_idle",240)
	# Keep the population fixed while comparing passive diagnostic cadence.
	arena.aliens.process_mode=Node.PROCESS_MODE_DISABLED;arena.actors.set_physics_process(false)
	for rex in get_nodes_in_group("tyrants"): rex.set_physics_process(false);rex.runtime_active=false
	for i in 2:
		arena.jitter_trace.passive_sample_interval=0
		await sample("full_rate_preroll_"+str(i),240)
		arena.jitter_trace.passive_sample_interval=.1
		await sample("reduced_preroll_"+str(i),240)
	# Capture records return to physics rate immediately.
	arena.jitter_trace.active_id=999
	var before=arena.jitter_trace.history.size();var cursor=arena.jitter_trace.cursor
	for i in 10: await physics_frame
	assert(arena.jitter_trace.cursor!=cursor or arena.jitter_trace.history.size()>before)
	arena.jitter_trace.active_id=0;arena.jitter_trace.pending.clear();arena.jitter_trace.pending_frames.clear()
	arena.aliens.process_mode=Node.PROCESS_MODE_INHERIT;arena.actors.set_physics_process(true)
	for rex in get_nodes_in_group("tyrants"): rex.set_physics_process(true)
	var clear_route=await select_drive_route()
	guard_drive=true;route_blocked=not clear_route;arena.vehicle_kit.test_brake=not clear_route;arena.vehicle_kit.test_throttle=.35 if clear_route else 0.0
	await sample("driving",180)
	guard_drive=false;results.driving.valid=not route_blocked;results.driving.obstacle_stop=route_blocked
	arena.vehicle_kit.test_throttle=0;arena.vehicle_kit.test_brake=true
	await sample("stopped_after_drive",180)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"performance-final-driving.png")
	var car=arena.vehicle_kit.car.global_position;var up=preload("res://world/terrain_drive_ring.gd").up_at(car)
	arena.vehicle_kit.driving=false;arena.camera.global_position=car+up*5
	arena.camera.look_at(car+Vector3(0,0,18),up)
	var revision=arena.destruction.applied_revision
	arena.throw_grenade()
	var start=Time.get_ticks_msec()
	while arena.destruction.applied_revision==revision and Time.get_ticks_msec()-start<15000: await process_frame
	assert(arena.destruction.applied_revision>revision,"Crater must publish")
	results.crater={"worker_ms":arena.destruction.last_worker_ms,"publish_ms":arena.destruction.last_update_ms}
	await sample("after_crater",180)
	FileAccess.open(OUT+"performance-final.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("PASS full scene idle, diagnostic cadence, drive/stop and crater")
	quit()

func lock_input(node: Node) -> void:
	node.set_process_input(false);node.set_process_unhandled_input(false);node.set_process_unhandled_key_input(false)
	for child in node.get_children(): lock_input(child)

func drive_clear() -> bool:
	assert(arena.vehicle_kit.driving and not arena.on_foot.active,"Benchmark must remain in vehicle")
	var car=arena.vehicle_kit.car
	var query=PhysicsShapeQueryParameters3D.new();var shape=BoxShape3D.new();shape.size=Vector3(3.8,2.5,5.5)
	query.shape=shape;query.transform=car.global_transform;query.transform.origin+=car.global_basis.y*1.5
	query.collision_mask=6;query.exclude=[car.get_rid(),arena.on_foot.get_rid()]
	query.motion=-car.global_basis.z*maxf(15.0,car.linear_velocity.length()*3.0)
	var space=arena.get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty(): return false
	return space.cast_motion(query)[0]>=.999

func select_drive_route() -> bool:
	var kit=arena.vehicle_kit;var car=kit.car
	var ring=preload("res://world/terrain_drive_ring.gd")
	var query=PhysicsShapeQueryParameters3D.new();var shape=BoxShape3D.new();shape.size=Vector3(3.8,2.5,5.5)
	query.shape=shape;query.collision_mask=6;query.exclude=[car.get_rid(),arena.on_foot.get_rid()]
	var space=arena.get_world_3d().direct_space_state;var best=0.0;var yaw=0.0
	for index in 24:
		var angle=index*TAU/24.0
		var basis=ring.tangent_basis(car.global_position,angle)
		query.transform=Transform3D(basis,car.global_position+basis.y*1.5);query.motion=-basis.z*60
		if not space.intersect_shape(query,1).is_empty(): continue
		var fraction=space.cast_motion(query)[0]
		if fraction>best: best=fraction;yaw=angle
	results.route={"clear_distance_m":best*60,"yaw":yaw}
	if best*60<30: print("SKIP driving: no clear 30 m corridor");return false
	var p=ring.coordinates(car.global_position)
	return await kit.place(Vector2(p.x,p.z),yaw)
