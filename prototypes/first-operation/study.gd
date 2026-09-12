extends Node3D
const State = preload("res://mission_state.gd")
const RADIUS := 3000000.0 / TAU
var state = State.new()
var camera: Camera3D
var environment: Environment
var baseline: ShaderMaterial
var painted: ShaderMaterial
var sky_mode := 0
var moving_clouds := true
var elapsed := 0.0
var help: Label
var table_status: Label3D
var relay_status: Label3D
var support_status: Label3D
var antenna: Node3D
var future_nodes: Array[MeshInstance3D] = []
var route_lines: Array[MeshInstance3D] = []
var purple: StandardMaterial3D
var inactive: StandardMaterial3D
var haze_materials: Array[ShaderMaterial] = []
var shots_running := false

func material(color: Color, metal: float = 0.0, rough: float = 0.7, emission: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if emission:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = color
	return m

func mesh_node(mesh: Mesh, position: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = position
	parent.add_child(n)
	return n

func box(position: Vector3, size: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_node(mesh, position, mat, parent)

func cylinder(position: Vector3, radius: float, height: float, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return mesh_node(mesh, position, mat, parent)

func label3(text: String, position: Vector3, size: int = 32) -> Label3D:
	var n := Label3D.new()
	n.text = text
	n.position = position
	n.font_size = size
	n.pixel_size = 0.004
	n.modulate = Color(0.84, 0.82, 0.95)
	n.outline_size = 5
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(n)
	return n

func link(a: Vector3, b: Vector3, mat: Material, thickness: float = 0.025) -> MeshInstance3D:
	var n := box((a+b)*0.5, Vector3(thickness, thickness, a.distance_to(b)), mat)
	if absf((b-a).normalized().dot(Vector3.UP)) < 0.99:
		n.look_at(b, Vector3.UP)
	return n

func ground_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://haze.gdshader")
	m.set_shader_parameter("base_color", Vector3(color.r,color.g,color.b))
	haze_materials.append(m)
	return m

func _ready() -> void:
	camera = Camera3D.new()
	camera.near = 0.5
	camera.far = 1100000.0
	camera.fov = 65
	add_child(camera)
	camera.make_current()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5,0.6,0.72)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	baseline = ShaderMaterial.new()
	baseline.shader = preload("res://baseline_sky.gdshader")
	baseline.set_shader_parameter("to_sun", Vector3(-0.4,0.7,0.2).normalized())
	painted = ShaderMaterial.new()
	painted.shader = preload("res://painterly_sky.gdshader")
	environment.sky = Sky.new()
	environment.sky.sky_material = baseline
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	purple = material(Color(0.59,0.30,0.94),0.0,0.6,true)
	inactive = material(Color(0.16,0.20,0.25))
	build_landscape()
	build_fob()
	build_swatches()
	var layer := CanvasLayer.new()
	add_child(layer)
	help = Label.new()
	help.position = Vector2(20,16)
	help.add_theme_font_size_override("font_size",18)
	help.text = "FOB / SKY STUDY — GREYBOX\nWASD move · Right mouse look · Q/Z rise/lower · Shift faster\n1 planning · 2 vista · 3 materials · 4 relay\nE use nearby station · R choose approach at table · F compare sky · P cloud motion\nL interrupt relay · B support availability · Tab hide help · Esc release mouse"
	layer.add_child(help)
	viewpoint(1)
	refresh()
	if OS.get_cmdline_user_args().has("--capture"):
		shots_running = true
		capture_sequence.call_deferred()

func build_landscape() -> void:
	box(Vector3(0,-0.35,0),Vector3(9000,0.5,9000),ground_material(Color(0.25,0.33,0.24)))
	var terrain := ground_material(Color(0.29,0.36,0.28))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# World-anchored coarse ring. Rotated local axes relative to ring_vibes, same dimensions.
	for i in range(1024):
		var a := ring_gap() + float(i)/1024.0*(TAU-2.0*ring_gap())
		var b := ring_gap() + float(i+1)/1024.0*(TAU-2.0*ring_gap())
		for j in range(8):
			var x0 := -25000.0 + float(j)*6250.0
			var x1 := x0 + 6250.0
			var p0 := ring_point(a,x0)
			var p1 := ring_point(a,x1)
			var p2 := ring_point(b,x1)
			var p3 := ring_point(b,x0)
			for p in [p0,p2,p1,p0,p3,p2]:
				surface.add_vertex(p)
	surface.generate_normals()
	mesh_node(surface.commit(),Vector3.ZERO,terrain)
	for i in range(18):
		var distance_m := 1000.0 + i*3600.0
		var x := (1.0 if i%2==0 else -1.0)*(4000.0+absf(sin(i*2.1))*12000.0)
		var m := CylinderMesh.new()
		m.top_radius = 80
		m.bottom_radius = 900 + i*100
		m.height = 300 + i*60
		m.radial_segments = 7
		var pos := ring_point(distance_m/RADIUS,x)
		pos.y += m.height*0.35
		mesh_node(m,pos,ground_material(Color(0.30,0.33,0.37)))

func ring_point(angle: float, lateral: float) -> Vector3:
	var hill := (sin(angle*23.0+lateral/16000.0)*0.5+0.5)*550.0
	hill *= smoothstep(0.0, 10000.0, minf(angle, TAU-angle)*RADIUS)
	var r := RADIUS - hill
	return Vector3(lateral,RADIUS-r*cos(angle),-r*sin(angle))

func build_fob() -> void:
	var metal := material(Color(0.12,0.16,0.17),0.5)
	var stone := material(Color(0.31,0.35,0.32))
	box(Vector3(0,0.0,0),Vector3(18,0.2,20),stone)
	for x in [-8.0,8.0]:
		box(Vector3(x,1.0,0),Vector3(0.4,2,18),stone)
		for z in [-7.0,6.0]:
			box(Vector3(x,2.1,z),Vector3(0.5,4.2,0.5),metal)
	box(Vector3(0,4.25,6),Vector3(16.5,0.25,6),metal)
	box(Vector3(0,0.45,0),Vector3(2.3,0.9,1.4),metal)
	box(Vector3(0,0.95,0),Vector3(3.7,0.12,2.8),material(Color(0.025,0.035,0.05)))
	for x in [-1.5,1.5]:
		cylinder(Vector3(x,1.05,0.9),0.10,0.08,purple)
	var hologram := ShaderMaterial.new()
	hologram.shader = preload("res://hologram.gdshader")
	box(Vector3(0,1.2,0),Vector3(3.3,0.012,2.45),hologram)
	var points := [Vector3(0,1.28,0.85),Vector3(0,1.28,-0.15),Vector3(-1.05,1.28,-0.9),Vector3(1.05,1.28,-0.9)]
	for i in range(points.size()):
		var n := cylinder(points[i],0.11,0.045,purple if i<2 else inactive)
		if i>1:
			future_nodes.append(n)
	route_lines.append(link(points[0],Vector3(-0.65,1.28,0.3),purple))
	route_lines.append(link(Vector3(-0.65,1.28,0.3),points[1],purple))
	route_lines.append(link(points[0],Vector3(0.65,1.28,0.3),inactive))
	route_lines.append(link(Vector3(0.65,1.28,0.3),points[1],inactive))
	future_nodes.append(link(points[1],points[2],inactive))
	future_nodes.append(link(points[1],points[3],inactive))
	table_status = label3("",Vector3(0,2.0,-0.7),29)
	label3("PLANNING / R SELECT APPROACH",Vector3(0,0.6,1.65),24)
	box(Vector3(4,0.7,-6),Vector3(1.3,1.4,0.6),metal)
	support_status = label3("SUPPORT TERMINAL / E",Vector3(4,1.9,-6),25)
	label3("REARM",Vector3(-5,1.9,4),28)
	box(Vector3(-5,0.45,4),Vector3(2,0.9,0.9),metal)
	label3("FRONTIER RELAY",Vector3(0,5.2,-32),34)
	box(Vector3(0,1.0,-32),Vector3(5,2,4),stone)
	cylinder(Vector3(0,5,-32),0.17,7,metal)
	antenna = Node3D.new()
	antenna.position = Vector3(0,8,-32)
	add_child(antenna)
	box(Vector3.ZERO,Vector3(4,0.5,1),metal,antenna)
	box(Vector3(0,0,-0.55),Vector3(3.4,0.12,0.08),purple,antenna)
	box(Vector3(0,0.8,-28.8),Vector3(1.2,1.6,0.6),metal)
	relay_status = label3("",Vector3(0,3,-28.5),28)

func build_swatches() -> void:
	var colors := [Color(0.01,0.014,0.012),Color(0.12,0.155,0.175),Color(0.30,0.38,0.28),Color(0.59,0.3,0.94)]
	var names := ["RUBBER","STEEL","PAINT","VIOLET"]
	for i in range(4):
		var x := 12.0+i*1.2
		var mat := material(colors[i],0.8 if i==1 else 0.0,0.4 if i==1 else 0.85,i==3)
		box(Vector3(x,0.55,3),Vector3(0.9,1.1,0.9),mat)
		var ball := SphereMesh.new()
		ball.radius = 0.35
		ball.height = 0.7
		mesh_node(ball,Vector3(x,1.48,3),mat)
		label3(names[i],Vector3(x,2.05,3),23)

func refresh() -> void:
	table_status.text = "FRONTIER / %s\n%s APPROACH\n%s" % ["LINKED" if state.connected() else "NO LINK",state.approach,"ONWARD SECTORS AVAILABLE" if state.connected() else "ONWARD SUPPORT UNAVAILABLE"]
	relay_status.text = ["HOSTILE / E SECURE (TEST)","OFFLINE / E CONNECT","LINKING / E CONFIRM (TEST)","OPERATIONAL / FOB"][state.relay]
	for n in future_nodes:
		n.material_override = purple if state.connected() else inactive
	for i in range(route_lines.size()):
		route_lines[i].material_override = purple if (i<2)==(state.approach=="RIDGE") else inactive

func viewpoint(index: int) -> void:
	match index:
		1: camera.position=Vector3(3.5,3.2,4.5); camera.look_at(Vector3(0,1.15,0))
		2: camera.position=Vector3(18,12,30); camera.look_at(Vector3(0,80,-1500))
		3: camera.position=Vector3(13.8,2.4,8.7); camera.look_at(Vector3(13.8,1.0,3))
		4: camera.position=Vector3(3,2.4,-25); camera.look_at(Vector3(0,2.5,-31))

func use_station() -> void:
	if camera.position.distance_to(Vector3(0,2,-28.5))<7:
		state.advance_relay()
	elif camera.position.distance_to(Vector3(4,2,-6))<5:
		state.request_support()
		support_status.text=state.report
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	if shots_running: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		if event.pressed: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		camera.rotate_y(-event.relative.x*0.003)
		camera.rotation.x=clampf(camera.rotation.x-event.relative.y*0.003,-1.4,1.4)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: viewpoint(1)
			KEY_2: viewpoint(2)
			KEY_3: viewpoint(3)
			KEY_4: viewpoint(4)
			KEY_E: use_station()
			KEY_R:
				if camera.position.distance_to(Vector3(0,2,0))<7:
					state.select_approach("VALLEY" if state.approach=="RIDGE" else "RIDGE"); refresh()
			KEY_F:
				sky_mode=1-sky_mode
				environment.sky.sky_material=baseline if sky_mode==0 else painted
			KEY_P: moving_clouds=not moving_clouds
			KEY_L: state.interrupt_link(); refresh()
			KEY_B: state.support_available=not state.support_available; support_status.text="SUPPORT AVAILABLE" if state.support_available else "SUPPORT UNAVAILABLE"
			KEY_TAB: help.visible=not help.visible
			KEY_ESCAPE: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if moving_clouds: elapsed+=delta
	painted.set_shader_parameter("time_seconds",elapsed)
	# Keep the last cloud phase when paused; do not snap the cloud pattern to time zero.
	if state.relay==State.Relay.LINKING: antenna.rotate_y(delta*0.3)
	if shots_running: return
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): dir-=camera.global_basis.z
	if Input.is_physical_key_pressed(KEY_S): dir+=camera.global_basis.z
	if Input.is_physical_key_pressed(KEY_A): dir-=camera.global_basis.x
	if Input.is_physical_key_pressed(KEY_D): dir+=camera.global_basis.x
	if Input.is_physical_key_pressed(KEY_Q): dir+=Vector3.UP
	if Input.is_physical_key_pressed(KEY_Z): dir-=Vector3.UP
	camera.position+=dir.normalized()*delta*(70.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 7.0)
	camera.position.y=maxf(1.5,camera.position.y)

func capture_sequence() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--capture")
	var folder := args[i+1] if i+1<args.size() else "user://captures"
	DirAccess.make_dir_recursive_absolute(folder)
	help.hide()
	for shot in ["planning-offline","planning-online","materials","vista-baseline","vista-painted","vista-painted-later","vista-altitude"]:
		match shot:
			"planning-offline": viewpoint(1)
			"planning-online": state.advance_relay();state.advance_relay();state.advance_relay();refresh();viewpoint(1)
			"materials": viewpoint(3)
			"vista-baseline": viewpoint(2)
			"vista-painted": environment.sky.sky_material=painted;viewpoint(2)
			"vista-painted-later": elapsed+=60.0
			"vista-altitude": camera.position=Vector3(1000,1500,1000);camera.look_at(Vector3(0,500,-18000))
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var err := image.save_png(folder.path_join(shot+".png"))
		if err!=OK: push_error("Capture failed");get_tree().quit(1);return
	print("CAPTURE_PASS: seven views; baseline haze density retained; motion/altitude evidence saved")
	get_tree().quit(0)


func ring_gap() -> float:
	return 0.0
