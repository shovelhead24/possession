extends SceneTree
var scene: Node

func _initialize() -> void:
	create_timer(600).timeout.connect(func(): push_error("Drive test timed out");quit(1))
	run.call_deferred()

func run() -> void:
	var stress := OS.get_cmdline_user_args().has("--stress-course")
	scene=load("res://world/sdf_stress_course.tscn" if stress else "res://world/sdf_authoring.tscn").instantiate();root.add_child(scene)
	while not scene.live_kit(): await process_frame
	while not scene.far_terrain.finished() or scene.ready_frames<3: await process_frame
	var kit: Node=scene.live_kit()
	scene.switch_editor_mode(false);kit.test_vehicle_controls=true;kit.enter_vehicle()
	var turning := OS.get_cmdline_user_args().has("--turning")
	if turning: kit.vehicle_system.test_steer=.18
	var car: Node=kit.vehicle
	var started := Time.get_ticks_msec()
	var ticks := 0;var braking := 0;var frozen := 0;var peak := 0.0
	var fast := 0;var max_brake_change := 0.0;var last_brake := 0.0
	var limited := 0;var minimum_drive := 1.0
	var start_position: Vector3=car.position
	var minimum_z: float=car.position.z
	var last_tick := Time.get_ticks_usec()
	var max_tick_gap_ms := 0.0
	var stage_samples := {}
	while Time.get_ticks_msec()-started<(75000 if stress else (35000 if turning else 18000)):
		await physics_frame
		ticks+=1;peak=maxf(peak,car.linear_velocity.length())
		if car.linear_velocity.length()>43: fast+=1
		if car.stream_braking: braking+=1
		if car.stream_drive_scale<.999: limited+=1
		minimum_drive=minf(minimum_drive,car.stream_drive_scale)
		minimum_z=minf(minimum_z,car.position.z)
		var now := Time.get_ticks_usec()
		max_tick_gap_ms=maxf(max_tick_gap_ms,(now-last_tick)/1000.0);last_tick=now
		var stage := clampi(1+floori((-car.position.z-120)/176),0,3)
		if not stage_samples.has(stage): stage_samples[stage]={"ticks":0,"brakes":0,"power_limited":0,"peak_speed":0.0}
		stage_samples[stage].ticks+=1
		stage_samples[stage].brakes+=int(car.stream_braking)
		stage_samples[stage].power_limited+=int(car.stream_drive_scale<.999)
		stage_samples[stage].peak_speed=maxf(stage_samples[stage].peak_speed,car.linear_velocity.length())
		if car.streaming_suspended: frozen+=1
		max_brake_change=maxf(max_brake_change,absf(car.stream_brake_amount-last_brake))
		last_brake=car.stream_brake_amount
		if stress and car.position.z<=-620: break
	print("STREAM_DRIVE_RESULT ",JSON.stringify({"ticks":ticks,"braking_ticks":braking,"frozen_ticks":frozen,"peak_speed":peak,"ticks_above_43":fast,"max_brake_step":max_brake_change,"resident_chunks":scene.chunks.size(),"power_limited_ticks":limited,"minimum_drive_scale":minimum_drive,"start_position":str(start_position),"end_position":str(car.position),"minimum_z":minimum_z,"stress":stress}))
	print("STREAM_DRIVE_STAGES ",JSON.stringify({"stages":stage_samples,"max_physics_wall_gap_ms":max_tick_gap_ms,"chunk_profiles":scene.install_profiles}))
	# Sustained steering scrubs speed through tyre physics; test supply separately.
	if not stress and not require(peak>(40 if turning else 43),"Unexpected speed loss"): return
	# Power taper is the intended first fallback; report it, do not confuse it
	# with the binary braking fault. Full-speed capability is checked above.
	if not stress and not require(braking==0,"Streaming braking returned on this route"): return
	if not require(frozen==0,"Unexpected collision starvation"): return
	kit.vehicle_system.test_starvation=true
	for i in 3: await physics_frame
	if not require(car.streaming_suspended and car.freeze,"Missing-collision safeguard lost"): return
	kit.vehicle_system.test_starvation=false
	for i in 3: await physics_frame
	if not require(not car.streaming_suspended,"Safeguard failed to recover"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://stress-drive-latest.png" if stress else "user://stream-drive-latest.png")
	print("STREAM_DRIVE_SAFEGUARDS_PASS" if stress else "STREAM_DRIVE_PASS");quit()

func require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message);quit(1)
	return condition
