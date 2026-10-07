extends Node
## Tactical vehicle kit adapter: preserve physics, tuning, cameras and seats.
var arena: Node3D
var gameplay: Node
var content: Node
var vehicles: Array[Node3D]=[]
var homes: Array[Transform3D]=[]
var driving: RigidBody3D
var gunning := false
var driver_look := Vector2.ZERO
var warthog_turret: Node
var warthog_menu: CanvasLayer
var tank_menu: CanvasLayer
var menu: CanvasLayer
var driver_model: Node3D
var seat_position := Vector3(-.52,.92,-.08)
var status: Label
var initialized := false
var test_starvation := false
var test_steer := 0.0

func bounds(model: Node3D) -> AABB:
	return content.model_bounds(model)

func imported(path: String) -> Node3D:
	return content.import_source(ProjectSettings.globalize_path(path).simplify_path())

func material(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new();mat.albedo_color=tint
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;return mat

func tracer(start: Vector3, end: Vector3) -> void:
	var mesh := ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(start);mesh.surface_add_vertex(end);mesh.surface_end()
	var draw := MeshInstance3D.new();draw.mesh=mesh;draw.material_override=material(Color(1,.75,.2))
	arena.add_child(draw);get_tree().create_timer(.08).timeout.connect(draw.queue_free)

func register_vehicle(body: RigidBody3D) -> void:
	vehicles.append(body);homes.append(body.transform)
	body.add_collision_exception_with(arena.player);arena.player.add_collision_exception_with(body)
	if not body.suspension_exclusions.has(arena.player.get_rid()): body.suspension_exclusions.append(arena.player.get_rid())

func initialize() -> void:
	status=gameplay.health_hud
	for index in vehicles.size():
		var setup_menu := preload("res://world/vehicle_menu.gd").new()
		setup_menu.vehicle_index=index
		var filename := "vehicle_tuning.cfg" if index==0 else "tank_wheel_tuning.cfg"
		setup_menu.legacy_config_path=OS.get_user_data_dir().get_base_dir().path_join("Possession — FOB and sky study").path_join(filename)
		add_child(setup_menu)
		if index==0: warthog_menu=setup_menu
		else: tank_menu=setup_menu
	menu=warthog_menu
	driver_model=imported("res://../prototypes/first-operation/seated_driver.glb")
	if driver_model:
		vehicles[0].add_child(driver_model);driver_model.rotation.y=PI
		driver_model.position=seat_position-Vector3(0,.98,0);driver_model.hide()
	initialized=true

func enter(body: RigidBody3D, turret_seat := false) -> void:
	release();driving=body;gunning=turret_seat and body==vehicles[0]
	menu=tank_menu if body==vehicles[1] else warthog_menu;driver_look=Vector2.ZERO
	arena.walking=false
	# Do not park a collidable walker beneath a vehicle or in its wheel rays.
	arena.player.collision_layer=0;arena.player.collision_mask=0
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func release() -> void:
	if menu and menu.opened: menu.set_open(false)
	driving=null;gunning=false
	if driver_model: driver_model.hide()
	arena.player.collision_layer=1;arena.player.collision_mask=3;arena.camera.fov=75
	# Collision exceptions remain for the invisible observer proxy, and are
	# removed only when actually walking outside a vehicle (see tick()).

func exit_on_foot() -> bool:
	if not driving: return false
	var body := driving
	var space := arena.get_world_3d().direct_space_state
	for side in [-1.0,1.0]:
		var p: Vector3 = body.position+body.basis.x*side*4
		var ground := PhysicsRayQueryParameters3D.create(p+Vector3.UP*8,p-Vector3.UP*14,3)
		ground.exclude=[body.get_rid(),arena.player.get_rid()]
		var hit := space.intersect_ray(ground)
		if hit.is_empty() or not arena.neighborhood_ready(hit.position): continue
		p=hit.position+Vector3.UP*.1
		var query := PhysicsShapeQueryParameters3D.new();var capsule := CapsuleShape3D.new()
		capsule.radius=.34;capsule.height=1.8;query.shape=capsule;query.transform.origin=p+Vector3.UP*.9
		query.exclude=[arena.player.get_rid()];query.collision_mask=3
		if not space.intersect_shape(query).is_empty(): continue
		release();arena.player.position=p;arena.player.velocity=Vector3.ZERO;arena.walking=true
		arena.camera.position=p+Vector3.UP*1.6;arena.look=Vector2(arena.camera.rotation.y,arena.camera.rotation.x)
		return true
	status.text="Exit obstructed";return false

func handle_input(event: InputEvent) -> bool:
	if not initialized: return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F2:
				if not driving:
					menu=warthog_menu if arena.camera.position.distance_to(vehicles[0].position)<arena.camera.position.distance_to(vehicles[1].position) else tank_menu
				menu.set_open(not menu.opened);return true
			KEY_ESCAPE:
				if menu.opened: menu.set_open(false);return true
			KEY_C:
				if driving: menu.set_camera_mode(1-int(menu.settings.camera_mode));return true
			KEY_HOME:
				if driving: driver_look=Vector2.ZERO;return true
			KEY_G:
				if driving==vehicles[0]: gunning=not gunning;driver_look=Vector2.ZERO;return true
	if menu.opened: return true
	if driving and event is InputEventMouseMotion:
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
			driver_look.x=driver_look.x-event.relative.x*.003 if gunning or driving.has_method("fire_cannon") else clampf(driver_look.x-event.relative.x*.003,-1.6,1.6)
			driver_look.y=clampf(driver_look.y-event.relative.y*.003,-PI/6 if gunning else -.7,PI/6 if gunning else .5)
		return true
	return false

func update_camera(delta: float) -> void:
	if gunning: warthog_turret.update_camera();driver_model.hide();return
	var cfg: Dictionary=menu.settings
	arena.player.position=driving.to_global(seat_position);arena.camera.fov=cfg.camera_fov
	if int(cfg.camera_mode)==1:
		var eye := seat_position+Vector3(0,.68,-.03)
		if driving==vehicles[1]: eye=Vector3(0,2.8,0)
		arena.camera.global_transform=driving.global_transform*Transform3D(Basis.from_euler(Vector3(driver_look.y,driver_look.x,0)),eye)
		if driver_model: driver_model.hide()
	else:
		if driver_model: driver_model.visible=driving==vehicles[0]
		var target := driving.position+Vector3.UP*1.4
		if driving==vehicles[1]: target=driving.to_global(Vector3(0,1.75,1.1))-(driving.basis*Basis.from_euler(Vector3(driver_look.y,driver_look.x,0))).z*80
		var wanted: Vector3=driving.position+(driving.basis*Basis(Vector3.UP,driver_look.x) if driving==vehicles[1] else driving.basis).z*cfg.camera_distance+Vector3.UP*cfg.camera_height
		var query := PhysicsRayQueryParameters3D.create(driving.position+Vector3.UP*1.4,wanted,3)
		query.exclude=[driving.get_rid(),arena.player.get_rid()]
		var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): wanted=hit.position+hit.normal*.25
		var next: Vector3 = arena.camera.position.lerp(wanted,1-exp(-cfg.camera_smoothing*delta))
		query.to=next;hit=arena.get_world_3d().direct_space_state.intersect_ray(query)
		arena.camera.position=hit.position+hit.normal*.25 if not hit.is_empty() else next
		arena.camera.look_at(target)
	arena.look=Vector2(arena.camera.rotation.y,arena.camera.rotation.x)

func tick(delta: float, test_controls := false) -> void:
	if not initialized: return
	for body in vehicles:
		# The prototype has a finite collision domain: contain bodies before their
		# wheel footprint can leave it, rather than letting streaming brake too late.
		var edge: float=arena.movement_limit()-8.0
		for axis in [0,2]:
			if absf(body.position[axis])>edge:
				body.position[axis]=clampf(body.position[axis],-edge,edge)
				if body.linear_velocity[axis]*body.position[axis]>0: body.linear_velocity[axis]=0
				body.stream_velocity[axis]=0
		if arena.walking and not driving:
			body.remove_collision_exception_with(arena.player);arena.player.remove_collision_exception_with(body)
		else:
			body.add_collision_exception_with(arena.player);arena.player.add_collision_exception_with(body)
		body.set_stream_ready(not test_starvation and arena.neighborhood_ready(body.position))
		body.stream_speed_limit=INF;body.stream_braking=false
		body.stream_brake_amount=0.0;body.stream_drive_scale=1.0
		if body==driving or (body==vehicles[0] and gameplay.vehicle_patrol):
			var direction: Vector3=body.linear_velocity.normalized() if body.linear_velocity.length()>2 else -body.basis.z
			var available := 640.0
			for distance in range(16,641,16):
				var probe: Vector3=body.position+direction*distance
				probe.x=clampf(probe.x,-edge,edge);probe.z=clampf(probe.z,-edge,edge)
				if not arena.neighborhood_ready(probe): available=distance-16.0;break
			# This is a collision-supply ceiling, not the vehicle's top-speed cap.
			var safe_limit: float=sqrt(7.0*maxf(0,available-24))
			body.stream_control.step(body.linear_velocity.length(),safe_limit,available,delta)
			body.stream_speed_limit=body.stream_control.limit
			body.stream_brake_amount=body.stream_control.brake
			body.stream_drive_scale=body.stream_control.drive
			body.stream_braking=body.stream_brake_amount>.001
		else: body.stream_control.reset()
		body.controlled=body==driving and not gunning and not menu.opened and not body.streaming_suspended
		if body.controlled:
			if test_controls: body.set_controls(.8,test_steer,false)
			else: body.driver_controls(Input.is_physical_key_pressed(KEY_W),Input.is_physical_key_pressed(KEY_S),Input.is_physical_key_pressed(KEY_SPACE),float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D)))
		else: body.balanced_braking=false;body.set_controls(0,0,true)
	if driving:
		update_camera(delta)
		if driving==vehicles[1] and not menu.opened and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): driving.fire_cannon()

func reset_all() -> void:
	release()
	for index in vehicles.size():
		var body=vehicles[index];body.transform=homes[index];body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO
		body.stream_velocity=Vector3.ZERO;body.stream_angular=Vector3.ZERO
		body.reverse_engaged=false;body.balanced_braking=false
		for corner in body.corners: corner.omega=0.0
