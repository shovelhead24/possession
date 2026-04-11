extends Node3D
class_name DayNightCycle

@export var day_length_seconds: float = 7200.0  # Full day cycle in seconds (2 hours real time)
@export var start_time: float = 0.45  # 0.0 = midnight, 0.5 = noon — start just before noon

var time_of_day: float = 0.0
var sun_light: DirectionalLight3D
var environment: Environment
var world_env: WorldEnvironment
var sky_shader_material: ShaderMaterial
var sky_dome: MeshInstance3D = null

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
		# Search for any DirectionalLight3D in the scene
		for child in get_parent().get_children():
			if child is DirectionalLight3D:
				sun_light = child
				break

	# Only create if none found
	if not sun_light:
		sun_light = DirectionalLight3D.new()
		sun_light.shadow_enabled = true
		add_child(sun_light)
		print("DayNightCycle: Created new sun light")
	else:
		print("DayNightCycle: Using existing sun light: ", sun_light.name)

	sun_light.light_energy = 1.0
	# Exclude weapon layer (layer 2) so the day/night sun doesn't dim weapon models.
	# The dedicated WeaponLight inside the SubViewport handles weapon illumination.
	sun_light.light_cull_mask = 0xFFFFFD  # all layers except layer 2

	# Setup environment
	setup_environment()

	print("Day/Night cycle started at time: ", time_of_day)

func setup_environment():
	# Look for existing WorldEnvironment node
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

	# GL Compatibility does NOT support shader_type sky — the Sky resource always
	# renders black.  Use a sky dome instead: a large sphere rendered from the inside
	# with a shader_type spatial material, which works in every renderer.
	environment.background_mode = Environment.BG_COLOR
	environment.background_color  = Color(0.02, 0.04, 0.10)  # deep-night fallback
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color  = Color(0.5, 0.6, 0.7)
	environment.ambient_light_energy = 0.3

	var dome_shader = load("res://sky_dome_shader.gdshader")
	if not dome_shader:
		push_error("DayNightCycle: sky_dome_shader.gdshader not found!")
		return

	sky_shader_material = ShaderMaterial.new()
	sky_shader_material.shader = dome_shader

	var sphere     = SphereMesh.new()
	sphere.radius  = 2000.0
	sphere.height  = 4000.0
	sphere.radial_segments = 32
	sphere.rings   = 16

	sky_dome = MeshInstance3D.new()
	sky_dome.name = "SkyDome"
	sky_dome.mesh = sphere
	sky_dome.material_override = sky_shader_material
	sky_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_dome.gi_mode    = GeometryInstance3D.GI_MODE_DISABLED
	# Render on a layer that nothing else uses so it can't interfere
	get_parent().add_child(sky_dome)
	print("DayNightCycle: Sky dome created (GL Compat spatial shader)")

func _process(delta):
	# Update time (0.0 to 1.0 representing full day)
	time_of_day += delta / day_length_seconds
	if time_of_day >= 1.0:
		time_of_day -= 1.0

	update_sun()
	update_lighting()

	# Keep sky dome centred on the camera so it always fills the background
	if sky_dome:
		var camera = get_viewport().get_camera_3d()
		if camera and camera.is_inside_tree():
			sky_dome.global_position = camera.global_position

func update_sun():
	# Rotate sun based on time of day
	# time=0.0 (midnight): sun below horizon (rotation.x = +90 deg)
	# time=0.25 (sunrise): sun at horizon (rotation.x = 0 deg)
	# time=0.5 (noon): sun overhead pointing down (rotation.x = -90 deg)
	# time=0.75 (sunset): sun at horizon (rotation.x = -180 deg)
	var sun_angle = PI/2 - time_of_day * TAU
	sun_light.rotation.x = sun_angle

func update_lighting():
	# Get sun's actual elevation angle in degrees (-90 to 90)
	var sun_elevation = sin(time_of_day * TAU - PI/2.0) * 90

	# Check if sun is occluded by terrain
	var sun_visible = check_sun_visibility()

	var sun_intensity: float
	var sun_color: Color
	var ambient_color: Color

	# Determine lighting based on sun position AND visibility
	if sun_elevation > 30:  # High in sky - full day
		sun_intensity = 1.0
		sun_color = sun_color_day
		ambient_color = ambient_day

	elif sun_elevation > 10:  # Getting lower - late afternoon
		var t = (30 - sun_elevation) / 20
		sun_intensity = lerp(1.0, 0.3, t)
		sun_color = sun_color_day.lerp(sun_color_sunset, t)
		ambient_color = ambient_day

	elif sun_elevation > -5:  # Sunset zone (just above/below horizon)
		var t = (10 - sun_elevation) / 15

		# If sun is blocked by terrain, transition faster to night
		if not sun_visible:
			t = min(t + 0.4, 1.0)

		sun_intensity = lerp(0.3, 0.0, t)
		sun_color = sun_color_sunset.lerp(sun_color_night, t)
		ambient_color = ambient_day.lerp(ambient_night, t)

	else:  # Below horizon - night
		sun_intensity = 0.0
		sun_color = sun_color_night
		ambient_color = ambient_night

	# Apply lighting changes
	sun_light.light_energy = sun_intensity
	sun_light.light_color = sun_color

	# Hide sun when it's truly below horizon
	sun_light.visible = sun_elevation > -5

	# Update environment ambient
	if environment:
		environment.ambient_light_color  = ambient_color
		environment.ambient_light_energy = 0.3 if sun_elevation > 0 else 0.15

	# Push sun position to sky dome shader
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
	query.collision_mask = 1  # Set to your terrain's collision layer

	var result = space_state.intersect_ray(query)
	return result.is_empty()  # True if nothing blocks the sun


func get_time_string() -> String:
	var hours = int(time_of_day * 24)
	var minutes = int((time_of_day * 24 - hours) * 60)
	return "%02d:%02d" % [hours, minutes]
