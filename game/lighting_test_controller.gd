extends Node3D
# Lighting Test Area — self-contained benchmarking scene for iterating
# on lighting settings without the full world overhead.
#
# Keys (KB / Controller):
#   WASD + Mouse / Left Stick + Right Stick = fly camera
#   Space / A button = ascend, C / LT = descend
#   Ctrl / RT = sprint
#   Shift+L / L1 = cycle lighting preset
#   Shift+S / R1 = toggle shadows
#   Shift+N / Triangle = toggle normal maps
#   Shift+M / DPad Left-Right = cycle shadow_max_distance
#   Shift+A / DPad Up-Down = cycle ambient energy
#   Shift+G / Square = cycle geometry stress test
#   Shift+F / L3 = toggle flashlight
#   Shift+T / R3 = toggle time flow (pause/play day cycle)
#   Shift+B / Options = start/stop benchmark (tests all settings)
#   Shift+Q / Create = write CSV log to logs/
#   F2 / Circle = return to world.tscn (toggle)

# -- Camera --
var camera: Camera3D
var cam_speed: float = 20.0
var mouse_sens: float = 0.003
var pitch: float = 0.0
var yaw: float = 0.0
var stick_look_sens: float = 2.5  # Radians/sec at full stick deflection

# -- Lighting --
var sun_light: DirectionalLight3D
var environment: Environment
var world_env: WorldEnvironment
var sky_dome: MeshInstance3D
var sky_material: ShaderMaterial

# -- Test materials --
var terrain_material: ShaderMaterial
var water_material: ShaderMaterial

# -- Presets --
const PRESETS = [
	{ "name": "Noon",    "time": 0.50, "sun_energy": 1.4, "ambient": 0.3,  "shadow": true  },
	{ "name": "Sunset",  "time": 0.73, "sun_energy": 0.3, "ambient": 0.15, "shadow": true  },
	{ "name": "Night",   "time": 0.0,  "sun_energy": 0.0, "ambient": 0.1,  "shadow": false },
	{ "name": "Dawn",    "time": 0.26, "sun_energy": 0.25,"ambient": 0.12, "shadow": true  },
	{ "name": "HighSun", "time": 0.50, "sun_energy": 1.8, "ambient": 0.4,  "shadow": true  },
]
var current_preset: int = 0

# -- A/B toggles --
var shadow_distances := [100.0, 300.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0]
var shadow_dist_idx: int = 1  # Start at 300
var ambient_levels := [0.1, 0.2, 0.3, 0.5, 0.8]
var ambient_idx: int = 2  # Start at 0.3
var normals_enabled: bool = true

# -- Benchmark --
var benchmark_active: bool = false
var benchmark_waypoints: Array[Vector3] = []
var benchmark_look_targets: Array[Vector3] = []
var benchmark_idx: int = 0
var benchmark_t: float = 0.0
var benchmark_speed: float = 0.15  # 0-1 interpolation per second

# -- Logging --
var log_data: PackedStringArray = PackedStringArray()
var frame_count: int = 0

# -- HUD --
var stats_label: Label
var controls_label: Label
var preset_label: Label

# -- Controller edge detection (DS4Windows may not deliver InputEventJoypadButton) --
var _prev_joy := {}

# -- Geometry stress test --
var stress_node: Node3D = null
var stress_level: int = 0
var stress_levels := [0, 500, 2000, 10000, 50000, 100000, 1000, 5000, 20000]
var stress_level_names := ["None", "500", "2k", "10k", "50k", "100k", "chunk_1k", "chunk_5k", "chunk_20k"]
var stress_materials: Array = []  # 4 StandardMaterial3D with terrain textures

# -- Flashlight --
var flashlight: SpotLight3D

# -- Continuous day/night --
var test_time: float = 0.5  # Current time of day (0-1)
var time_speed: float = 0.02  # Full cycle in ~50 seconds
var time_running: bool = true  # Auto-advance time

# -- Benchmark passes --
var benchmark_passes := [
	{"label": "baseline", "shadows": true, "shadow_dist": 300.0, "stress": 0},
	{"label": "no_shadows", "shadows": false, "shadow_dist": 300.0, "stress": 0},
	{"label": "shadow_100m", "shadows": true, "shadow_dist": 100.0, "stress": 0},
	{"label": "shadow_1km", "shadows": true, "shadow_dist": 1000.0, "stress": 0},
	{"label": "stress_2k", "shadows": true, "shadow_dist": 300.0, "stress": 2},
	{"label": "stress_10k", "shadows": true, "shadow_dist": 300.0, "stress": 3},
	{"label": "stress_50k", "shadows": true, "shadow_dist": 300.0, "stress": 4},
	{"label": "stress_100k", "shadows": true, "shadow_dist": 300.0, "stress": 5},
	{"label": "chunk_1k",   "shadows": true, "shadow_dist": 300.0,  "stress": 6},
	{"label": "chunk_5k",   "shadows": true, "shadow_dist": 300.0,  "stress": 7},
	{"label": "chunk_20k",  "shadows": true, "shadow_dist": 1000.0, "stress": 8},
]
var benchmark_pass_idx: int = 0

# -- Sun color LUT (matching day_night_cycle.gd) --
var sun_color_day := Color(1.0, 0.95, 0.8)
var sun_color_sunset := Color(1.0, 0.6, 0.4)
var sun_color_night := Color(0.2, 0.3, 0.5)

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_camera()
	_build_flashlight()
	_build_lighting()
	_build_sky_dome()
	_build_test_geometry()
	_build_stress_materials()
	_build_hud()
	_setup_benchmark_path()
	apply_preset(current_preset)

# ------------------------------------------------------------------ #
#  CAMERA                                                             #
# ------------------------------------------------------------------ #
func _build_camera():
	camera = Camera3D.new()
	camera.name = "TestCamera"
	camera.position = Vector3(0, 110, 80)
	camera.far = 15000.0
	camera.current = true
	add_child(camera)
	pitch = -0.15

func _build_flashlight():
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_energy = 4.0
	flashlight.spot_range = 60.0
	flashlight.spot_angle = 25.0
	flashlight.shadow_enabled = true
	flashlight.visible = false
	camera.add_child(flashlight)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sens
		pitch -= event.relative.y * mouse_sens
		pitch = clampf(pitch, -PI / 2.0, PI / 2.0)

func _joy_just_pressed(button: int) -> bool:
	var pressed = Input.is_joy_button_pressed(0, button)
	var was = _prev_joy.get(button, false)
	_prev_joy[button] = pressed
	return pressed and not was

func _process(delta):
	# Continuous day/night cycle
	if time_running and not benchmark_active:
		test_time += delta * time_speed
		if test_time >= 1.0: test_time -= 1.0
	_update_sun_from_time(test_time)

	if not benchmark_active:
		_process_free_camera(delta)
	else:
		_process_benchmark(delta)
	_poll_controller()
	_update_hud()
	_log_frame()

func _process_free_camera(delta):
	# Controller right stick look
	var rs_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var rs_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if abs(rs_x) > 0.15:
		yaw -= rs_x * stick_look_sens * delta
	if abs(rs_y) > 0.15:
		pitch -= rs_y * stick_look_sens * delta
		pitch = clampf(pitch, -PI / 2.0, PI / 2.0)

	camera.rotation = Vector3(pitch, yaw, 0)

	var dir := Vector3.ZERO
	var shift_held = Input.is_key_pressed(KEY_SHIFT)
	if Input.is_key_pressed(KEY_W): dir.z -= 1
	if Input.is_key_pressed(KEY_S) and not shift_held: dir.z += 1
	if Input.is_key_pressed(KEY_A) and not shift_held: dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_SPACE): dir.y += 1
	if Input.is_key_pressed(KEY_C): dir.y -= 1

	# Controller left stick
	var ls_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ls_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if abs(ls_x) > 0.15: dir.x += ls_x
	if abs(ls_y) > 0.15: dir.z += ls_y
	# Controller: A = ascend, LT = descend
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		dir.y += 1
	if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.3:
		dir.y -= 1

	var speed = cam_speed
	if Input.is_key_pressed(KEY_CTRL):
		speed *= 5.0
	if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.3:
		speed *= 5.0

	if dir.length() > 0:
		dir = dir.normalized()
		var move = camera.global_transform.basis * dir * speed * delta
		camera.position += move

func _input(event):
	# Keyboard toggles require Shift to avoid conflicting with WASD movement
	if event is InputEventKey and event.pressed and not event.echo:
		if event.shift_pressed:
			match event.keycode:
				KEY_L:
					current_preset = (current_preset + 1) % PRESETS.size()
					apply_preset(current_preset)
				KEY_S:
					sun_light.shadow_enabled = not sun_light.shadow_enabled
				KEY_N:
					normals_enabled = not normals_enabled
					if terrain_material:
						terrain_material.set_shader_parameter("normal_map_strength", 0.8 if normals_enabled else 0.0)
				KEY_M:
					shadow_dist_idx = (shadow_dist_idx + 1) % shadow_distances.size()
					sun_light.directional_shadow_max_distance = shadow_distances[shadow_dist_idx]
				KEY_A:
					ambient_idx = (ambient_idx + 1) % ambient_levels.size()
					environment.ambient_light_energy = ambient_levels[ambient_idx]
				KEY_B:
					_toggle_benchmark()
				KEY_G:
					_cycle_stress_test()
				KEY_F:
					flashlight.visible = not flashlight.visible
				KEY_T:
					time_running = not time_running
				KEY_Q:
					_write_log()
		else:
			if event.is_action_pressed("lighting_test"):
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_tree().change_scene_to_file("res://world.tscn")

func _poll_controller():
	# Poll controller buttons with edge detection — more reliable than
	# InputEventJoypadButton when using DS4Windows with PS5 controllers
	if _joy_just_pressed(JOY_BUTTON_LEFT_SHOULDER):  # L1 = cycle preset
		current_preset = (current_preset + 1) % PRESETS.size()
		apply_preset(current_preset)
	if _joy_just_pressed(JOY_BUTTON_RIGHT_SHOULDER):  # R1 = toggle shadows
		sun_light.shadow_enabled = not sun_light.shadow_enabled
	if _joy_just_pressed(JOY_BUTTON_Y):  # Triangle = toggle normals
		normals_enabled = not normals_enabled
		if terrain_material:
			terrain_material.set_shader_parameter("normal_map_strength", 0.8 if normals_enabled else 0.0)
	if _joy_just_pressed(JOY_BUTTON_X):  # Square = cycle stress test
		_cycle_stress_test()
	if _joy_just_pressed(JOY_BUTTON_LEFT_STICK):  # L3 = flashlight
		flashlight.visible = not flashlight.visible
	if _joy_just_pressed(JOY_BUTTON_RIGHT_STICK):  # R3 = time pause/play
		time_running = not time_running
	if _joy_just_pressed(JOY_BUTTON_DPAD_UP):  # DPad Up = ambient up
		ambient_idx = (ambient_idx + 1) % ambient_levels.size()
		environment.ambient_light_energy = ambient_levels[ambient_idx]
	if _joy_just_pressed(JOY_BUTTON_DPAD_DOWN):  # DPad Down = ambient down
		ambient_idx = (ambient_idx - 1 + ambient_levels.size()) % ambient_levels.size()
		environment.ambient_light_energy = ambient_levels[ambient_idx]
	if _joy_just_pressed(JOY_BUTTON_DPAD_LEFT):  # DPad Left = shadow dist down
		shadow_dist_idx = (shadow_dist_idx - 1 + shadow_distances.size()) % shadow_distances.size()
		sun_light.directional_shadow_max_distance = shadow_distances[shadow_dist_idx]
	if _joy_just_pressed(JOY_BUTTON_DPAD_RIGHT):  # DPad Right = shadow dist up
		shadow_dist_idx = (shadow_dist_idx + 1) % shadow_distances.size()
		sun_light.directional_shadow_max_distance = shadow_distances[shadow_dist_idx]
	if _joy_just_pressed(JOY_BUTTON_START):  # Options = benchmark
		_toggle_benchmark()
	if _joy_just_pressed(JOY_BUTTON_BACK):  # Create = write CSV
		_write_log()
	if _joy_just_pressed(JOY_BUTTON_B):  # Circle = landscape scene
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://world.tscn")

# ------------------------------------------------------------------ #
#  LIGHTING                                                           #
# ------------------------------------------------------------------ #
func _build_lighting():
	sun_light = DirectionalLight3D.new()
	sun_light.name = "TestSun"
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.1
	sun_light.shadow_normal_bias = 1.0
	sun_light.directional_shadow_max_distance = shadow_distances[shadow_dist_idx]
	add_child(sun_light)

	world_env = WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.04, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.6, 0.7)
	environment.ambient_light_energy = 0.3
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.52, 0.62, 0.78)
	environment.fog_density = 0.00004
	environment.fog_depth_begin = 5000.0
	environment.fog_depth_end = 10000.0
	world_env.environment = environment
	add_child(world_env)

func apply_preset(idx: int):
	var p = PRESETS[idx]
	test_time = p["time"]
	time_running = false  # Pause on preset jump (Shift+T to resume)
	_update_sun_from_time(test_time)
	# Apply preset-specific overrides on top of computed values
	sun_light.light_energy = p["sun_energy"]
	sun_light.shadow_enabled = p["shadow"]
	environment.ambient_light_energy = p["ambient"]

func _update_sun_from_time(t: float):
	# Compute sun direction to match sky dome visual — uses Basis instead of
	# Euler angles to avoid rotation-order issues that caused 90/180° offsets
	var sun_elevation = sin(t * TAU - PI / 2.0) * 90.0
	var sun_azimuth_deg = fmod(t * 360.0 + 180.0, 360.0)
	var er = deg_to_rad(sun_elevation)
	var ar = deg_to_rad(sun_azimuth_deg)
	var sun_dir = Vector3(cos(er) * sin(ar), sin(er), cos(er) * cos(ar))
	if sun_dir.length_squared() > 0.001:
		var up = Vector3.FORWARD if abs(sun_dir.y) > 0.99 else Vector3.UP
		sun_light.basis = Basis.looking_at(-sun_dir, up)

	# Sun energy and color (matches day_night_cycle.gd logic)
	if sun_elevation > 30:
		sun_light.light_energy = 1.0
		sun_light.light_color = sun_color_day
	elif sun_elevation > 10:
		var blend = (30.0 - sun_elevation) / 20.0
		sun_light.light_energy = lerp(1.0, 0.3, blend)
		sun_light.light_color = sun_color_day.lerp(sun_color_sunset, blend)
	elif sun_elevation > -5:
		var blend = (10.0 - sun_elevation) / 15.0
		sun_light.light_energy = lerp(0.3, 0.0, blend)
		sun_light.light_color = sun_color_sunset.lerp(sun_color_night, blend)
	else:
		sun_light.light_energy = 0.0
		sun_light.light_color = sun_color_night

	sun_light.visible = sun_elevation > -5

	# Fog
	var fog_day = Color(0.52, 0.62, 0.78)
	var fog_night = Color(0.05, 0.06, 0.10)
	var fog_t = clampf(sun_elevation / 30.0, 0.0, 1.0)
	environment.fog_light_color = fog_day.lerp(fog_night, 1.0 - fog_t)

	# Sky dome
	if sky_material:
		sky_material.set_shader_parameter("sun_elevation", sun_elevation)
		sky_material.set_shader_parameter("sun_azimuth", sun_azimuth_deg)
		sky_material.set_shader_parameter("sun_color",
			Vector3(sun_light.light_color.r, sun_light.light_color.g, sun_light.light_color.b))

	# Water
	if water_material:
		var water_sun = -sun_light.global_transform.basis.z
		water_material.set_shader_parameter("sun_direction",
			Vector3(water_sun.x, water_sun.y, water_sun.z))

# ------------------------------------------------------------------ #
#  SKY DOME                                                           #
# ------------------------------------------------------------------ #
func _build_sky_dome():
	var dome_shader = load("res://sky_dome_shader.gdshader")
	if not dome_shader:
		return

	sky_material = ShaderMaterial.new()
	sky_material.shader = dome_shader

	var sphere = SphereMesh.new()
	sphere.radius = 12000.0
	sphere.height = 24000.0
	sphere.radial_segments = 24
	sphere.rings = 12

	sky_dome = MeshInstance3D.new()
	sky_dome.name = "SkyDome"
	sky_dome.mesh = sphere
	sky_dome.material_override = sky_material
	sky_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_dome.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(sky_dome)

# ------------------------------------------------------------------ #
#  TEST GEOMETRY                                                      #
# ------------------------------------------------------------------ #
func _build_test_geometry():
	var geo = Node3D.new()
	geo.name = "TestGeometry"
	add_child(geo)

	_build_terrain_material()

	# -- Dark ground floor for visual reference and text readability --
	var floor_mi = MeshInstance3D.new()
	floor_mi.name = "GroundFloor"
	var floor_plane = PlaneMesh.new()
	floor_plane.size = Vector2(22000, 22000)
	floor_mi.mesh = floor_plane
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.12, 0.14, 0.12)
	floor_mi.material_override = floor_mat
	floor_mi.position = Vector3(0, 35, 0)
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geo.add_child(floor_mi)

	# -- Terrain texture planes --
	# Each plane is positioned at a Y value that activates its shader zone
	# Heights chosen to match terrain_shader.gdshader zone thresholds:
	#   Sand/beach: water_height(48) to +beach_height_max(15) = Y 48-63
	#   Grass: above beach, below stone_start(200)
	#   Stone: stone_start(200) to snow_start(300)
	#   Snow: above snow_full(360)
	_add_plane(geo, "GrassPlane",  Vector3(-50, 100, 0),  40.0, terrain_material)
	_add_plane(geo, "SandPlane",   Vector3(0, 52, 0),     40.0, terrain_material)
	_add_plane(geo, "StonePlane",  Vector3(50, 250, 0),   40.0, terrain_material)
	_add_plane(geo, "SnowPlane",   Vector3(-50, 380, 0),  40.0, terrain_material)

	# -- Slope ramp (tests cliff blending at stone zone height) --
	_add_slope_ramp(geo, Vector3(50, 100, -60), 40.0, 40.0, terrain_material)

	# -- Water plane --
	_build_water_plane(geo, Vector3(0, 48, -60), 60.0)

	# -- Monolith pair (same as ancient_structures.gd) --
	_add_monolith_pair(geo, Vector3(0, 35, -150))

	# -- Distance posts (shadow/LOD reference markers) --
	var post_distances = [100, 300, 500, 1000, 2000, 3000, 5000, 7000, 10000]
	for d in post_distances:
		_add_distance_post(geo, d)

	# -- Stress test container (populated by _cycle_stress_test) --
	stress_node = Node3D.new()
	stress_node.name = "StressGeometry"
	geo.add_child(stress_node)

func _build_terrain_material():
	TerrainChunk._ensure_textures_loaded()
	var shader = TerrainChunk._tex_shader
	if not shader or not TerrainChunk._tex_grass or not TerrainChunk._tex_snow:
		# Fallback: simple grey material
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.5, 0.5)
		terrain_material = null
		return

	terrain_material = ShaderMaterial.new()
	terrain_material.shader = shader
	terrain_material.set_shader_parameter("grass_texture", TerrainChunk._tex_grass)
	terrain_material.set_shader_parameter("snow_texture", TerrainChunk._tex_snow)
	terrain_material.set_shader_parameter("stone_texture", TerrainChunk._tex_stone if TerrainChunk._tex_stone else TerrainChunk._tex_grass)
	if TerrainChunk._tex_sand:
		terrain_material.set_shader_parameter("sand_texture", TerrainChunk._tex_sand)

	# Normal maps
	var gnorm = TerrainChunk._tex_grass_normal
	var snorm = TerrainChunk._tex_stone_normal if TerrainChunk._tex_stone_normal else gnorm
	var wsnorm = TerrainChunk._tex_snow_normal if TerrainChunk._tex_snow_normal else snorm
	if gnorm:
		terrain_material.set_shader_parameter("grass_normal", gnorm)
		terrain_material.set_shader_parameter("sand_normal", gnorm)
	if snorm:
		terrain_material.set_shader_parameter("stone_normal", snorm)
	terrain_material.set_shader_parameter("snow_normal", wsnorm if wsnorm else gnorm)

	terrain_material.set_shader_parameter("texture_scale", 0.05)
	terrain_material.set_shader_parameter("cliff_texture_scale", 0.08)
	terrain_material.set_shader_parameter("snow_start_height", 300.0)
	terrain_material.set_shader_parameter("snow_full_height", 360.0)
	terrain_material.set_shader_parameter("stone_blend_range", 100.0)
	terrain_material.set_shader_parameter("slope_snow_threshold", 0.5)
	terrain_material.set_shader_parameter("cliff_slope_start", 0.55)
	terrain_material.set_shader_parameter("cliff_slope_full", 0.35)
	terrain_material.set_shader_parameter("beach_height_max", 15.0)
	terrain_material.set_shader_parameter("beach_slope_min", 0.85)
	terrain_material.set_shader_parameter("water_height", 48.0)
	terrain_material.set_shader_parameter("max_terrain_height", 400.0)
	terrain_material.set_shader_parameter("use_vertex_color_tint", false)
	terrain_material.set_shader_parameter("normal_map_strength", 0.8)

func _make_plane_mesh(size: float, subdivisions: int = 4) -> ArrayMesh:
	# SurfaceTool plane with vertex color alpha=0 to prevent terrain shader
	# grass paint override (terrain_color = mix(terrain_color, grass, COLOR.a))
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_color(Color(0.5, 0.5, 0.5, 0.0))
	var half = size / 2.0
	var step = size / float(subdivisions)
	for iz in range(subdivisions):
		for ix in range(subdivisions):
			var x0 = -half + ix * step
			var x1 = x0 + step
			var z0 = -half + iz * step
			var z1 = z0 + step
			# CCW winding as viewed from above (+Y) = front face up
			st.add_vertex(Vector3(x0, 0, z0))
			st.add_vertex(Vector3(x1, 0, z0))
			st.add_vertex(Vector3(x0, 0, z1))
			st.add_vertex(Vector3(x1, 0, z0))
			st.add_vertex(Vector3(x1, 0, z1))
			st.add_vertex(Vector3(x0, 0, z1))
	return st.commit()

func _add_plane(parent: Node3D, label: String, pos: Vector3, size: float, mat: Material):
	var mi = MeshInstance3D.new()
	mi.name = label
	mi.mesh = _make_plane_mesh(size)
	if mat:
		mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

	var post_label = Label3D.new()
	post_label.text = label.replace("Plane", "")
	post_label.font_size = 96
	post_label.position = pos + Vector3(0, 3, -size / 2.0 - 2)
	post_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	post_label.outline_size = 12
	post_label.outline_modulate = Color(0, 0, 0, 1)
	parent.add_child(post_label)

func _add_slope_ramp(parent: Node3D, pos: Vector3, width: float, length: float, mat: Material):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 70-degree slope — steep enough to trigger cliff texture
	# (cliff_slope_start=0.55, cliff_slope_full=0.35; cos(70)=0.342 < 0.35 → full cliff)
	var half_w = width / 2.0
	var run = length * 0.4  # Horizontal extent
	var rise = run * tan(deg_to_rad(70.0))  # Vertical rise
	var v0 = Vector3(-half_w, 0, 0)
	var v1 = Vector3(half_w, 0, 0)
	var v2 = Vector3(-half_w, rise, -run)
	var v3 = Vector3(half_w, rise, -run)

	# Normal perpendicular to slope, facing camera (+Z side)
	st.set_normal(Vector3(0, 0.342, 0.940))
	st.set_color(Color(0.5, 0.5, 0.5, 0.0))
	# CCW winding so front face is visible from camera side
	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v1)
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)

	var mesh = st.commit()
	var mi = MeshInstance3D.new()
	mi.name = "SlopeRamp"
	mi.mesh = mesh
	if mat:
		mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

	var lbl = Label3D.new()
	lbl.text = "Slope (cliff test)"
	lbl.font_size = 96
	lbl.position = pos + Vector3(0, 3, 5)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0, 1)
	parent.add_child(lbl)

func _build_water_plane(parent: Node3D, pos: Vector3, size: float):
	var water_shader = load("res://water_shader.gdshader") as Shader
	if water_shader:
		water_material = ShaderMaterial.new()
		water_material.shader = water_shader
		water_material.set_shader_parameter("wave_speed", 0.25)
		water_material.set_shader_parameter("wave_height", 1.2)
		water_material.set_shader_parameter("glitter_intensity", 1.8)
		water_material.set_shader_parameter("specular_intensity", 2.5)
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.3, 0.6, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mi = MeshInstance3D.new()
	mi.name = "WaterPlane"
	var plane = PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 16
	plane.subdivide_depth = 16
	mi.mesh = plane
	mi.material_override = water_material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

	var lbl = Label3D.new()
	lbl.text = "Water"
	lbl.font_size = 96
	lbl.position = pos + Vector3(0, 3, -size / 2.0 - 2)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0, 1)
	parent.add_child(lbl)

func _add_monolith_pair(parent: Node3D, center: Vector3):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.68, 0.66, 0.63)
	mat.roughness = 0.88

	var mono_size = Vector3(38, 180, 38)
	var gap = 55.0
	var half_span = (gap + mono_size.x) * 0.5
	var center_y = center.y - 60.0 + mono_size.y * 0.5

	for side in [-1.0, 1.0]:
		var mi = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = mono_size
		mi.mesh = box
		mi.material_override = mat
		mi.position = Vector3(center.x + side * half_span, center_y, center.z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)

	var lbl = Label3D.new()
	lbl.text = "Monolith"
	lbl.font_size = 96
	lbl.position = Vector3(center.x, center_y + mono_size.y * 0.5 + 5, center.z)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0, 1)
	parent.add_child(lbl)

func _add_distance_post(parent: Node3D, distance: int):
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(2, 20, 2)
	mi.mesh = box
	mi.position = Vector3(0, 60, -float(distance))

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.8, 0) if distance <= 300 else Color(0.8, 0.2, 0.2)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

	var lbl = Label3D.new()
	lbl.text = str(distance) + "m"
	lbl.font_size = 128
	lbl.position = mi.position + Vector3(0, 14, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0, 1)
	parent.add_child(lbl)

# ------------------------------------------------------------------ #
#  GEOMETRY STRESS TEST                                               #
# ------------------------------------------------------------------ #
func _build_stress_materials():
	# 4 StandardMaterial3D with terrain textures + normals for stress objects
	TerrainChunk._ensure_textures_loaded()
	var tex_pairs = [
		[TerrainChunk._tex_grass, TerrainChunk._tex_grass_normal],
		[TerrainChunk._tex_sand, TerrainChunk._tex_grass_normal],
		[TerrainChunk._tex_stone, TerrainChunk._tex_stone_normal],
		[TerrainChunk._tex_snow, TerrainChunk._tex_snow_normal],
	]
	stress_materials.clear()
	for pair in tex_pairs:
		var mat = StandardMaterial3D.new()
		if pair[0]:
			mat.albedo_texture = pair[0]
		else:
			mat.albedo_color = Color(0.5, 0.5, 0.5)
		if pair[1]:
			mat.normal_enabled = true
			mat.normal_texture = pair[1]
		mat.roughness = 0.85
		stress_materials.append(mat)

func _cycle_stress_test():
	stress_level = (stress_level + 1) % stress_levels.size()
	_build_stress_geometry(stress_levels[stress_level])
	print("Stress test: ", stress_level_names[stress_level])

func _build_stress_geometry(count: int):
	if not stress_node:
		return
	# Clear previous
	for child in stress_node.get_children():
		child.queue_free()
	if count == 0:
		return

	# Chunk stress tests (indices 6-8) use terrain planes instead of boxes
	if stress_level >= 6:
		_build_chunk_stress(count)
		return

	# Use MultiMesh for efficiency at high counts
	var box = BoxMesh.new()
	box.size = Vector3(1.5, 4.0, 1.5)

	var group_count = stress_materials.size() if stress_materials.size() > 0 else 1
	var per_group = count / group_count
	var cols = ceili(sqrt(float(count)))
	var spacing = 5.0

	for g in range(group_count):
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box
		mm.instance_count = per_group

		for i in range(per_group):
			var global_i = g * per_group + i
			var col = global_i % cols
			var row = global_i / cols
			var h = 2.0 + fmod(float(global_i) * 7.3, 12.0)
			var pos = Vector3(
				-cols * spacing / 2.0 + col * spacing,
				50 + h / 2.0,
				-cols * spacing / 2.0 + row * spacing
			)
			var basis = Basis().scaled(Vector3(1.0, h / 4.0, 1.0))
			mm.set_instance_transform(i, Transform3D(basis, pos))

		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if g < stress_materials.size():
			mmi.material_override = stress_materials[g]
		stress_node.add_child(mmi)

func _build_chunk_stress(count: int):
	# Simulate terrain chunk rendering with 100x100m terrain planes
	var plane = PlaneMesh.new()
	plane.size = Vector2(100, 100)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4  # 32 tris per plane, matching LOD2-3

	var cols = ceili(sqrt(float(count)))
	var spacing = 100.0  # Tile-to-tile, no gaps

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plane
	mm.instance_count = count

	var half_extent = cols * spacing / 2.0
	for i in range(count):
		var col = i % cols
		var row = i / cols
		var pos = Vector3(
			-half_extent + col * spacing + spacing / 2.0,
			50,
			-half_extent + row * spacing + spacing / 2.0
		)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))

	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if terrain_material:
		mmi.material_override = terrain_material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stress_node.add_child(mmi)

# ------------------------------------------------------------------ #
#  HUD                                                                #
# ------------------------------------------------------------------ #
func _build_hud():
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 20
	add_child(hud)

	var label_bg = StyleBoxFlat.new()
	label_bg.bg_color = Color(0, 0, 0, 0.6)
	label_bg.set_content_margin_all(8)

	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.position = Vector2(20, 20)
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color(0, 1, 0))
	stats_label.add_theme_stylebox_override("normal", label_bg)
	hud.add_child(stats_label)

	preset_label = Label.new()
	preset_label.name = "PresetLabel"
	preset_label.position = Vector2(20, 350)
	preset_label.add_theme_font_size_override("font_size", 24)
	preset_label.add_theme_color_override("font_color", Color(1, 1, 0))
	preset_label.add_theme_stylebox_override("normal", label_bg)
	hud.add_child(preset_label)

	controls_label = Label.new()
	controls_label.name = "ControlsLabel"
	controls_label.position = Vector2(20, 620)
	controls_label.add_theme_font_size_override("font_size", 13)
	controls_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	controls_label.add_theme_stylebox_override("normal", label_bg)
	controls_label.text = "KB: Shift+L Preset | Shift+S Shadows | Shift+N Normals | Shift+M ShadowDist | Shift+A Ambient | Shift+G Stress | Shift+F Flash | Shift+T Time | Shift+B Bench | Shift+Q Log | F2 Landscape\nPS: L1 Preset | R1 Shadows | Tri Normals | Sq Stress | DPad U/D Ambient | DPad L/R ShDist | L3 Flash | R3 Time | Opt Bench | Create Log | O Landscape"
	hud.add_child(controls_label)

	# UAT test checklist — right side of screen
	var uat_label = Label.new()
	uat_label.name = "UATLabel"
	uat_label.anchor_right = 1.0
	uat_label.position = Vector2(900, 20)
	uat_label.add_theme_font_size_override("font_size", 14)
	uat_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	uat_label.add_theme_stylebox_override("normal", label_bg)
	uat_label.text = """--- UAT TEST FLOW ---
1. TEXTURE ZONES (visual check):
   Fly to each plane, confirm correct texture:
   - Grass (Y=100): green, not sand
   - Sand (Y=52): beach texture near water
   - Stone (Y=250): grey rock texture
   - Snow (Y=380): white snow texture
   - Slope: cliff/triplanar stone on face

2. LIGHTING PRESETS (Shift+L / L1):
   Cycle all 5. For each, check:
   - Shadows cast on ground? (Noon/Sunset/Dawn)
   - Night: ambient only, no sun
   - Colours change naturally?

3. SHADOWS PERF (Shift+S / R1):
   At Noon preset, toggle shadows:
   - Note FPS with shadows ON
   - Note FPS with shadows OFF
   - Delta = shadow cost on your GPU

4. SHADOW DISTANCE (Shift+M / DPad L/R):
   Cycle 100/300/500/1000/2000m:
   - Note FPS at each setting
   - Find sweet spot for quality vs perf

5. STRESS TEST (Shift+G / Square):
   Cycle through geometry levels:
   - Note FPS at each density level
   - With shadows ON vs OFF at each level

6. BENCHMARK (Shift+B / Options):
   Run auto-flythrough, then Shift+Q to save CSV.
   Check logs/ folder for results."""
	hud.add_child(uat_label)

func _update_hud():
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var prims = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var mem = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)

	var time_h = int(test_time * 24)
	var time_m = int((test_time * 24 - time_h) * 60)
	var p = PRESETS[current_preset]
	var bench_status = "IDLE"
	if benchmark_active:
		bench_status = "PASS %d/%d: %s" % [benchmark_pass_idx + 1, benchmark_passes.size(), benchmark_passes[benchmark_pass_idx]["label"]]
	stats_label.text = "FPS: %d\nFrame: %.1f ms\nObjects: %d\nPrimitives: %d\nMemory: %.0f MB\n---\nTime: %02d:%02d %s\nShadows: %s (%dm)\nNormals: %s\nAmbient: %.2f\nSun: %.2f\nFlashlight: %s\nStress: %s\n---\nCAM: %.0f, %.0f, %.0f\nBenchmark: %s" % [
		fps, frame_ms, objects, prims, mem,
		time_h, time_m, "PLAY" if time_running else "PAUSED",
		"ON" if sun_light.shadow_enabled else "OFF",
		int(sun_light.directional_shadow_max_distance),
		"ON" if normals_enabled else "OFF",
		environment.ambient_light_energy,
		sun_light.light_energy,
		"ON" if flashlight.visible else "OFF",
		stress_level_names[stress_level],
		camera.position.x, camera.position.y, camera.position.z,
		bench_status
	]

	preset_label.text = "%02d:%02d" % [time_h, time_m]

# ------------------------------------------------------------------ #
#  BENCHMARK                                                          #
# ------------------------------------------------------------------ #
func _setup_benchmark_path():
	# Waypoints that cover each test surface
	benchmark_waypoints = [
		Vector3(-50, 110, 20),  # Looking at grass plane (Y=100)
		Vector3(0, 62, 20),     # Looking at sand plane (Y=52)
		Vector3(50, 260, 20),   # Looking at stone plane (Y=250)
		Vector3(-50, 390, 20),  # Looking at snow plane (Y=380)
		Vector3(50, 110, -40),  # Looking at slope ramp (Y=100)
		Vector3(0, 55, -40),    # Looking at water (Y=48)
		Vector3(0, 80, -100),    # Looking at monoliths
		Vector3(0, 200, -5000),  # Distant — tests 10km render/fog
		Vector3(0, 110, 80),     # Back to start — looking at everything
	]
	benchmark_look_targets = [
		Vector3(-50, 100, 0),
		Vector3(0, 52, 0),
		Vector3(50, 250, 0),
		Vector3(-50, 380, 0),
		Vector3(50, 100, -60),
		Vector3(0, 48, -60),
		Vector3(0, 35, -150),
		Vector3(0, 50, -8000),
		Vector3(0, 100, -50),
	]

func _toggle_benchmark():
	benchmark_active = not benchmark_active
	if benchmark_active:
		benchmark_pass_idx = 0
		benchmark_idx = 0
		benchmark_t = 0.0
		log_data.clear()
		frame_count = 0
		log_data.append("frame,timestamp_ms,fps,frame_time_ms,cam_x,cam_y,cam_z,look_x,look_y,look_z,objects,primitives,shadow_enabled,shadow_max_dist,ambient_energy,sun_energy,normals_enabled,stress_level,pass_label")
		_apply_benchmark_pass(0)

func _apply_benchmark_pass(pass_idx: int):
	var bp = benchmark_passes[pass_idx]
	sun_light.shadow_enabled = bp["shadows"]
	sun_light.directional_shadow_max_distance = bp["shadow_dist"]
	var new_stress = bp["stress"]
	if new_stress != stress_level:
		stress_level = new_stress
		_build_stress_geometry(stress_levels[stress_level])
	print("Benchmark pass %d/%d: %s" % [pass_idx + 1, benchmark_passes.size(), bp["label"]])

func _process_benchmark(delta):
	if benchmark_idx >= benchmark_waypoints.size() - 1:
		# Advance to next pass
		benchmark_pass_idx += 1
		if benchmark_pass_idx >= benchmark_passes.size():
			benchmark_active = false
			_write_log()
			return
		_apply_benchmark_pass(benchmark_pass_idx)
		benchmark_idx = 0
		benchmark_t = 0.0
		return

	benchmark_t += delta * benchmark_speed
	if benchmark_t >= 1.0:
		benchmark_t = 0.0
		benchmark_idx += 1
		if benchmark_idx >= benchmark_waypoints.size() - 1:
			benchmark_pass_idx += 1
			if benchmark_pass_idx >= benchmark_passes.size():
				benchmark_active = false
				_write_log()
				return
			_apply_benchmark_pass(benchmark_pass_idx)
			benchmark_idx = 0
			benchmark_t = 0.0
			return

	# Interpolate camera position and look-at
	var from_pos = benchmark_waypoints[benchmark_idx]
	var to_pos = benchmark_waypoints[benchmark_idx + 1]
	camera.position = from_pos.lerp(to_pos, benchmark_t)

	var from_look = benchmark_look_targets[benchmark_idx]
	var to_look = benchmark_look_targets[benchmark_idx + 1]
	var look_target = from_look.lerp(to_look, benchmark_t)
	camera.look_at(look_target, Vector3.UP)

	# Keep sky dome centred on camera
	if sky_dome:
		sky_dome.global_position = camera.global_position

# ------------------------------------------------------------------ #
#  LOGGING                                                            #
# ------------------------------------------------------------------ #
func _log_frame():
	if not benchmark_active:
		return

	frame_count += 1
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var prims = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var look = -camera.global_transform.basis.z

	var pass_label = benchmark_passes[benchmark_pass_idx]["label"] if benchmark_pass_idx < benchmark_passes.size() else "manual"
	log_data.append("%d,%d,%.1f,%.2f,%.1f,%.1f,%.1f,%.2f,%.2f,%.2f,%d,%d,%s,%.0f,%.2f,%.2f,%s,%s,%s" % [
		frame_count,
		Time.get_ticks_msec(),
		fps, frame_ms,
		camera.position.x, camera.position.y, camera.position.z,
		look.x, look.y, look.z,
		objects, prims,
		"1" if sun_light.shadow_enabled else "0",
		sun_light.directional_shadow_max_distance,
		environment.ambient_light_energy,
		sun_light.light_energy,
		"1" if normals_enabled else "0",
		stress_level_names[stress_level],
		pass_label
	])

func _write_log():
	if log_data.is_empty():
		print("No benchmark data to write.")
		return

	# Write to repo root logs/ directory (one level above game/)
	var project_path = ProjectSettings.globalize_path("res://")
	var repo_root = project_path.trim_suffix("/").get_base_dir()
	var log_dir = repo_root + "/logs"
	if not DirAccess.dir_exists_absolute(log_dir):
		DirAccess.make_dir_absolute(log_dir)

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var log_path = log_dir + "/lighting_test_" + timestamp + ".csv"

	var file = FileAccess.open(log_path, FileAccess.WRITE)
	if file:
		for line in log_data:
			file.store_line(line)
		file.close()
		print("Benchmark CSV written: ", log_path, " (", log_data.size(), " rows)")
	else:
		push_error("Failed to write log to: " + log_path)
