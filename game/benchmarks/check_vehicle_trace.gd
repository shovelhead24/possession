extends SceneTree

func _initialize() -> void:
	create_timer(180).timeout.connect(func(): push_error("Vehicle trace test timed out");quit(1))
	run.call_deferred()

func run() -> void:
	var recorder=load("res://world/vehicle_trace.gd").new()
	for i in 800: recorder.remember({"sample_usec":i*10000})
	var recent: Array=recorder.recent(7990000)
	assert(recorder.history.size()==600 and recent.size()==501)
	assert(recent[0].sample_usec==2990000 and recent[-1].sample_usec==7990000)
	recorder.free()
	var scene=load("res://world/sdf_authoring.tscn").instantiate()
	root.add_child(scene)
	while not scene.live_kit(): await process_frame
	while not scene.far_terrain.finished() or scene.ready_frames<3: await process_frame
	var kit: Node=scene.live_kit()
	scene.switch_editor_mode(false);kit.test_vehicle_controls=true;kit.enter_vehicle()
	for i in 360: await physics_frame
	scene.mark_operation()
	for i in 120: await physics_frame
	scene.mark_operation()
	var rows: Array=[]
	var file := FileAccess.open(scene.trace_path,FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Variant=JSON.parse_string(line)
		if row is Dictionary and row.get("event")=="vehicle_samples": rows.append(row)
	assert(not rows.is_empty(),"No vehicle telemetry persisted")
	assert(rows[0].phase=="pre_roll" and rows[0].samples.size()>200,"Missing pre-roll")
	var count := 0;var max_ms := 0.0;var last_time := 0
	for row in rows:
		assert(row.marker_id==1)
		for sample in row.samples:
			assert(sample.sample_usec>last_time,"Duplicate or unordered samples")
			last_time=sample.sample_usec;count+=1
			max_ms=maxf(max_ms,sample.sampling_ms)
			assert(sample.vehicles.size()==2)
			assert(sample.vehicles[0].wheels.size()==4)
	assert(count>320 and scene.vehicle_trace.active_id==0)
	assert(scene.vehicle_trace.history.size()<=600)
	print("VEHICLE_TRACE_PASS samples=",count," max_sampling_ms=",max_ms," path=",scene.trace_path)
	quit()
