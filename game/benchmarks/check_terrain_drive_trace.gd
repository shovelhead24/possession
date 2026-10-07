extends SceneTree

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): push_error("Drive trace test timed out");quit(1))
	run.call_deferred()

func press_f8(scene: Node) -> void:
	var event := InputEventKey.new();event.keycode=KEY_F8;event.pressed=true
	scene._input(event)

func run() -> void:
	var scene=load("res://world/terrain_drive.tscn").instantiate()
	root.add_child(scene)
	while not scene.ready_to_play: await process_frame
	while not scene.loading.ready_to_enter: await process_frame
	scene.loading.close()
	scene.vehicle_kit.test_controls=true
	scene.vehicle_kit.test_throttle=0
	scene.vehicle_kit.test_brake=true
	await create_timer(6).timeout
	press_f8(scene)
	assert(scene.jitter_trace.active_id==1)
	scene.vehicle_kit.test_throttle=1
	scene.vehicle_kit.test_brake=false
	await create_timer(5).timeout
	press_f8(scene)
	assert(scene.jitter_trace.active_id==0)
	while scene.jitter_trace.writer: await process_frame
	var file := FileAccess.open(scene.jitter_trace.path,FileAccess.READ)
	var physics_count := 0;var frames := 0;var pre_roll := 0;var last_time := 0
	var max_sampling_ms := 0.0;var max_frame_ms := 0.0;var force_samples := 0
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Variant=JSON.parse_string(line)
		assert(row is Dictionary)
		if row.event=="vehicle_samples":
			if row.phase=="pre_roll": pre_roll+=row.samples.size()
			for sample in row.samples:
				assert(sample.sample_usec>last_time);last_time=sample.sample_usec
				assert(sample.has("generated") and sample.has("phase_at_usec"))
				assert(sample.vehicles.size()==1 and sample.vehicles[0].wheels.size()==4)
				for wheel in sample.vehicles[0].wheels:
					assert(wheel.has("load") and wheel.has("ray_from") and wheel.has("same_point_probe"))
					if wheel.load>0: force_samples+=1
				max_sampling_ms=maxf(max_sampling_ms,sample.sampling_ms);physics_count+=1
		if row.event=="frame_samples":
			for sample in row.samples:
				assert(sample.has("camera_position") and sample.has("physics_frame"))
				max_frame_ms=maxf(max_frame_ms,sample.frame_ms);frames+=1
	assert(pre_roll>=250 and physics_count>=500 and frames>=500 and force_samples>0)
	assert(scene.jitter_trace.history.size()<=600 and scene.jitter_trace.frame_history.size()<=600)
	press_f8(scene);assert(scene.jitter_trace.active_id==2)
	await create_timer(.1).timeout
	press_f8(scene);assert(scene.jitter_trace.active_id==0)
	while scene.jitter_trace.writer: await process_frame
	print("DRIVE_TRACE_PASS physics=",physics_count," frames=",frames," pre_roll=",pre_roll," max_sampling_ms=",max_sampling_ms," max_frame_ms=",max_frame_ms)
	quit()
