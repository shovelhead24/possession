extends CharacterBody3D
## Adapted from sdf_demo's walking capsule and arena_vehicles.exit_on_foot.
const Ring = preload("res://world/terrain_drive_ring.gd")
const EYE := 1.6
var arena: Node3D
var active := false
var aim_device := -1
var yaw := 0.0
var pitch := 0.0
var shape: CollisionShape3D
var notice := ""
var jump_queued := false
var test_controls := false
var test_move := Vector2.ZERO
var last_safe := Vector3.ZERO
func origin_shifted(delta: Vector3):last_safe-=delta
var toss_velocity := Vector3.ZERO
var toss_time := 0.0

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;name="OnFoot";process_priority=50
	floor_snap_length=.3;floor_max_angle=deg_to_rad(48)
	collision_layer=0;collision_mask=3
	shape=CollisionShape3D.new();var capsule := CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.8
	shape.shape=capsule;shape.position.y=.9;shape.disabled=true;add_child(shape)

func find_ground(estimate: Vector3, rise := 8.0, fall := 14.0) -> Dictionary:
	if not arena.streamer.ready_at(estimate): return {}
	var up := Ring.up_at(estimate)
	var ray := PhysicsRayQueryParameters3D.create(estimate+up*rise,estimate-up*fall,1)
	ray.exclude=[get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.dot(up)<cos(floor_max_angle): return {}
	var feet: Vector3=hit.position+up*.06
	var query := PhysicsShapeQueryParameters3D.new();query.shape=shape.shape
	query.transform=Transform3D(Ring.tangent_basis(feet,0),feet+up*.9);query.collision_mask=3;query.exclude=[get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return {}
	return {"feet":feet}

func activate_at(feet: Vector3) -> void:
	var forward: Vector3=-arena.camera.global_basis.z
	var up := Ring.up_at(feet)
	yaw=Ring.tangent_yaw(feet,forward.slide(up).normalized());pitch=asin(clampf(forward.dot(up),-.99,.99))
	position=feet;last_safe=feet;velocity=Vector3.ZERO;active=true;jump_queued=false
	global_basis=Ring.tangent_basis(feet,yaw);up_direction=up
	collision_layer=2;shape.disabled=false;reset_physics_interpolation()
	arena.vehicle_kit.driving=false;arena.vehicle_kit.car.controlled=false;arena.vehicle_kit.car.set_controls(0,0,true)
	if arena.vehicle_kit.driver_model: arena.vehicle_kit.driver_model.hide()
	arena.camera.fov=75;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;update_camera();notice=""

func deactivate() -> void:
	active=false;velocity=Vector3.ZERO;jump_queued=false;collision_layer=0;shape.disabled=true

func exit_vehicle() -> bool:
	var car: RigidBody3D=arena.vehicle_kit.car
	if car.linear_velocity.length()>3:
		notice="Slow down before exiting.";return false
	for offset in [Vector3(-3.2,0,0),Vector3(3.2,0,0),Vector3(-4.5,0,0),Vector3(4.5,0,0),Vector3(0,0,4.5),Vector3(0,0,-4.5)]:
		var landing := find_ground(car.global_transform*offset)
		if not landing.is_empty(): activate_at(landing.feet);return true
	notice="Exit obstructed: move to clear ground.";return false

func enter_vehicle() -> bool:
	var car: RigidBody3D=arena.vehicle_kit.car
	for candidate in arena.vehicle_kit.vehicles:
		if is_instance_valid(candidate) and not candidate.has_meta("trex_held") and candidate.global_position.distance_squared_to(global_position)<car.global_position.distance_squared_to(global_position): car=candidate
	if global_position.distance_to(car.global_position)>6:
		notice="Move within 6 m of a vehicle to enter.";return false
	if car.linear_velocity.length()>3: notice="Wait for the vehicle to slow down.";return false
	var ray := PhysicsRayQueryParameters3D.create(global_position+up_direction*EYE,car.global_position+Ring.up_at(car.global_position)*1.1,3)
	ray.exclude=[get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.collider!=car: notice="Vehicle entry obstructed.";return false
	arena.vehicle_kit.select_vehicle(car)
	deactivate();arena.vehicle_kit.driving=true;arena.vehicle_kit.driver_look=Vector2.ZERO
	arena.vehicle_kit.update_camera(1.0);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;notice="";return true

func handle_input(event: InputEvent) -> bool:
	if has_meta("trex_held") or (arena.vehicle_kit.driving and arena.vehicle_kit.car.has_meta("trex_held")): return true
	if not arena.ready_to_play or not arena.loading.dismissed or arena.editor.opened or arena.vehicle_kit.menu.opened: return false
	if active and event is InputEventJoypadMotion and absf(event.axis_value)>.2:
		aim_device=event.device;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;return true
	if active and event is InputEventJoypadButton and event.pressed:
		aim_device=event.device
		if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;return true
		if event.button_index==JOY_BUTTON_A: jump_queued=true;return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D] or event.keycode in [KEY_W,KEY_A,KEY_S,KEY_D]: aim_device=-1
		if event.keycode==KEY_E:
			if arena.vehicle_kit.driving: exit_vehicle()
			elif active: enter_vehicle()
			else:
				var landing := find_ground(arena.camera.global_position,2,200)
				if not landing.is_empty(): activate_at(landing.feet)
				else: notice="No clear loaded ground below the camera."
			return true
		if active:
			if event.keycode==KEY_ESCAPE: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;return true
			if event.keycode==KEY_SPACE: jump_queued=Input.mouse_mode==Input.MOUSE_MODE_CAPTURED;return true
			if event.keycode in [KEY_R,KEY_C,KEY_1,KEY_2,KEY_3,KEY_4]: return true
	if active and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;return true
	if active and event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		aim_device=-1
		if arena.get("weapons"): arena.weapons.aim_assist.reset_tracking()
		yaw-=event.relative.x*.0025;pitch=clampf(pitch-event.relative.y*.0025,-1.5,1.5);return true
	return false

func _physics_process(delta: float) -> void:
	if not active or not arena.ready_to_play: return
	if arena.get("aliens") and arena.aliens.defeated: velocity=Vector3.ZERO;return
	if arena.editor.opened or not arena.loading.dismissed or arena.vehicle_kit.menu.opened:
		velocity=Vector3.ZERO;jump_queued=false;return
	up_direction=Ring.up_at(global_position);global_basis=Ring.tangent_basis(global_position,yaw)
	if not arena.streamer.ready_at(global_position): velocity=Vector3.ZERO;return
	if toss_time>0:
		toss_time-=delta;velocity=toss_velocity.slide(up_direction)+up_direction*(velocity.dot(up_direction)-20*delta)
		toss_velocity=toss_velocity.move_toward(Vector3.ZERO,delta*8);move_and_slide();return
	var axes := test_move if test_controls else Vector2.ZERO
	if not test_controls and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		axes=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if aim_device>=0: axes=stick(JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y)
	var direction := global_basis*Vector3(axes.x,0,axes.y).limit_length()
	if not arena.streamer.ready_at(global_position+direction*2): direction=Vector3.ZERO
	var vertical := velocity.dot(up_direction)-20*delta
	if jump_queued and is_on_floor(): vertical=6
	jump_queued=false;velocity=direction*9.0+up_direction*vertical
	move_and_slide()
	if is_on_floor(): last_safe=global_position

func update_camera() -> void:
	var feet := get_global_transform_interpolated().origin
	var up := Ring.up_at(feet)
	arena.camera.global_transform=Transform3D(Ring.tangent_basis(feet,yaw)*Basis(Vector3.RIGHT,pitch),feet+up*EYE)

func stick(x_axis: int, y_axis: int) -> Vector2:
	if aim_device<0 or not Input.get_connected_joypads().has(aim_device): return Vector2.ZERO
	return deadzone(Vector2(Input.get_joy_axis(aim_device,x_axis),Input.get_joy_axis(aim_device,y_axis)))
static func deadzone(value: Vector2) -> Vector2:
	var amount=value.length()
	return Vector2.ZERO if amount<=.18 else value.normalized()*minf(1,(amount-.18)/.82)
func _process(delta: float) -> void:
	if active and not arena.editor.opened and arena.loading.dismissed and not arena.vehicle_kit.menu.opened:
		if aim_device>=0 and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not has_meta("trex_held") and toss_time<=0:
			var move=stick(JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y);var look=stick(JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y)
			var filtered={"scale":1.0,"rotation":Vector2.ZERO}
			if arena.get("weapons"): filtered=arena.weapons.controller_aim(move,look,delta)
			yaw-=look.x*deg_to_rad(150)*delta*filtered.scale
			pitch-=look.y*deg_to_rad(110)*delta*filtered.scale
			yaw+=filtered.rotation.x;pitch=clampf(pitch+filtered.rotation.y,-1.5,1.5)
		update_camera()
		if arena.vehicle_kit.driver_model: arena.vehicle_kit.driver_model.hide()

func toss_from_trex(impulse: Vector3, _source: PhysicsBody3D) -> void:
	toss_velocity=impulse;toss_time=.8;velocity=impulse
