extends Node
## Same source preparation, Wishbone controller, saved tuning and cameras as workshop.
const Ring = preload("res://world/terrain_drive_ring.gd")
const START_POINT := Vector2(100,220)
var arena: Node3D
var car: RigidBody3D
var vehicles: Array=[]
var actor_template: PackedScene
var original_car: RigidBody3D
var menu: CanvasLayer
var warthog_menu: CanvasLayer
var tank_menu: CanvasLayer
var driver_look := Vector2.ZERO
var camera_input_idle := 0.0
var camera_forward_time := 0.0
var camera_was_moved := false
var look_spring_offset := Vector3.ZERO
var look_spring_velocity := Vector3.ZERO
var camera_close_view := false
var camera_probe := PhysicsShapeQueryParameters3D.new()
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
	# Cache the finished source before setup reparents wheels into the suspension.
	for child in model.find_children("*","",true,false): child.owner=model
	actor_template=PackedScene.new();actor_template.pack(model)
	car.setup(model,Callable(importer,"model_bounds"));original_car=car
	car.add_child(preload("res://world/vehicle_audio.gd").new())
	car.add_child(preload("res://world/wheel_dirt.gd").new())
	driver_model=importer.import_source(ProjectSettings.globalize_path("res://../prototypes/first-operation/seated_driver.glb").simplify_path())
	if driver_model:
		car.add_child(driver_model);driver_model.rotation.y=PI;driver_model.position=seat_position-Vector3(0,.98,0)
	importer.contact_debug.free();importer.free()
	vehicles.append(car)
	menu=preload("res://world/vehicle_menu.gd").new()
	menu.legacy_config_path=OS.get_user_data_dir().get_base_dir().path_join("Possession — FOB and sky study").path_join("vehicle_tuning.cfg")
	add_child(menu);warthog_menu=menu
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
	await place(START_POINT,0)
	initialized=true
	print("DRIVE_WARTHOG_CONFIG ",JSON.stringify(saved_values))

func place(point: Vector2, yaw: float) -> bool:
	var h: float=arena.source.surface_height(point)
	var estimated := Ring.point(point.x,h,point.y)
	var up := Ring.up_at(estimated)
	var ray := PhysicsRayQueryParameters3D.create(estimated+up*200,estimated-up*200,1)
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return false
	# Let the physics server freeze before changing pose; otherwise its next sync
	# can overwrite a teleport requested between physics ticks.
	relocating=true;car.set_stream_ready(false)
	await get_tree().physics_frame
	car.global_transform=Transform3D(Ring.tangent_basis(hit.position,yaw),hit.position+up*.3)
	car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO;car.stream_velocity=Vector3.ZERO;car.stream_angular=Vector3.ZERO
	car.stream_control.reset();car.reverse_engaged=false;car.balanced_braking=false
	for corner in car.corners: corner.omega=0.0
	await get_tree().physics_frame
	car.reset_physics_interpolation()
	arena.camera.position=car.position+car.basis.z*menu.settings.camera_distance+Ring.up_at(car.position)*menu.settings.camera_height
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
			var ring_position := Ring.coordinates(car.position)
			place(Vector2(ring_position.x,ring_position.z),Ring.tangent_yaw(car.position,-car.global_basis.z));return true
	if menu.opened: return true
	if driving and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE;return true
	if driving and event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		driver_look.x=wrapf(driver_look.x-event.relative.x*.003,-PI,PI) if car.has_method("fire_cannon") else clampf(driver_look.x-event.relative.x*.003,-1.6,1.6)
		driver_look.y=clampf(driver_look.y-event.relative.y*.003,-.7,.5)
		register_camera_input();return true
	return false

func register_camera_input() -> void:
	camera_was_moved=true;camera_input_idle=0.0

func camera_clear_position(pivot: Vector3, wanted: Vector3) -> Vector3:
	if not camera_probe.shape:
		var sphere := SphereShape3D.new();sphere.radius=.28;camera_probe.shape=sphere
	camera_probe.collision_mask=7;camera_probe.exclude=[car.get_rid()]
	camera_probe.transform=Transform3D(Basis.IDENTITY,pivot)
	camera_probe.motion=wanted-pivot
	var safe := arena.get_world_3d().direct_space_state.cast_motion(camera_probe)
	return pivot+camera_probe.motion*maxf(0.0,safe[0]-.04/maxf(.04,camera_probe.motion.length()))

func recenter_camera(delta: float, forward_speed: float) -> void:
	if camera_input_idle<2.0 or camera_forward_time<2.0 or forward_speed<1.0 or menu.opened: return
	driver_look=driver_look.lerp(Vector2.ZERO,1.0-exp(-2.8*delta))
	if driver_look.length_squared()<.000001: driver_look=Vector2.ZERO

func update_look_spring(target_offset: Vector3, delta: float) -> void:
	# Critically damped spring keeps the look target smooth and frame-rate independent.
	var frequency := 3.5
	var displacement := look_spring_offset-target_offset
	var coupled_velocity := look_spring_velocity+displacement*frequency
	var decay := exp(-frequency*delta)
	look_spring_offset=target_offset+(displacement+coupled_velocity*delta)*decay
	look_spring_velocity=(look_spring_velocity-coupled_velocity*frequency*delta)*decay

func update_camera(delta: float) -> void:
	if not initialized: return
	# Match the renderer's vehicle pose rather than the latest discrete physics pose.
	var pose := car.get_global_transform_interpolated()
	var cfg: Dictionary=menu.settings
	arena.camera.fov=cfg.camera_fov
	if int(cfg.camera_mode)==1:
		camera_close_view=false;camera_forward_time=0.0
		arena.camera.global_transform=pose*Transform3D(Basis.from_euler(Vector3(driver_look.y,driver_look.x,0)),seat_position+Vector3(0,.68,-.03))
		if driver_model: driver_model.hide()
	else:
		var up := Ring.up_at(pose.origin)
		camera_input_idle+=delta
		var travel := car.linear_velocity.slide(up)
		camera_forward_time=camera_forward_time+delta if travel.dot(-pose.basis.z)>1.0 and not menu.opened else 0.0
		recenter_camera(delta,travel.dot(-pose.basis.z))
		var look_ahead_ready := camera_was_moved and camera_input_idle>=2.0 and travel.length()>2.5
		var spring_target := travel.normalized()*clampf(travel.length()*.45,0.0,4.5) if look_ahead_ready else Vector3.ZERO
		update_look_spring(spring_target,delta)
		var target := pose.origin+up*1.4
		target+=look_spring_offset
		var orbit: Vector3=pose.basis.z*cfg.camera_distance+up*cfg.camera_height
		orbit=Basis(up,driver_look.x)*Basis(pose.basis.x,driver_look.y)*orbit
		var wanted: Vector3=pose.origin+orbit
		# Sweep a small camera volume from the car, independently of look-ahead.
		# A ray from the shifted aim point could start on the far side of a wall.
		var pivot := pose.origin+up*1.4
		wanted=camera_clear_position(pivot,wanted)
		var clearance := wanted.distance_to(pivot)
		camera_close_view=clearance<2.0 if not camera_close_view else clearance<3.0
		if driver_model: driver_model.visible=not camera_close_view and not car.has_method("fire_cannon")
		if camera_close_view:
			# Temporary driver view avoids staring into the chassis when squeezed.
			# Hysteresis prevents rapid switching along a wall or tree trunk.
			var eye: Vector3=pose*(seat_position+Vector3(0,.68,-.03))
			arena.camera.global_transform=pose*Transform3D(Basis.from_euler(Vector3(driver_look.y,driver_look.x,0)),Vector3.ZERO)
			arena.camera.global_position=camera_clear_position(pivot,eye)
			return
		var next: Vector3=arena.camera.position.lerp(wanted,1-exp(-cfg.camera_smoothing*delta))
		arena.camera.position=camera_clear_position(pivot,next)
		arena.camera.look_at(target,up)

func _physics_process(delta: float) -> void:
	if not initialized or not arena.ready_to_play or relocating: return
	if not driving: camera_forward_time=0.0
	for other in vehicles:
		if other!=car and not other.has_meta("actor_id") and not other.has_meta("trex_held"):
			other.gravity_up=Ring.up_at(other.position)
			other.set_stream_ready(arena.streamer.ready_at(other.position) and not arena.editor.opened and not menu.opened)
			other.controlled=false;other.set_controls(0,0,true)
	car.gravity_up=Ring.up_at(car.position)
	var supply: Node=arena.streamer
	car.set_stream_ready(supply.ready_at(car.position) and not arena.editor.opened and not menu.opened)
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
		elif arena.get("controller") and arena.controller.using_controller: arena.controller.drive(car)
		else: car.driver_controls(Input.is_physical_key_pressed(KEY_W),Input.is_physical_key_pressed(KEY_S),Input.is_physical_key_pressed(KEY_SPACE),float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D)))
	else: car.balanced_braking=false;car.set_controls(0,0,true)
	freeze_ticks+=int(car.streaming_suspended);brake_ticks+=int(car.stream_braking);limited_ticks+=int(car.stream_drive_scale<.999)

func create_authored_vehicle(pose: Transform3D) -> RigidBody3D:
	var vehicle=preload("res://world/wishbone_vehicle.gd").new()
	vehicle.collision_layer=2;vehicle.collision_mask=3;arena.add_child(vehicle)
	vehicle.set_stream_ready(false);vehicle.recovery_floor=-INF;vehicle.suspension_mask=7
	var model=actor_template.instantiate();vehicle.add_child(model)
	var importer=preload("res://world/arena_live_content.gd").new()
	var bounds=importer.model_bounds(model)
	var collision=CollisionShape3D.new();var box=BoxShape3D.new()
	box.size=Vector3(bounds.size.x*.82,.76,4.8*.92);collision.shape=box;collision.position.y=.85;vehicle.add_child(collision)
	vehicle.track_extension=.18;vehicle.wheel_mount_raise=.14;vehicle.center_of_mass.y=.48
	vehicle.setup(model,Callable(importer,"model_bounds"))
	for key in saved_values:
		if not key.begins_with("camera_"): vehicle.set(key,saved_values[key])
	importer.contact_debug.free();importer.free()
	vehicle.add_child(preload("res://world/vehicle_audio.gd").new())
	vehicle.add_child(preload("res://world/wheel_dirt.gd").new())
	vehicle.global_transform=pose;vehicle.reset_physics_interpolation();vehicles.append(vehicle)
	return vehicle
func select_vehicle(vehicle: RigidBody3D) -> void:
	if car==vehicle: return
	car.controlled=false;car.set_controls(0,0,true)
	if vehicle.has_method("fire_cannon"): ensure_tank_menu(vehicle)
	menu.set_open(false)
	car=vehicle;menu=tank_menu if vehicle.has_method("fire_cannon") else warthog_menu;menu.car=vehicle
	seat_position=Vector3(0,2.4,.8) if vehicle.has_method("fire_cannon") else Vector3(-.52,.92,-.08)
	look_spring_offset=Vector3.ZERO;look_spring_velocity=Vector3.ZERO
	menu.loading=true
	for key in menu.controls:
		if not key.begins_with("camera_"): menu.controls[key].value=car.get(key)
	menu.loading=false
	if driver_model:
		driver_model.reparent(car,false);driver_model.position=seat_position-Vector3(0,.98,0)
		driver_model.visible=not car.has_method("fire_cannon")

func ensure_tank_menu(tank: RigidBody3D) -> void:
	if tank_menu: return
	tank_menu=preload("res://world/vehicle_menu.gd").new();tank_menu.vehicle_index=vehicles.find(tank)
	tank_menu.settings.camera_distance=12.0;tank_menu.settings.camera_height=5.0;add_child(tank_menu)
	for label in tank_menu.panel.find_children("*","Label",true,false): label.text=label.text.replace("F2 or Esc","F5 or Esc")
	arena.devices.add_menu(tank_menu)

func restore_tank() -> void:
	preload("res://world/rebuild_tank_factory.gd").prepare()
	for offset in [Vector3(12,0,0),Vector3(-12,0,0),Vector3(0,0,14),Vector3(18,0,12)]:
		var hit=arena.aliens.ground(original_car.global_position+original_car.global_basis*offset)
		if hit.is_empty(): continue
		var pose=Transform3D(Ring.tangent_basis(hit.position,0),hit.position+Ring.up_at(hit.position)*.3)
		var probe=PhysicsShapeQueryParameters3D.new();var box=BoxShape3D.new();box.size=Vector3(3.2,2.4,6.2);probe.shape=box
		probe.transform=pose*Transform3D(Basis.IDENTITY,Vector3(0,1.3,.5));probe.collision_mask=6
		if not arena.get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty(): continue
		var tank=preload("res://world/rebuild_tank_factory.gd").create(self,pose)
		ensure_tank_menu(tank);return
	push_warning("No clear tank pad near the start. Place an Altay through F1 > Actors.")
