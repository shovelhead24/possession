extends SceneTree
var scene: Node3D
var output := ""
var passed := true
var reports: Array=[]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	create_timer(600).timeout.connect(func(): push_error("DRIVE_TIMEOUT");quit(1))
	run.call_deferred()

func require(condition: bool, message: String) -> void:
	if not condition: passed=false;push_error(message)

func run() -> void:
	root.size=Vector2i(1280,800)
	scene=load("res://world/terrain_drive.tscn").instantiate();root.add_child(scene)
	while not scene.ready_to_play: await process_frame
	Engine.max_fps=120
	var kit: Node=scene.vehicle_kit;var stream: Node=scene.streamer
	require(kit.car.corners.size()==4,"Four original Warthog wheels required")
	require(kit.saved_values.size()==17,"All 17 saved tuning and camera values must match")
	kit.test_controls=true;kit.test_throttle=0;kit.test_brake=true
	await create_timer(4).timeout
	await sample("stationary",12)
	kit.test_throttle=1;kit.test_brake=false
	await sample("bridge_drive",10)
	kit.test_throttle=0;kit.test_brake=true
	# Start within original collision coverage and drive into uncached exterior DEM tiles.
	require(await kit.place(Vector2(1300,350),-PI/2),"Starting ground missing")
	await create_timer(2).timeout
	require(Vector2(kit.car.position.x,kit.car.position.z).distance_to(Vector2(1300,350))<5,"Starting pose reset did not persist")
	kit.test_throttle=1;kit.test_brake=false
	await sample("cold_drive",65)
	kit.test_throttle=0;kit.test_brake=true
	var first_end: Vector3=kit.car.position
	require(first_end.x>1700,"Did not drive beyond original terrain")
	await settle_stream()
	# A new origin changes residency but must reload retained caches, never delete them.
	kit.driving=false;scene.camera.position=Vector3(1300,60,350);stream.plan()
	while not stream.ready_at(Vector3(1300,0,350)): await process_frame
	kit.driving=true;require(await kit.place(Vector2(1300,350),-PI/2),"Warm return ground missing")
	await create_timer(2).timeout
	require(Vector2(kit.car.position.x,kit.car.position.z).distance_to(Vector2(1300,350))<5,"Warm pose reset did not persist")
	await settle_stream()
	kit.test_throttle=1;kit.test_brake=false
	await sample("warm_drive",65)
	kit.test_throttle=0;kit.test_brake=true
	check_streamed_collision()
	stream.force_starvation=true
	await physics_frame;await physics_frame
	require(kit.car.streaming_suspended and kit.car.freeze,"Collision starvation did not freeze safely")
	var frozen: Vector3=kit.car.position
	for i in 12: await physics_frame
	require(kit.car.position.distance_to(frozen)<.001,"Frozen vehicle moved without collision")
	stream.force_starvation=false
	await physics_frame;await physics_frame
	require(not kit.car.streaming_suspended and not kit.car.freeze,"Vehicle did not recover from starvation")
	var file := FileAccess.open(output+"/terrain-drive-results.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"passed":passed,"configuration":kit.saved_values,"reports":reports},"\t"))
	print("TERRAIN_DRIVE_", "PASS" if passed else "FAIL")
	quit(0 if passed else 2)

func settle_stream() -> void:
	await create_timer(1).timeout
	while scene.streamer.worker or not scene.streamer.pending.is_empty() or not scene.streamer.stage.is_empty() or not scene.streamer.publish.is_empty() or scene.vehicle_kit.car.linear_velocity.length()>1:
		await process_frame

func check_streamed_collision() -> void:
	var key: Vector2i=scene.streamer.key_at(scene.vehicle_kit.car.position)
	var entry: Dictionary=scene.tile_entries[key]
	var faces: PackedVector3Array=entry.visual.mesh.get_faces()
	var centre := Vector2(key)*200+Vector2.ONE*100
	var largest_error := 0.0
	for offset in [Vector2(-.05,-.05),Vector2(.05,-.05),Vector2(-.05,.05),Vector2(.05,.05)]:
		var point: Vector2=centre+offset
		var origin := Vector3(point.x,scene.source.surface_height(point)+100,point.y)
		var hit := scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+Vector3.DOWN*200,1))
		var mesh_hit: Variant=null
		for i in range(0,faces.size(),3):
			var crossing: Variant=Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
			if crossing is Vector3 and (mesh_hit==null or crossing.y>mesh_hit.y): mesh_hit=crossing
		require(not hit.is_empty() and mesh_hit is Vector3,"Collision quadrant boundary has a hole")
		if not hit.is_empty() and mesh_hit is Vector3:
			largest_error=maxf(largest_error,hit.position.distance_to(mesh_hit))
	require(largest_error<.002,"Streamed collision does not match rendered full-detail triangles")
	print("DRIVE_COLLISION_MATCH max_error_m=",largest_error)

func sample(label: String, seconds: float) -> void:
	var kit: Node=scene.vehicle_kit;var stream: Node=scene.streamer
	var start_builds: int=stream.builds;var start_hits: int=stream.hits
	var start_freezes: int=kit.freeze_ticks;var start_brakes: int=kit.brake_ticks;var start_limited: int=kit.limited_ticks
	var peak_speed := 0.0;var active_frames := 0
	var min_z: float=kit.car.position.z
	var frames: Array[float]=[]
	var long_frames: Array=[]
	var began := Time.get_ticks_usec();var last := began
	while Time.get_ticks_usec()-began<int(seconds*1000000):
		await process_frame
		var now := Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
		if frames[-1]>16.667:
			long_frames.append({"time_s":(now-began)/1000000.0,"ms":frames[-1],"phase":stream.last_phase,"phase_ms":stream.last_phase_ms,"phase_age_ms":(now-stream.last_phase_at)/1000.0,"pending":stream.pending.size(),"worker":stream.worker!=null,"position":str(kit.car.position)})
		peak_speed=maxf(peak_speed,kit.car.linear_velocity.length())
		min_z=minf(min_z,kit.car.position.z)
		if label!="stationary":
			var desired := (Vector3(100-kit.car.position.x,0,-80) if label=="bridge_drive" else Vector3(80,0,350-kit.car.position.z)).normalized()
			var forward: Vector3=(-kit.car.basis.z).slide(Vector3.UP).normalized()
			kit.test_steer=clampf(forward.signed_angle_to(desired,Vector3.UP)*2,-1,1)
		if stream.worker or not stream.stage.is_empty() or not stream.publish.is_empty(): active_frames+=1
	var sum := 0.0;var misses := 0
	for value in frames: sum+=value;misses+=int(value>16.667)
	frames.sort()
	var report := {"label":label,"fps":frames.size()*1000/sum,"frames":frames.size(),"median_ms":frames[int(frames.size()*.5)],"p95_ms":frames[int(frames.size()*.95)],"p99_ms":frames[int(frames.size()*.99)],"max_ms":frames[-1],"over_budget":misses,"cold_tiles":stream.builds-start_builds,"cache_tiles":stream.hits-start_hits,"streaming_frames":active_frames,"peak_speed_mps":peak_speed,"freeze_ticks":kit.freeze_ticks-start_freezes,"brake_ticks":kit.brake_ticks-start_brakes,"power_limited_ticks":kit.limited_ticks-start_limited,"resident":scene.tile_entries.size(),"max_resident":stream.max_resident,"max_upload_phase_ms":stream.max_phase_ms,"end":str(kit.car.position),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	reports.append(report);print("DRIVE_FRAME ",JSON.stringify(report))
	print("DRIVE_LONG_FRAMES ",label," ",JSON.stringify(long_frames))
	require(report.p99_ms<=16.667,"Frame budget exceeded: "+label)
	require(report.freeze_ticks==0,"Unexpected collision starvation: "+label)
	require(report.max_resident<=450,"Resident terrain exceeded bound")
	if label in ["cold_drive","warm_drive"]: require(peak_speed>40,"Warthog failed to reach existing driving speed: "+label)
	if label=="bridge_drive": require(min_z<80,"Warthog did not pass under bridge")
	if label=="cold_drive": require(report.cold_tiles>0,"Cold route did not exercise generation")
	if label=="warm_drive": require(report.cache_tiles>0,"Warm route did not exercise disk reuse")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/warthog-"+label+".png")
