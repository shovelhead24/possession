extends Node3D
# Lighting Test Area — self-contained benchmarking scene for iterating
# on lighting settings without the full world overhead.
#
# Keys:
#   WASD + Mouse = fly camera
#   L = cycle lighting preset (Noon/Sunset/Night/Dawn/HighSun)
#   S = toggle shadows
#   N = toggle normal maps
#   M = cycle shadow_max_distance
#   A = cycle ambient energy
#   B = start/stop benchmark flythrough
#   Q = write CSV log to logs/
#   F2 / Escape = return to world.tscn

# -- Camera --
var camera: Camera3D
var cam_speed: float = 20.0
var mouse_sens: float = 0.003
var pitch: float = 0.0
var yaw: float = 0.0

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
var shadow_distances := [100.0, 300.0, 500.0, 1000.0, 2000.0]
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

# -- Sun color LUT (matching day_night_cycle.gd) --
var sun_color_day := Color(1.0, 0.95, 0.8)
var sun_color_sunset := Color(1.0, 0.6, 0.4)
var sun_color_night := Color(0.2, 0.3, 0.5)

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_camera()
	_build_lighting()
	_build_sky_dome()
	_build_test_geometry()
	_build_hud()
	_setup_benchmark_path()
	apply_preset(current_preset)

# ------------------------------------------------------------------ #
#  CAMERA                                                             #
# ------------------------------------------------------------------ #
func _build_camera():
	camera = Camera3D.new()
	camera.name = "TestCamera"
	camera.position = Vector3(0, 60, 80)
	camera.current = true
	add_child(camera)
	pitch = -0.15

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sens
		pitch -= event.relative.y * mouse_sens
		pitch = clampf(pitch, -PI / 2.0, PI / 2.0)

func _process(delta):
	if not benchmark_active:
		_process_free_camera(delta)
	else:
		_process_benchmark(delta)
	_update_hud()
	_log_frame()

func _process_free_camera(delta):
	camera.rotation = Vector3(pitch, yaw, 0)

	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir.z -= 1
	if Input.is_key_pressed(KEY_S): dir.z += 1
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_SPACE): dir.y += 1
	if Input.is_key_pressed(KEY_SHIFT): dir.y -= 1

	var speed = cam_speed
	if Input.is_key_pressed(KEY_CTRL):
		speed *= 5.0

	if dir.length() > 0:
		dir = dir.normalized()
		var move = camera.global_transform.basis * dir * speed * delta
		camera.position += move

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
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
				sun_light.shadow_max_distance = shadow_distances[shadow_dist_idx]
			KEY_A:
				ambient_idx = (ambient_idx + 1) % ambient_levels.size()
				environment.ambient_light_energy = ambient_levels[ambient_idx]
			KEY_B:
				_toggle_benchmark()
			KEY_Q:
				_write_log()
			KEY_F2, KEY_ESCAPE:
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
	sun_light.shadow_max_distance = shadow_distances[shadow_dist_idx]
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
	environment.fog_density = 0.0002
	world_env.environment = environment
	add_child(world_env)

func apply_preset(idx: int):
	var p = PRESETS[idx]
	var time_of_day: float = p["time"]

	# Sun rotation (same formula as day_night_cycle.gd)
	var sun_angle = PI / 2.0 - time_of_day * TAU
	sun_light.rotation.x = sun_angle

	# Sun energy and color
	var sun_elevation = sin(time_of_day * TAU - PI / 2.0) * 90.0
	sun_light.light_energy = p["sun_energy"]

	if sun_elevation > 30:
		sun_light.light_color = sun_color_day
	elif sun_elevation > 10:
		var t = (30.0 - sun_elevation) / 20.0
		sun_light.light_color = sun_color_day.lerp(sun_color_sunset, t)
	elif sun_elevation > -5:
		var t = (10.0 - sun_elevation) / 15.0
		sun_light.light_color = sun_color_sunset.lerp(sun_color_night, t)
	else:
		sun_light.light_color = sun_color_night

	sun_light.shadow_enabled = p["shadow"]
	sun_light.visible = sun_elevation > -5

	# Environment
	environment.ambient_light_energy = p["ambient"]
	var fog_day = Color(0.52, 0.62, 0.78)
	var fog_night = Color(0.05, 0.06, 0.10)
	var fog_t = clampf(sun_elevation / 30.0, 0.0, 1.0)
	environment.fog_light_color = fog_day.lerp(fog_night, 1.0 - fog_t)

	# Push to sky dome
	if sky_material:
		sky_material.set_shader_parameter("sun_elevation", sun_elevation)
		var sun_azimuth = fmod(time_of_day * 360.0 + 180.0, 360.0)
		sky_material.set_shader_parameter("sun_azimuth", sun_azimuth)
		sky_material.set_shader_parameter("sun_color",
			Vector3(sun_light.light_color.r, sun_light.light_color.g, sun_light.light_color.b))

	# Push sun direction to water shader
	if water_material:
		var sun_dir = -sun_light.global_transform.basis.z
		water_material.set_shader_parameter("sun_direction",
			Vector3(sun_dir.x, sun_dir.y, sun_dir.z))

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
	sphere.radius = 2000.0
	sphere.height = 4000.0
	sphere.radial_segments = 32
	sphere.rings = 16

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

	# -- Terrain texture planes --
	# Each plane is positioned at a Y value that activates its shader zone
	_add_plane(geo, "GrassPlane",  Vector3(-50, 50, 0),   40.0, terrain_material)
	_add_plane(geo, "SandPlane",   Vector3(0, 49, 0),     40.0, terrain_material)
	_add_plane(geo, "StonePlane",  Vector3(50, 150, 0),   40.0, terrain_material)
	_add_plane(geo, "SnowPlane",   Vector3(-50, 310, 0),  40.0, terrain_material)

	# -- Slope ramp (tests cliff blending) --
	_add_slope_ramp(geo, Vector3(50, 50, -60), 40.0, 40.0, terrain_material)

	# -- Water plane --
	_build_water_plane(geo, Vector3(0, 48, -60), 60.0)

	# -- Monolith pair (same as ancient_structures.gd) --
	_add_monolith_pair(geo, Vector3(0, 0, -150))

	# -- Distance posts (shadow/LOD reference markers) --
	var post_distances = [100, 300, 500, 1000, 1500, 2000]
	for d in post_distances:
		_add_distance_post(geo, d)

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

func _add_plane(parent: Node3D, label: String, pos: Vector3, size: float, mat: Material):
	var mi = MeshInstance3D.new()
	mi.name = label
	var plane = PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	mi.mesh = plane
	if mat:
		mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

	# Add label post
	var post_label = Label3D.new()
	post_label.text = label.replace("Plane", "")
	post_label.font_size = 96
	post_label.position = pos + Vector3(0, 3, -size / 2.0 - 2)
	post_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(post_label)

func _add_slope_ramp(parent: Node3D, pos: Vector3, width: float, length: float, mat: Material):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Ramp: flat at bottom, 45 degrees rise
	var half_w = width / 2.0
	# Bottom-left, bottom-right, top-left, top-right
	var v0 = Vector3(-half_w, 0, 0)
	var v1 = Vector3(half_w, 0, 0)
	var v2 = Vector3(-half_w, length, -length)
	var v3 = Vector3(half_w, length, -length)

	st.set_normal(Vector3(0, 0.707, 0.707))
	st.set_color(Color(0.5, 0.5, 0.5, 0.0))
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v2)

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
	parent.add_child(lbl)

# ------------------------------------------------------------------ #
#  HUD                                                                #
# ------------------------------------------------------------------ #
func _build_hud():
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 20
	add_child(hud)

	stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.position = Vector2(20, 20)
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color(0, 1, 0))
	hud.add_child(stats_label)

	preset_label = Label.new()
	preset_label.name = "PresetLabel"
	preset_label.position = Vector2(20, 350)
	preset_label.add_theme_font_size_override("font_size", 24)
	preset_label.add_theme_color_override("font_color", Color(1, 1, 0))
	hud.add_child(preset_label)

	controls_label = Label.new()
	controls_label.name = "ControlsLabel"
	controls_label.position = Vector2(20, 600)
	controls_label.add_theme_font_size_override("font_size", 14)
	controls_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	controls_label.text = "[L] Preset  [S] Shadows  [N] Normals  [M] Shadow Dist  [A] Ambient  [B] Benchmark  [Q] Log  [Esc] Exit"
	hud.add_child(controls_label)

func _update_hud():
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var prims = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var mem = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)

	var p = PRESETS[current_preset]
	stats_label.text = "FPS: %d\nFrame: %.1f ms\nObjects: %d\nPrimitives: %d\nMemory: %.0f MB\n---\nPRESET: %s\nShadows: %s (%dm)\nNormals: %s\nAmbient: %.2f\nSun: %.2f\n---\nCAM: %.0f, %.0f, %.0f\nBenchmark: %s" % [
		fps, frame_ms, objects, prims, mem,
		p["name"],
		"ON" if sun_light.shadow_enabled else "OFF",
		int(sun_light.shadow_max_distance),
		"ON" if normals_enabled else "OFF",
		environment.ambient_light_energy,
		sun_light.light_energy,
		camera.position.x, camera.position.y, camera.position.z,
		"RUNNING" if benchmark_active else "IDLE"
	]

	preset_label.text = p["name"]

# ------------------------------------------------------------------ #
#  BENCHMARK                                                          #
# ------------------------------------------------------------------ #
func _setup_benchmark_path():
	# Waypoints that cover each test surface
	benchmark_waypoints = [
		Vector3(-50, 60, 20),   # Looking at grass plane
		Vector3(0, 58, 20),     # Looking at sand plane
		Vector3(50, 160, 20),   # Looking at stone plane
		Vector3(-50, 320, 20),  # Looking at snow plane
		Vector3(50, 60, -40),   # Looking at slope ramp
		Vector3(0, 55, -40),    # Looking at water
		Vector3(0, 80, -100),   # Looking at monoliths
		Vector3(0, 60, 80),     # Back to start — looking at everything
	]
	benchmark_look_targets = [
		Vector3(-50, 50, 0),
		Vector3(0, 49, 0),
		Vector3(50, 150, 0),
		Vector3(-50, 310, 0),
		Vector3(50, 50, -60),
		Vector3(0, 48, -60),
		Vector3(0, 30, -150),
		Vector3(0, 50, -50),
	]

func _toggle_benchmark():
	benchmark_active = not benchmark_active
	if benchmark_active:
		benchmark_idx = 0
		benchmark_t = 0.0
		log_data.clear()
		frame_count = 0
		# Add CSV header
		log_data.append("frame,timestamp_ms,fps,frame_time_ms,cam_x,cam_y,cam_z,look_x,look_y,look_z,objects,primitives,shadow_enabled,shadow_max_dist,ambient_energy,sun_energy,preset_name,normals_enabled")

func _process_benchmark(delta):
	if benchmark_idx >= benchmark_waypoints.size() - 1:
		benchmark_active = false
		_write_log()
		return

	benchmark_t += delta * benchmark_speed
	if benchmark_t >= 1.0:
		benchmark_t = 0.0
		benchmark_idx += 1
		if benchmark_idx >= benchmark_waypoints.size() - 1:
			benchmark_active = false
			_write_log()
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
	var p = PRESETS[current_preset]

	log_data.append("%d,%d,%.1f,%.2f,%.1f,%.1f,%.1f,%.2f,%.2f,%.2f,%d,%d,%s,%.0f,%.2f,%.2f,%s,%s" % [
		frame_count,
		Time.get_ticks_msec(),
		fps, frame_ms,
		camera.position.x, camera.position.y, camera.position.z,
		look.x, look.y, look.z,
		objects, prims,
		"1" if sun_light.shadow_enabled else "0",
		sun_light.shadow_max_distance,
		environment.ambient_light_energy,
		sun_light.light_energy,
		p["name"],
		"1" if normals_enabled else "0"
	])

func _write_log():
	if log_data.is_empty():
		print("No benchmark data to write.")
		return

	# Write to repo logs/ directory
	var project_path = ProjectSettings.globalize_path("res://")
	var repo_root = project_path.get_base_dir()  # Go up from game/ to repo root
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
