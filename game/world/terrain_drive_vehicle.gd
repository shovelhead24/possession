extends Node
## Same source preparation, Wishbone controller, saved tuning and cameras as workshop.
var arena: Node3D
var car: RigidBody3D
var vehicles: Array=[]
var menu: CanvasLayer
var driver_look := Vector2.ZERO
var driving := true
var driver_model: Node3D
var test_controls := false
var test_steer := 0.0
var test_throttle := 1.0
var test_brake := false
var initialized := false
var relocating := false
var saved_values := {}
var freeze_ticks := 0
var brake_ticks := 0
var limited_ticks := 0
var seat_position := Vector3(-.52,.92,-.08)

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;process_physics_priority=-50
	var importer := preload("res://world/arena_live_content.gd").new()
	var model: Node3D=importer.import_source(ProjectSettings.globalize_path("res://../assets/halo_warthog.zip").simplify_path())
	if not model: push_error("Warthog source unavailable");get_tree().quit(1);return
	for player in model.find_children("*","AnimationPlayer",true,false): player.stop()
	var bounds: AABB=importer.model_bounds(model)
	if bounds.size.x>bounds.size.z: model.rotate_y(-PI/2)
	model.rotate_y(PI);bounds=importer.model_bounds(model)
	model.scale*=4.8/maxf(bounds.size.x,bounds.size.z);bounds=importer.model_bounds(model)
	model.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	car=preload("res://world/wishbone_vehicle.gd").new();car.name="Warthog"
	car.collision_layer=2;car.collision_mask=3;arena.add_child(car)
	car.set_stream_ready(false);car.recovery_floor=-INF
	car.add_child(model);bounds=importer.model_bounds(model)
	var collision := CollisionShape3D.new();var box := BoxShape3D.new()
	box.size=Vector3(bounds.size.x*.82,.76,4.8*.92);collision.shape=box;collision.position.y=.85;car.add_child(collision)
	preload("res://world/warthog_finish.gd").finish(model,Callable(importer,"model_bounds"))
	car.track_extension=.18;car.wheel_mount_raise=.14;car.center_of_mass.y=.48
	car.setup(model,Callable(importer,"model_bounds"))
	car.add_child(preload("res://world/vehicle_audio.gd").new())
	car.add_child(preload("res://world/wheel_dirt.gd").new())
	driver_model=importer.import_source(ProjectSettings.globalize_path("res://../prototypes/first-operation/seated_driver.glb").simplify_path())
	if driver_model:
		car.add_child(driver_model);driver_model.rotation.y=PI;driver_model.position=seat_position-Vector3(0,.98,0)
	importer.contact_debug.free();importer.free()
	vehicles.append(car)
	menu=preload("res://world/vehicle_menu.gd").new()
	menu.legacy_config_path=OS.get_user_data_dir().get_base_dir().path_join("Possession — FOB and sky study").path_join("vehicle_tuning.cfg")
	add_child(menu)
	for label in menu.panel.find_children("*","Label",true,false): label.text=label.text.replace("F2 or Esc","F5 or Esc")
	var config := ConfigFile.new()
	var path := "user://vehicle_tuning.cfg"
	if config.load(path)!=OK: config.load(menu.legacy_config_path)
	if config.has_section("vehicle"):
		for key in config.get_section_keys("vehicle"):
			var expected: Variant=config.get_value("vehicle",key)
			var actual: Variant=menu.settings.get(key) if key.begins_with("camera_") else car.get(key)
			assert(actual!=null and is_equal_approx(float(actual),float(expected)),"Warthog tuning mismatch: "+key)
			saved_values[key]=actual
	await get_tree().physics_frame
	await place(Vector2(100,220),0)
	initialized=true
	print("DRIVE_WARTHOG_CONFIG ",JSON.stringify(saved_values))

func place(point: Vector2, yaw: float) -> bool:
	var h: float=arena.source.surface_height(point)
	var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x,h+200,point.y),Vector3(point.x,h-200,point.y),1)
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return false
	# Let the physics server freeze before changing pose; otherwise its next sync
	# can overwrite a teleport requested between physics ticks.
	relocating=true;car.set_stream_ready(false)
	await get_tree().physics_frame
	car.global_transform=Transform3D(Basis(Vector3.UP,yaw),hit.position+Vector3.UP*.3)
	car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO;car.stream_velocity=Vector3.ZERO;car.stream_angular=Vector3.ZERO
	car.stream_control.reset();car.reverse_engaged=false;car.balanced_braking=false
	for corner in car.corners: corner.omega=0.0
	await get_tree().physics_frame
	arena.camera.position=car.position+car.basis.z*menu.settings.camera_distance+Vector3.UP*menu.settings.camera_height
	relocating=false
	return true

func handle_input(event: InputEvent) -> bool:
	if not initialized or not arena.ready_to_play: return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F5:
			menu.set_open(not menu.opened);return true
		if event.keycode==KEY_ESCAPE and menu.opened:
			menu.set_open(false);return true
		if not arena.loading.dismissed: return false
		if event.keycode==KEY_E:
			driving=not driving;driver_look=Vector2.ZERO
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			return true
		if event.keycode==KEY_C and driving: menu.set_camera_mode(1-int(menu.settings.camera_mode));return true
		if event.keycode==KEY_HOME: driver_look=Vector2.ZERO;return true
		if event.keycode==KEY_R:
			place(Vector2(car.position.x,car.position.z),car.rotation.y);return true
	if menu.opened: return true
	if driving and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE;return true
	if driving and event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		driver_look.x=clampf(driver_look.x-event.relative.x*.003,-1.6,1.6)
		driver_look.y=clampf(driver_look.y-event.relative.y*.003,-.7,.5);return true
	return false

func update_camera(delta: float) -> void:
	if not initialized: return
	var cfg: Dictionary=menu.settings
	arena.camera.fov=cfg.camera_fov
	if int(cfg.camera_mode)==1:
		arena.camera.global_transform=car.global_transform*Transform3D(Basis.from_euler(Vector3(driver_look.y,driver_look.x,0)),seat_position+Vector3(0,.68,-.03))
		if driver_model: driver_model.hide()
	else:
		if driver_model: driver_model.show()
		var target := car.position+Vector3.UP*1.4
		var wanted: Vector3=car.position+car.basis.z*cfg.camera_distance+Vector3.UP*cfg.camera_height
		var query := PhysicsRayQueryParameters3D.create(target,wanted,3);query.exclude=[car.get_rid()]
		var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): wanted=hit.position+hit.normal*.25
		var next: Vector3=arena.camera.position.lerp(wanted,1-exp(-cfg.camera_smoothing*delta))
		query.to=next;hit=arena.get_world_3d().direct_space_state.intersect_ray(query)
		arena.camera.position=hit.position+hit.normal*.25 if not hit.is_empty() else next
		arena.camera.look_at(target)

func _physics_process(delta: float) -> void:
	if not initialized or not arena.ready_to_play or relocating: return
	var supply: Node=arena.streamer
	car.set_stream_ready(supply.ready_at(car.position))
	car.stream_speed_limit=INF;car.stream_braking=false;car.stream_brake_amount=0.0;car.stream_drive_scale=1.0
	if driving:
		var direction := car.linear_velocity.normalized() if car.linear_velocity.length()>2 else -car.basis.z
		var available := 640.0
		for distance in range(16,641,16):
			if not supply.ready_at(car.position+direction*distance): available=distance-16.0;break
		car.stream_control.step(car.linear_velocity.length(),sqrt(7.0*maxf(0,available-24)),available,delta)
		car.stream_speed_limit=car.stream_control.limit;car.stream_brake_amount=car.stream_control.brake
		car.stream_drive_scale=car.stream_control.drive;car.stream_braking=car.stream_brake_amount>.001
	else: car.stream_control.reset()
	car.controlled=driving and not menu.opened and arena.loading.dismissed and not car.streaming_suspended
	if car.controlled:
		if test_controls: car.set_controls(test_throttle,test_steer,test_brake)
		else: car.driver_controls(Input.is_physical_key_pressed(KEY_W),Input.is_physical_key_pressed(KEY_S),Input.is_physical_key_pressed(KEY_SPACE),float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D)))
	else: car.balanced_braking=false;car.set_controls(0,0,true)
	freeze_ticks+=int(car.streaming_suspended);brake_ticks+=int(car.stream_braking);limited_ticks+=int(car.stream_drive_scale<.999)
