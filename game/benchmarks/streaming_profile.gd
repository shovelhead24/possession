extends "res://world/sdf_arena_expanded.gd"
## Real Warthog physics on a fixed requested route. Compare distance AND frame time:
## streaming backpressure intentionally makes the realised trajectory differ.
var run_cache := "trial1"
var run_label := "cold"
var duration := 20.0
var mode := "indexed"
var phase := 0
var settled := 0.0
var start_usec := 0
var previous_usec := 0
var frame_ms: Array[float]=[]
var trajectory: Array[Dictionary]=[]
var profile_start := 0
var startup_usec := 0
var previous_position := Vector3.ZERO
var travelled := 0.0
var simulation_seconds := 0.0
var limited_seconds := 0.0
var suspended_seconds := 0.0
var sample_ticks := 0
var waypoint := 0
var route: Array[Vector3]=[Vector3(-28,0,-160),Vector3(-60,0,-200),Vector3(-80,0,-64),Vector3(-28,0,-34)]
var kit: Node
var car: RigidBody3D

func _ready() -> void:
	startup_usec=Time.get_ticks_usec()
	for arg in OS.get_cmdline_user_args():
		if arg=="--mesher-legacy": mode="legacy"
		if arg.begins_with("--profile-cache="): run_cache=arg.get_slice("=",1).validate_filename()
		if arg.begins_with("--profile-label="): run_label=arg.get_slice("=",1).validate_filename()
		if arg.begins_with("--profile-seconds="): duration=maxf(5,float(arg.get_slice("=",1)))
	super._ready()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	DisplayServer.window_set_title("Streaming profile / "+mode+" / "+run_label)

func cache_folder_for(spacing: float) -> String:
	if is_equal_approx(spacing,2): return "user://streaming-profile-cache/"+run_cache+"/"+mode+"/"
	return CACHE_FOLDER

func _input(_event: InputEvent) -> void:
	pass

func _physics_process(delta: float) -> void:
	if phase==1:
		kit.vehicle_system.tick(delta,false)
		settled+=delta
		if settled>=2:
			kit.enter_vehicle(car);previous_position=car.position
			start_usec=Time.get_ticks_usec();previous_usec=start_usec;profile_start=install_profiles.size();phase=2
			print("DRIVE_PROFILE_START ",mode," ",run_label)
	elif phase==2:
		kit.vehicle_system.tick(delta,true)
		var goal := route[waypoint];goal.y=car.position.y
		if car.position.distance_to(goal)<10: waypoint=(waypoint+1)%route.size()
		var direction := (goal-car.position).normalized()
		var angle: float=(-car.basis.z).signed_angle_to(direction,Vector3.UP)
		car.set_controls(.8,clampf(angle*1.5,-1,1),absf(angle)>1 and car.linear_velocity.length()>6)
		travelled+=car.position.distance_to(previous_position);previous_position=car.position
		simulation_seconds+=delta
		if car.stream_speed_limit<car.top_speed-.1: limited_seconds+=delta
		if car.streaming_suspended: suspended_seconds+=delta
		sample_ticks+=1
		if sample_ticks%12==0:
			trajectory.append({"seconds":simulation_seconds,"position":str(car.position),"speed":car.linear_velocity.length(),"speed_limit":car.stream_speed_limit,"queued":stream_jobs.size(),"resident":chunks.size(),"suspended":car.streaming_suspended})

func _process(delta: float) -> void:
	super._process(delta)
	if phase==0 and coarse_ready and ready_frames>3 and is_instance_valid(arena_content) and arena_content.get("kit") and arena_content.kit.initialized and ring_background.previews_loaded==ring_background.preview_total:
		kit=arena_content.kit;car=kit.vehicle
		kit.reset_all();kit.test_capture=true
		for actor in kit.actors: actor.process_mode=Node.PROCESS_MODE_DISABLED
		phase=1
	if phase==2:
		var now := Time.get_ticks_usec()
		frame_ms.append((now-previous_usec)/1000.0);previous_usec=now
		if (now-start_usec)/1000000.0>=duration:
			phase=3;car.set_controls(0,0,true);finish_profile.call_deferred()

func finish_profile() -> void:
	var ordered := frame_ms.duplicate();ordered.sort()
	var total := 0.0
	for ms in frame_ms: total+=ms
	var stalls := 0
	for ms in frame_ms:
		if ms>50: stalls+=1
	var report := {"mode":mode,"label":run_label,"cache_namespace":run_cache,"fps":frame_ms.size()*1000.0/total,"median_ms":ordered[int(ordered.size()/2)],"p95_ms":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"max_ms":ordered[-1],"frames_over_50ms":stalls,"wall_seconds":total/1000.0,"simulation_seconds":simulation_seconds,"distance_m":travelled,"stream_limited_seconds":limited_seconds,"suspended_seconds":suspended_seconds,"route":str(route),"resolution":str(get_viewport().get_visible_rect().size),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"shadows":sun.shadow_enabled,"top_speed":car.top_speed,"engine_force":car.engine_force,"trajectory":trajectory,"installations":install_profiles.slice(profile_start),"startup_installations":install_profiles.slice(0,profile_start),"frame_ms":frame_ms}
	var file := FileAccess.open("user://streaming-"+mode+"-"+run_label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	var summary := report.duplicate();summary.erase("trajectory");summary.erase("installations");summary.erase("startup_installations");summary.erase("frame_ms")
	print("DRIVE_PROFILE ",JSON.stringify(summary))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://streaming-"+mode+"-"+run_label+".png")
	# Existing jobs are joined on exit, and no new work is dispatched during drain.
	set_process(false)
	for job in stream_jobs:
		if not job.has("result"): job.result=job.thread.wait_to_finish()
	hide()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_tree().quit()
