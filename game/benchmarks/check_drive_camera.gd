extends SceneTree

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): push_error("Camera check timed out");quit(1))
	run.call_deferred()

func vec(a: Array) -> Vector3:
	return Vector3(a[0],a[1],a[2])

func run() -> void:
	var scene=load("res://world/terrain_drive.tscn").instantiate()
	root.add_child(scene)
	while not scene.ready_to_play: await process_frame
	while not scene.loading.ready_to_enter: await process_frame
	scene.loading.close()
	assert(scene.loading.dismissed)
	assert(physics_interpolation)
	assert(scene.camera.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF)
	assert(await scene.vehicle_kit.place(Vector2(1300,350),-PI/2))
	scene.vehicle_kit.menu.settings.camera_mode=0 # In-memory only; never save test settings.
	scene.vehicle_kit.test_controls=true
	await create_timer(16).timeout
	print("CAMERA_CHECK_SPEED ",scene.vehicle_kit.car.linear_velocity.length()," position=",scene.vehicle_kit.car.position)
	assert(scene.vehicle_kit.car.linear_velocity.length()>20)
	scene.jitter_trace.toggle()
	await create_timer(6).timeout
	scene.jitter_trace.toggle()
	while scene.jitter_trace.writer: await process_frame
	var file := FileAccess.open(scene.jitter_trace.path,FileAccess.READ)
	var frames: Array=[]
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty(): continue
		var row: Variant=JSON.parse_string(line)
		if row is Dictionary and row.event=="frame_samples": frames.append_array(row.samples)
	var raw_still := 0;var rendered_still := 0;var raw_relative: Array=[];var smooth_relative: Array=[];var times: Array=[]
	for i in range(1,frames.size()):
		var a: Dictionary=frames[i-1];var b: Dictionary=frames[i]
		var raw := vec(b.car_position)-vec(a.car_position)
		var rendered := vec(b.car_render_position)-vec(a.car_render_position)
		var camera_step := vec(b.camera_position)-vec(a.camera_position)
		raw_still+=int(raw.length()<.00001);rendered_still+=int(rendered.length()<.00001)
		raw_relative.append((raw-camera_step).length())
		smooth_relative.append((rendered-camera_step).length());times.append(b.frame_ms)
	raw_relative.sort();smooth_relative.sort();times.sort()
	var count := frames.size()-1
	assert(count>800 and raw_still>count*.35 and rendered_still<count*.02)
	assert(smooth_relative[int(count*.95)]<raw_relative[int(count*.95)]*.3,"Relative camera jitter remains")
	assert(times[int(count*.99)]<16.667)
	# The driver camera must be rigidly attached to the same interpolated pose.
	scene.vehicle_kit.menu.settings.camera_mode=1
	var max_seat_error := 0.0
	for i in 180:
		await process_frame
		scene.vehicle_kit.update_camera(1.0/120)
		var expected: Transform3D=scene.vehicle_kit.car.get_global_transform_interpolated()*Transform3D(Basis.IDENTITY,scene.vehicle_kit.seat_position+Vector3(0,.68,-.03))
		max_seat_error=maxf(max_seat_error,expected.origin.distance_to(scene.camera.global_position))
	assert(max_seat_error<.0001)
	var current: Vector3=scene.vehicle_kit.car.global_position
	assert(await scene.vehicle_kit.place(Vector2(current.x-50,current.z),0))
	assert(scene.vehicle_kit.car.get_global_transform_interpolated().origin.distance_to(scene.vehicle_kit.car.global_position)<.001,"Recovery interpolates from old location")
	print("DRIVE_CAMERA_PASS ",JSON.stringify({"frames":count,"raw_still_frames":raw_still,"rendered_still_frames":rendered_still,"raw_relative_step_p95_m":raw_relative[int(count*.95)],"rendered_relative_step_p95_m":smooth_relative[int(count*.95)],"frame_p99_ms":times[int(count*.99)],"frame_max_ms":times[-1],"driver_camera_error_m":max_seat_error}))
	quit()
