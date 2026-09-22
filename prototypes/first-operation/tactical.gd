extends "res://study.gd"

var walker: CharacterBody3D
var trex_toss_velocity := Vector3.ZERO
var trex_toss_time := 0.0
var flying := false
var jump_held := false
var kit: Node
const EYE := 1.65
const RELAY_SHIFT := Vector3(0,0,-268)

func height_at(x: float, z: float) -> float:
	# Authored landform envelope: quiet ground at both sites, ridge west, gully east.
	var envelope := smoothstep(15.0,65.0,-z)*(1.0-smoothstep(235.0,280.0,-z))
	var ridge := 11.0*exp(-pow((x+32.0)/19.0,2.0))
	var gully := -3.8*exp(-pow((x-25.0)/12.0,2.0))
	var shoulders := 9.0*smoothstep(55.0,115.0,absf(x))
	var folds := 1.4*sin(z*0.065)*exp(-pow(x/70.0,2.0))
	var course=(1.0-smoothstep(8.0,14.0,absf(x+65.0)))*smoothstep(-170.0,-150.0,z)*(1.0-smoothstep(12.0,25.0,z))
	var outer=smoothstep(115.0,180.0,absf(x))+smoothstep(330.0,400.0,-z)
	var rolling=(6.0+4.0*sin(x*.027)*cos(z*.021)+2.5*sin(z*.05+x*.016))*minf(outer,1.0)
	return envelope*(ridge+gully+shoulders+folds)*(1.0-course)+rolling

func build_landscape() -> void:
	super.build_landscape()
	# Replace the flat foreground; keep the distant ring as the study's scale proxy.
	for child in get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.x==9000:
			child.position.y=-12.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(230):
		for ix in range(180):
			var x := -270.0+ix*3.0
			var z := -580.0+iz*3.0
			for p in [Vector2(x,z),Vector2(x+3,z),Vector2(x+3,z+3),Vector2(x,z),Vector2(x+3,z+3),Vector2(x,z+3)]:
				st.add_vertex(Vector3(p.x,height_at(p.x,p.y),p.y))
	st.index();st.generate_normals()
	var terrain := mesh_node(st.commit(),Vector3.ZERO,local_ground(Color(0.30,0.37,0.25)))
	terrain.name="TacticalGround"
	terrain.create_trimesh_collision()

func solid(pos: Vector3, size: Vector3, mat: Material) -> void:
	var n := box(pos,size,mat)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size=size
	shape.shape=cube
	n.add_child(body);body.add_child(shape)

func build_fob() -> void:
	var before := get_children()
	super.build_fob()
	for child in get_children():
		if child not in before and child is Node3D:
			if child.position.z < -20: child.position+=RELAY_SHIFT
		if child not in before and child is MeshInstance3D and child.mesh is BoxMesh:
			child.create_trimesh_collision()
	var stone := material(Color(0.34,0.35,0.30))
	var metal := material(Color(0.16,0.20,0.22),0.4)
	# Compound has an 8 m front gate, an east-side infantry entrance and an open interior.
	for x in [-20.0,20.0]:
		solid(Vector3(x,1.4,-281),Vector3(32,2.8,0.7),stone)
	solid(Vector3(-36,1.4,-307),Vector3(0.7,2.8,52),stone)
	solid(Vector3(0,1.4,-333),Vector3(72,2.8,0.7),stone)
	for z in [-291.0,-320.0]: solid(Vector3(36,1.4,z),Vector3(0.7,2.8,20),stone)
	building(Vector3(-19,0,-309),stone,metal)
	building(Vector3(18,0,-315),stone,metal)
	# Low walls create intermittent cover without closing the main route.
	for z in [-68.0,-118.0,-181.0,-238.0]:
		var x := 5.0 if z > -150 else -3.0
		solid(Vector3(x,height_at(x,z)+0.6,z),Vector3(8,1.2,0.65),stone)
	# A marked dirt track follows the sheltered gully; all vertices sample the same ground.
	for i in range(125):
		var z := -25.0-i*2.0
		var x := 25.0*sin(clampf((-z-25.0)/45.0,0.0,1.0)*PI*0.5)
		if z < -230: x*=clampf((z+280.0)/50.0,0.0,1.0)
		var ribbon := SurfaceTool.new();ribbon.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in [Vector2(x-3,z),Vector2(x+3,z),Vector2(x+3,z+2),Vector2(x-3,z),Vector2(x+3,z+2),Vector2(x-3,z+2)]:
			ribbon.add_vertex(Vector3(p.x,height_at(p.x,p.y)+0.035,p.y))
		ribbon.generate_normals()
		mesh_node(ribbon.commit(),Vector3.ZERO,local_ground(Color(0.38,0.33,0.25)))
	label3("RELAY COMPOUND",Vector3(0,5,-281),70)

func building(origin: Vector3, wall: Material, roof: Material) -> void:
	solid(origin+Vector3(0,-0.1,0),Vector3(12,0.2,14),wall)
	solid(origin+Vector3(0,3.3,0),Vector3(12.6,0.3,14.6),roof)
	solid(origin+Vector3(0,1.6,-7),Vector3(12,3.2,0.4),wall)
	# Front door gap is 2 m wide; side windows have low sills and real openings.
	for x in [-3.5,3.5]: solid(origin+Vector3(x,1.6,7),Vector3(5,3.2,0.4),wall)
	solid(origin+Vector3(0,2.85,7),Vector3(2,0.7,0.4),wall)
	for x in [-6.0,6.0]:
		solid(origin+Vector3(x,0.5,0),Vector3(0.4,1,14),wall)
		solid(origin+Vector3(x,2.8,0),Vector3(0.4,0.8,14),wall)
		for z in [-5.5,0.0,5.5]: solid(origin+Vector3(x,1.7,z),Vector3(0.4,1.4,3),wall)

func _ready() -> void:
	super._ready()
	if not shots_running: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	walker=CharacterBody3D.new()
	walker.name="Player"
	walker.floor_snap_length=0.4
	walker.floor_max_angle=deg_to_rad(48)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.32;capsule.height=1.8
	shape.shape=capsule;shape.position.y=0.9
	walker.add_child(shape);add_child(walker)
	viewpoint(1)
	support_status.text="E / CALL STRIKE ON RANGE"
	relay_status.text="E / CONNECT RELAY"
	help.text="WASD walk · Mouse look · Tab controls"
	help.hide()
	add_child(preload("res://suspension_course.gd").new())
	if not OS.get_cmdline_user_args().has("--no-kit"): install_kit()

func install_kit() -> void:
	kit=preload("res://arena_kit.gd").new();add_child(kit)
	var trees=preload("res://arena_trees.gd").new();trees.name="ArenaTrees";add_child(trees)
	add_child(preload("res://practice_range.gd").new())

func viewpoint(index: int) -> void:
	var points := [Vector3(3.5,0.2,4.5),Vector3(-32,0,-140),Vector3(25,0,-140),Vector3(0,0,-274)]
	var pos: Vector3=points[index-1]
	pos.y=maxf(pos.y,height_at(pos.x,pos.z))+0.15
	if is_instance_valid(walker): walker.position=pos;walker.velocity=Vector3.ZERO
	camera.position=pos+Vector3.UP*EYE
	camera.look_at(Vector3(0,2,-300) if index>1 else Vector3(0,1.2,0))

func use_station() -> void:
	if kit and not kit.driving and walker.position.distance_to(Vector3(10,0,-10))<3:
		get_node("PracticeRange").reset();kit.status.text="SQUADS RESET / G frag / F3 plasma speed";return
	if kit:
		if kit.driving:
			kit.toggle_vehicle();return
		for vehicle in kit.vehicles:
			if walker.position.distance_to(vehicle.position)<6:
				kit.toggle_vehicle();return
	if camera.position.distance_to(Vector3(0,2,-296.5))<5:
		state.relay=State.Relay.OPERATIONAL
		state.report="RELAY CONNECTED"
		refresh();relay_status.text="RELAY CONNECTED"
	elif camera.position.distance_to(Vector3(4,2,-6))<5:
		if strike_busy: return
		if state.request_support(): strike()
		support_status.text=state.report

func _input(event: InputEvent) -> void:
	if kit and kit.handle_vehicle_input(event): return
	if kit and kit.driving and event is InputEventKey and event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_V]: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_V:
		flying=not flying
		if not flying and is_instance_valid(walker):
			walker.position=camera.position-Vector3.UP*EYE;walker.velocity=Vector3.ZERO
	super._input(event)

func strike() -> void:
	if strike_busy: return
	strike_busy=true
	state.report="STRIKE INBOUND / MARKED RANGE"
	await get_tree().create_timer(1.0).timeout
	for x in [12.0,16.0,20.0]:
		var point=Vector3(x,1,-18-(x-12)*1.5)
		var ball=SphereMesh.new();ball.radius=1.0;ball.height=2.0
		var flash=mesh_node(ball,point,material(Color(1,.45,.08),0,.7,true))
		var tween=create_tween();tween.tween_property(flash,"scale",Vector3.ONE*4,.25);tween.tween_property(flash,"scale",Vector3.ONE*.01,.35);tween.tween_callback(flash.queue_free)
		for target in get_children():
			if target is Node3D and target.has_meta("target_hits") and target.position.distance_to(point)<5:
				target.set_meta("target_hits",int(target.get_meta("target_hits"))+1)
		await get_tree().create_timer(.25).timeout
	state.report="STRIKE COMPLETE / RANGE HIT";support_status.text=state.report
	strike_busy=false

var strike_busy := false

func refresh() -> void:
	super.refresh()
	relay_status.text="RELAY CONNECTED" if state.connected() else "E / CONNECT RELAY"

func _process(delta: float) -> void:
	if moving_clouds: elapsed+=delta
	painted.set_shader_parameter("time_seconds",elapsed)
	if state.relay==State.Relay.LINKING: antenna.rotate_y(delta*0.3)

func _physics_process(delta: float) -> void:
	if shots_running or not is_instance_valid(walker): return
	if kit and kit.menu and kit.menu.opened: return
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir-=camera.global_basis.z
	if Input.is_physical_key_pressed(KEY_S): dir+=camera.global_basis.z
	if Input.is_physical_key_pressed(KEY_A): dir-=camera.global_basis.x
	if Input.is_physical_key_pressed(KEY_D): dir+=camera.global_basis.x
	if flying:
		if Input.is_physical_key_pressed(KEY_SPACE): dir+=Vector3.UP
		if Input.is_physical_key_pressed(KEY_Z): dir-=Vector3.UP
		camera.position+=dir.normalized()*delta*35.0
		return
	dir.y=0;dir=dir.normalized()
	var speed := 9.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 5.0
	if trex_toss_time>0:
		trex_toss_time-=delta;walker.velocity.x=trex_toss_velocity.x;walker.velocity.z=trex_toss_velocity.z;trex_toss_velocity.x=move_toward(trex_toss_velocity.x,0.0,delta*8);trex_toss_velocity.z=move_toward(trex_toss_velocity.z,0.0,delta*8)
	else: walker.velocity.x=dir.x*speed;walker.velocity.z=dir.z*speed
	if not walker.is_on_floor(): walker.velocity.y-=22.0*delta
	var jump := Input.is_physical_key_pressed(KEY_SPACE)
	if jump and not jump_held and walker.is_on_floor(): walker.velocity.y=7.0
	jump_held=jump
	walker.move_and_slide()
	if walker.position.y < -40: viewpoint(1)
	camera.position=walker.position+Vector3.UP*EYE

func toss_player(impulse: Vector3) -> void:
	trex_toss_velocity=impulse;trex_toss_time=.75;walker.velocity.y=impulse.y

func capture_sequence() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[args.find("--capture")+1]
	DirAccess.make_dir_recursive_absolute(folder)
	help.hide()
	for shot in ["fob-route","ridge","gully","compound","interior","overview","Railgun","Blade","Spear","Club","Improvised","Rock","vehicle-yard","wishbone-rig","wishbone-steer"]:
		if kit and shot in kit.names: kit.select_weapon(kit.names.find(shot));viewpoint(1)
		if shot in ["wishbone-rig","wishbone-steer"]:
			var car=kit.vehicles[0];car.freeze=true;car.set_physics_process(false);car.global_transform=Transform3D(Basis.IDENTITY,Vector3(-17,.25,9))
			if not car.inspection: car.toggle_inspection()
			car.controlled=true;car.set_controls(0,1 if shot=="wishbone-steer" else 0,true)
			for step in range(30): car._physics_process(1.0/60.0)
			kit.overlay.hide();camera.position=Vector3(-12,2.8,5);camera.look_at(Vector3(-17,1.0,9))
		if shot=="vehicle-yard":
			kit.overlay.hide();camera.position=Vector3(-24,5,24);camera.look_at(Vector3(-24,1.5,9))
		match shot:
			"fob-route": viewpoint(1);camera.look_at(Vector3(0,3,-100))
			"ridge": viewpoint(2)
			"gully": viewpoint(3)
			"compound": viewpoint(4)
			"interior": camera.position=Vector3(-19,1.85,-310);camera.look_at(Vector3(-19,1.5,-294))
			"overview": camera.position=Vector3(110,125,15);camera.look_at(Vector3(0,0,-160))
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(folder.path_join(shot+".png"))
		if error!=OK: get_tree().quit(1);return
	print("CAPTURE_PASS: tactical route, both approaches, compound, interior, overview")
	get_tree().quit()


func ring_gap() -> float:
	return 0.002

func local_ground(color: Color) -> ShaderMaterial:
	var mat=ShaderMaterial.new();mat.shader=preload("res://local_ground.gdshader");mat.set_shader_parameter("base_color",Vector3(color.r,color.g,color.b));return mat


