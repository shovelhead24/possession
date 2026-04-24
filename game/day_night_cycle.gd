extends Node3D
class_name DayNightCycle

@export var day_length_seconds: float = 7200.0  # Full day cycle in seconds (2 hours real time)
@export var start_time: float = 0.45  # 0.0 = midnight, 0.5 = noon — start just before noon

var time_of_day: float = 0.0
var cycle_paused: bool = false  # True when a preset is active (Shift+L/L1 to cycle, Shift+T to resume)
var sun_light: DirectionalLight3D
var environment: Environment
var world_env: WorldEnvironment

# Lighting presets — same as lighting test (Shift+L / L1 to cycle)
const PRESETS = [
	{ "name": "Noon",    "time": 0.50, "sun_energy": 1.4, "ambient": 0.3,  "shadow": true  },
	{ "name": "Sunset",  "time": 0.73, "sun_energy": 0.3, "ambient": 0.15, "shadow": true  },
	{ "name": "Night",   "time": 0.0,  "sun_energy": 0.0, "ambient": 0.1,  "shadow": false },
	{ "name": "Dawn",    "time": 0.26, "sun_energy": 0.25,"ambient": 0.12, "shadow": true  },
	{ "name": "HighSun", "time": 0.50, "sun_energy": 1.8, "ambient": 0.4,  "shadow": true  },
]
var current_preset: int = -1  # -1 = normal cycle (no preset active)
var sky_shader_material: ShaderMaterial
var sky_dome: MeshInstance3D = null
var _water_material: ShaderMaterial = null

# Colors for different times of day
var sun_color_day = Color(1.0, 0.95, 0.8)
var sun_color_sunset = Color(1.0, 0.6, 0.4)
var sun_color_night = Color(0.2, 0.3, 0.5)

var ambient_day = Color(0.5, 0.6, 0.7)
var ambient_night = Color(0.08, 0.07, 0.06)  # Warmer night ambient from gas giant

func _ready():
	time_of_day = start_time

	# Find existing DirectionalLight3D or create one
	sun_light = get_node_or_null("/root/World/DirectionalLight3D")
	if not sun_light:
		sun_light = get_tree().get_first_node_in_group("sun")
	if not sun_light:
		for child in get_parent().get_children():
			if child is DirectionalLight3D:
				sun_light = child
				break

	if not sun_light:
		sun_light = DirectionalLight3D.new()
		sun_light.shadow_enabled = true
		add_child(sun_light)
		print("DayNightCycle: Created new sun light")
	else:
		print("DayNightCycle: Using existing sun light: ", sun_light.name)

	# Exclude weapon layer (layer 2) so the day/night sun doesn't dim weapon models.
	# The dedicated WeaponLight inside the SubViewport handles weapon illumination.
	sun_light.light_cull_mask = 0xFFFFFD  # all layers except layer 2

	setup_environment()
	print("Day/Night cycle started at time: ", time_of_day)

func setup_environment():
	world_env = get_node_or_null("/root/World/WorldEnvironment")
	if not world_env:
		world_env = WorldEnvironment.new()
		get_parent().add_child(world_env)
		world_env.name = "WorldEnvironment"

	if world_env.environment:
		environment = world_env.environment
	else:
		environment = Environment.new()
		world_env.environment = environment

	# GL Compatibility does NOT support shader_type sky — use a sky dome instead:
	# a large sphere rendered from the inside with a shader_type spatial material.
	environment.background_mode = Environment.BG_COLOR
	environment.background_color  = Color(0.02, 0.04, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color  = Color(0.5, 0.6, 0.7)
	environment.ambient_light_energy = 0.3

	var dome_shader = load("res://sky_dome_shader.gdshader")
	if not dome_shader:
		push_error("DayNightCycle: sky_dome_shader.gdshader not found!")
		return

	sky_shader_material = ShaderMaterial.new()
	sky_shader_material.shader = dome_shader

	# Load 5 faces — dn omitted, ground always occludes it.
	# Orientations are baked into the PNGs; no runtime transforms needed.
	var faces = {
		"ft": "res://skybox/Installation05_01ft.png",
		"bk": "res://skybox/Installation05_01bk.png",
		"lf": "res://skybox/Installation05_01lf.png",
		"rt": "res://skybox/Installation05_01rt.png",
		"up": "res://skybox/Installation05_01up.png",
	}
	for face in faces:
		var img = Image.load_from_file(faces[face])
		if img:
			img.convert(Image.FORMAT_RGBA8)
			sky_shader_material.set_shader_parameter("face_" + face, ImageTexture.create_from_image(img))
		else:
			push_error("DayNightCycle: missing skybox face: " + faces[face])

	var sphere     = SphereMesh.new()
	sphere.radius  = 9000.0
	sphere.height  = 18000.0
	sphere.radial_segments = 128
	sphere.rings   = 64

	sky_dome = MeshInstance3D.new()
	sky_dome.name = "SkyDome"
	sky_dome.mesh = sphere
	sky_dome.material_override = sky_shader_material
	sky_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_dome.gi_mode    = GeometryInstance3D.GI_MODE_DISABLED
	sky_dome.layers     = 1
	# Defer add_child — calling during _ready() while parent initialises children
	# causes a "parent node is busy" error and silently drops the node.
	get_parent().add_child.call_deferred(sky_dome)
	print("DayNightCycle: Sky dome created")

# Controller edge-detection state for L1
var _l1_was_pressed: bool = false

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.shift_pressed:
			match event.keycode:
				KEY_L:
					_cycle_preset()
				KEY_T:
					_resume_cycle()

func _process(delta):
	# Poll controller L1 with edge detection
	var l1 = Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER)
	if l1 and not _l1_was_pressed:
		_cycle_preset()
	_l1_was_pressed = l1

	if not cycle_paused:
		time_of_day += delta / day_length_seconds
		if time_of_day >= 1.0:
			time_of_day -= 1.0

	update_sun()
	update_lighting()

	if sky_dome and sky_dome.is_inside_tree():
		var camera = get_viewport().get_camera_3d()
		if camera and camera.is_inside_tree():
			sky_dome.global_position = camera.global_position

func _cycle_preset():
	current_preset = (current_preset + 1) % PRESETS.size()
	var p = PRESETS[current_preset]
	time_of_day = p["time"]
	cycle_paused = true
	update_sun()
	update_lighting()
	sun_light.light_energy = p["sun_energy"]
	sun_light.shadow_enabled = p["shadow"]
	if environment:
		environment.ambient_light_energy = p["ambient"]
	print("Lighting preset: ", p["name"], " (Shift+T to resume cycle)")

func _resume_cycle():
	cycle_paused = false
	current_preset = -1
	print("Day/night cycle resumed")

func update_sun():
	var sun_elevation = sin(time_of_day * TAU - PI / 2.0) * 90.0
	var sun_azimuth_deg = fmod(time_of_day * 360.0 + 180.0, 360.0)
	var er = deg_to_rad(sun_elevation)
	var ar = deg_to_rad(sun_azimuth_deg)
	var sun_dir = Vector3(cos(er) * sin(ar), sin(er), cos(er) * cos(ar))
	if sun_dir.length_squared() > 0.001:
		var up = Vector3.FORWARD if abs(sun_dir.y) > 0.99 else Vector3.UP
		sun_light.basis = Basis.looking_at(-sun_dir, up)

func update_lighting():
	var sun_elevation = sin(time_of_day * TAU - PI/2.0) * 90
	var sun_visible = check_sun_visibility()

	var sun_intensity: float
	var sun_color: Color
	var ambient_color: Color

	if sun_elevation > 30:
		sun_intensity = 1.0
		sun_color = sun_color_day
		ambient_color = ambient_day
	elif sun_elevation > 10:
		var t = (30 - sun_elevation) / 20
		sun_intensity = lerp(1.0, 0.3, t)
		sun_color = sun_color_day.lerp(sun_color_sunset, t)
		ambient_color = ambient_day
	elif sun_elevation > -5:
		var t = (10 - sun_elevation) / 15
		if not sun_visible:
			t = min(t + 0.4, 1.0)
		sun_intensity = lerp(0.3, 0.0, t)
		sun_color = sun_color_sunset.lerp(sun_color_night, t)
		ambient_color = ambient_day.lerp(ambient_night, t)
	else:
		sun_intensity = 0.0
		sun_color = sun_color_night
		ambient_color = ambient_night

	sun_light.light_energy = sun_intensity
	sun_light.light_color = sun_color
	sun_light.visible = sun_elevation > -5

	if environment:
		environment.ambient_light_color  = ambient_color
		environment.ambient_light_energy = 0.3 if sun_elevation > 0 else 0.15
		var fog_day = Color(0.52, 0.62, 0.78)
		var fog_night = Color(0.05, 0.06, 0.10)
		var fog_t = clampf(sun_elevation / 30.0, 0.0, 1.0)
		environment.fog_light_color = fog_day.lerp(fog_night, 1.0 - fog_t)

	if not _water_material:
		var tm = get_node_or_null("/root/World/TerrainManager")
		if tm and "water_plane" in tm and tm.water_plane:
			_water_material = tm.water_plane.material_override as ShaderMaterial
	if _water_material:
		var sun_dir = -sun_light.global_transform.basis.z
		_water_material.set_shader_parameter("sun_direction",
			Vector3(sun_dir.x, sun_dir.y, sun_dir.z))

	var sun_azimuth = fmod(time_of_day * 360.0 + 180.0, 360.0)
	if sky_shader_material:
		sky_shader_material.set_shader_parameter("sun_elevation", sun_elevation)
		sky_shader_material.set_shader_parameter("sun_azimuth",   sun_azimuth)
		sky_shader_material.set_shader_parameter("sun_color",
				Vector3(sun_color.r, sun_color.g, sun_color.b))

func check_sun_visibility() -> bool:
	var sun_direction = -sun_light.global_transform.basis.z
	var space_state = get_world_3d().direct_space_state
	var camera = get_viewport().get_camera_3d()
	if not camera or not camera.is_inside_tree():
		return true
	var from = camera.global_position
	var to = from - (sun_direction * 1000)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	return space_state.intersect_ray(query).is_empty()

func get_time_string() -> String:
	var hours = int(time_of_day * 24)
	var minutes = int((time_of_day * 24 - hours) * 60)
	return "%02d:%02d" % [hours, minutes]
