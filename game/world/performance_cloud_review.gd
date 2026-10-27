extends Node
## Opt-in session experiments; defaults reproduce the existing sky.
const MODES=["Existing sky", "Wind drift + soft wrapping", "Wind + evolving shapes", "Wind + evolution / 75% cards"]
var landscape_water: ShaderMaterial
var moon_fill: OmniLight3D
var moonlight: DirectionalLight3D
var planet_texture: Texture2D
var defaults_started=false
var arena: Node3D
var cached: Node3D
var upper: ShaderMaterial
var day_cycle: Node
var dialog: AcceptDialog
var mode_picker: OptionButton
var mode := 0
var cloud_time := 0.0
var speed := 1.0
var playing := true
var tint := Color.WHITE
var experimental_shaders := true
var backdrop_surfaces: Array=[]
var weather: Node
var rain: Node3D
var light_shafts: Node3D
var valley_mist: MeshInstance3D
var water: MeshInstance3D
var weather_profile: Dictionary={}
var weather_restore: Dictionary={}
var tabs: TabContainer
var viewpoints: Node
func setup(owner_arena: Node3D):
	arena=owner_arena;process_priority=104
	var planet_source=Image.load_from_file("res://world/materials/sky_blue_planet.png")
	planet_source.generate_mipmaps()
	planet_texture=ImageTexture.create_from_image(planet_source)
	moonlight=DirectionalLight3D.new();moonlight.name="PlanetMoonlight"
	moonlight.light_color=Color(.52,.66,1.0);moonlight.light_energy=0
	moonlight.shadow_enabled=false;arena.add_child(moonlight)
	moon_fill=OmniLight3D.new();moon_fill.name="NearbyMoonFill"
	moon_fill.light_color=Color(.55,.65,.85);moon_fill.omni_range=28
	moon_fill.omni_attenuation=1.2;moon_fill.light_energy=0;moon_fill.light_specular=0
	moon_fill.shadow_enabled=false;arena.add_child(moon_fill)
	landscape_water=load("res://assets/showcases/water.res")
	cached=arena.sky_comparison.legacy.cached
	for mat in cached.materials:mat.shader=preload("res://world/performance_cloud_cards.gdshader")
	upper=arena.sky_comparison.high_painterly.material_override
	upper.shader=preload("res://world/performance_cloud_upper.gdshader")
	arena.sky_comparison.painted_material.shader=preload("res://world/performance_cycle_sky.gdshader")
	for key in ["_wall_mat","_field_mat"]:
		var surface: ShaderMaterial=arena.backdrop.get(key)
		if not surface:continue
		var shader=Shader.new()
		shader.code=surface.shader.code.replace("uniform vec3 to_sun","uniform vec3 cycle_surface_tint=vec3(1.0);\nuniform vec3 to_sun").replace("mix(lit, sky_color, fog)","mix(lit*cycle_surface_tint, sky_color, fog)")
		surface.shader=shader;backdrop_surfaces.append(surface)
	# Patch only the review materials, preserving older scenes and their defaults.
	for key in ["_mat","_wall_mat"]:
		var surface: ShaderMaterial=arena.backdrop.get(key)
		var shader=Shader.new()
		var source: String=surface.shader.code
		source=source.replace("shader_type spatial;", "shader_type spatial;\n#include \"res://world/performance_ring_light.gdshaderinc\"")
		if key=="_mat":
			source=source.replace("vec3 col = mix(lit, sky_color, fog);", "vec3 col = mix(lit, sky_color, fog);\nif(ring_cycle_enabled) col=ring_surface_light(albedo,n,v_world_pos,fog,sky_color,dist);")
		else:
			source=source.replace("ALBEDO = mix(lit*cycle_surface_tint, sky_color, fog);", "ALBEDO = mix(lit*cycle_surface_tint, sky_color, fog);\nif(ring_cycle_enabled) ALBEDO=ring_surface_light(wall_color*(0.94+0.06*band),n,v_world_pos,fog,sky_color,dist);")
		shader.code=source;surface.shader=shader
	dialog=AcceptDialog.new();dialog.title="Clouds, weather and daylight review";dialog.min_size=Vector2i(660,530);arena.add_child(dialog)
	dialog.add_to_group("controller_modal_ui")
	dialog.visibility_changed.connect(func():
		if dialog.visible:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	)
	tabs=TabContainer.new();dialog.add_child(tabs)
	var column=VBoxContainer.new();column.name="Clouds";tabs.add_child(column)
	var weather_column=VBoxContainer.new();weather_column.name="Weather";tabs.add_child(weather_column)
	var day_column=VBoxContainer.new();day_column.name="Daylight";tabs.add_child(day_column)
	var water_column=VBoxContainer.new();water_column.name="Water";tabs.add_child(water_column)
	water=preload("res://world/performance_water.gd").new();arena.add_child(water);water.setup(arena,water_column)
	var launch=Button.new();launch.text="Clouds, weather + sunrise / sunset review..."
	arena.sky_comparison.dialog.get_child(0).add_child(launch)
	launch.pressed.connect(open_review)
	mode_picker=OptionButton.new();column.add_child(mode_picker)
	for label in MODES:mode_picker.add_item(label)
	mode_picker.item_selected.connect(set_mode)
	var play=CheckBox.new();play.text="Animate cloud experiments";play.button_pressed=true;column.add_child(play)
	play.toggled.connect(func(value):playing=value)
	var row=HBoxContainer.new();column.add_child(row)
	var label=Label.new();label.text="Cloud preview speed (1 = gentle wind)";row.add_child(label)
	var rate=SpinBox.new();rate.min_value=0;rate.max_value=120;rate.step=1;rate.value=1;row.add_child(rate)
	rate.value_changed.connect(func(value):speed=value)
	var note=Label.new();note.text="Try 60x to inspect motion and wrapping. 75% cards tests less overlap.\nReview the Billboards + high painterly layer sky preset.\nExisting sky keeps its upper-layer drift. Settings reset on restart."
	column.add_child(note)
	day_cycle=preload("res://world/performance_day_cycle.gd").new();add_child(day_cycle)
	day_cycle.lighting_changed.connect(set_lighting)
	day_cycle.setup(arena,day_column)
	rain=preload("res://world/performance_rain.gd").new();arena.add_child(rain);rain.setup(arena)
	light_shafts=preload("res://world/performance_light_shafts.gd").new();arena.add_child(light_shafts);light_shafts.setup(arena)
	valley_mist=preload("res://world/performance_valley_mist.gd").new();arena.camera.add_child(valley_mist);valley_mist.setup(arena)
	var rays=CheckBox.new();rays.text="Cheap sun shafts (experimental)";weather_column.add_child(rays)
	rays.toggled.connect(func(value):light_shafts.enabled=value)
	weather=preload("res://world/performance_weather.gd").new();add_child(weather);weather.setup(arena,weather_column)
	weather_profile=weather.current_profile();weather.weather_changed.connect(set_weather)
	var weather_note=Label.new();weather_note.text="Use Billboards + high painterly layer. Rain stays near the camera.\nSun shafts fade behind solid occluders; this is an art approximation."
	weather_column.add_child(weather_note)
	set_mode(0)
	var view_column=VBoxContainer.new();view_column.name="Viewpoints";tabs.add_child(view_column)
	viewpoints=preload("res://world/performance_viewpoints.gd").new();add_child(viewpoints);viewpoints.setup(arena,self,view_column)
func open_review():
	arena.sky_comparison.dialog.hide()
	dialog.popup_centered()
func set_mode(value: int):
	mode=clampi(value,0,MODES.size()-1);mode_picker.select(mode)
	select_shaders()
	cached.gpu_orientation=mode>0;cached.settle=2.0
	cached.animation_bounds_margin=2300.0 if mode>0 else 0.0
	for record in cached.chunks.values():record.node.extra_cull_margin=cached.animation_bounds_margin
	for mat in cached.materials:
		mat.set_shader_parameter("drift_enabled",mode>0)
		mat.set_shader_parameter("evolution_enabled",mode>1)
		mat.set_shader_parameter("card_fraction",0.75 if mode==3 else 1.0)
	upper.set_shader_parameter("drift_enabled",mode>0)
	upper.set_shader_parameter("evolution_enabled",mode>1)
	apply_weather_uniforms()
	update_time()
func set_lighting(sky_color: Color, cloud_color: Color):
	select_shaders()
	tint=cloud_color
	for mat in cached.materials:mat.set_shader_parameter("cloud_tint",Vector3(tint.r,tint.g,tint.b))
	upper.set_shader_parameter("cloud_tint",Vector3(tint.r,tint.g,tint.b))
	for surface in backdrop_surfaces:surface.set_shader_parameter("cycle_surface_tint",Vector3(tint.r,tint.g,tint.b))
	var material=arena.sky_comparison.painted_material
	material.set_shader_parameter("local_up",preload("res://world/terrain_drive_ring.gd").up_at(arena.camera.global_position))
	material.set_shader_parameter("sky_tint",Vector3(sky_color.r,sky_color.g,sky_color.b))
	material.set_shader_parameter("sun_direction",arena.daylight.sun.global_basis.z)
	material.set_shader_parameter("cycle_enabled",day_cycle.enabled)
	arena.daylight.environment.sky=arena.sky_comparison.painted_sky if day_cycle.enabled or arena.sky_comparison.painted else arena.sky_comparison.original_sky
	apply_weather_lighting()
func select_shaders():
	var use_experiments: bool=mode>0 or (day_cycle!=null and day_cycle.enabled) or (not weather_profile.is_empty() and not weather_profile.is_original)
	if use_experiments==experimental_shaders:return
	experimental_shaders=use_experiments
	for mat in cached.materials:
		mat.shader=preload("res://world/performance_cloud_cards.gdshader") if use_experiments else preload("res://world/sky_cached_billboard.gdshader")
	upper.shader=preload("res://world/performance_cloud_upper.gdshader") if use_experiments else preload("res://world/sky_high_painterly.gdshader")
	arena.sky_comparison.painted_material.shader=preload("res://world/performance_cycle_sky.gdshader") if use_experiments else preload("res://world/sky_painterly_background.gdshader")
func update_time():
	for mat in cached.materials:mat.set_shader_parameter("cloud_time",cloud_time)
	upper.set_shader_parameter("cloud_time",cloud_time)
func _process(delta: float):
	if not defaults_started and arena.ready_to_play and arena.loading.dismissed:
		defaults_started=true
		set_mode(2)
		day_cycle.hours_per_second=0.02
		day_cycle.set_enabled(true);day_cycle.animate=true;day_cycle.sync_controls()
		weather.set_cycling(true)
	if day_cycle.enabled:
		arena.sky_comparison.painted_material.set_shader_parameter("sun_direction",arena.daylight.sun.global_basis.z)
	apply_weather_lighting()
	update_ring_lighting()
	if mode==0:return
	if playing:cloud_time+=delta*speed*(lerpf(.4,2.0,float(weather_profile.wind)) if not weather_profile.is_original else 1.0)
	update_time()

func set_weather(profile: Dictionary):
	var env: Environment=arena.daylight.environment
	if not profile.is_original and weather_restore.is_empty():
		weather_restore={"horizon":arena.backdrop.horizon_color,"sun_energy":arena.daylight.sun.light_energy,"ambient_energy":env.ambient_light_energy,"haze":arena.sky_comparison.weather_haze_density}
		for key in ["fog_enabled","fog_density","fog_light_color","fog_sky_affect"]:weather_restore[key]=env.get(key)
		weather_restore.sun=arena.backdrop._mat.get_shader_parameter("daylight_sun")
		weather_restore.ambient=arena.backdrop._mat.get_shader_parameter("daylight_ambient")
		# Both previews restore the lighting from before either preview began.
		if day_cycle.enabled and not day_cycle.baseline_state.is_empty():
			var original: Dictionary=day_cycle.baseline_state
			weather_restore.horizon=original.backdrop_horizon
			weather_restore.sun_energy=original.sun_energy
			weather_restore.ambient_energy=original.ambient_energy
			weather_restore.sun=original.backdrop_sun
			weather_restore.ambient=original.backdrop_ambient
	weather_profile=profile;select_shaders();apply_weather_uniforms()
	rain.configure(float(profile.rain),float(profile.wind))
	valley_mist.visible=float(profile.get("mist_density",0.0))>0
	valley_mist.material.set_shader_parameter("density",float(profile.get("mist_density",0.0))*4.0)
	if profile.is_original:
		if not weather_restore.is_empty():
			for key in ["fog_enabled","fog_density","fog_light_color","fog_sky_affect"]:env.set(key,weather_restore[key])
			arena.sky_comparison.weather_haze_density=weather_restore.haze
			arena.backdrop.horizon_color=weather_restore.horizon
			for key in day_cycle.backdrop_materials():arena.backdrop.get(key).set_shader_parameter("sky_color",weather_restore.horizon)
			arena.sky_comparison.apply_atmosphere()
			arena.daylight.sun.light_energy=weather_restore.sun_energy;env.ambient_light_energy=weather_restore.ambient_energy
			arena.backdrop._mat.set_shader_parameter("daylight_sun",weather_restore.sun)
			arena.backdrop._mat.set_shader_parameter("daylight_ambient",weather_restore.ambient)
			weather_restore.clear()
			if day_cycle.enabled:day_cycle.apply_time()
		return
	env.fog_enabled=profile.fog_density>0;env.fog_density=profile.fog_density
	env.fog_sky_affect=1.0-exp(-float(profile.fog_density)*1000.0)
	arena.sky_comparison.weather_haze_density=profile.fog_density
	if profile.name=="Mist" and not weather.cycling:
		env.fog_enabled=false;env.fog_sky_affect=0.0
		arena.sky_comparison.weather_haze_density=0.0
		arena.sky_comparison.apply_atmosphere()
	apply_weather_lighting()
func apply_weather_uniforms():
	if weather_profile.is_empty():return
	for mat in cached.materials:
		mat.set_shader_parameter("card_fraction",float(weather_profile.cloud_fraction)*(0.75 if mode==3 else 1.0))
		mat.set_shader_parameter("weather_darkness",weather_profile.cloud_darkness)
	upper.set_shader_parameter("weather_darkness",weather_profile.cloud_darkness)
	upper.set_shader_parameter("weather_opacity",weather_profile.upper_opacity)
	upper.set_shader_parameter("weather_fill",weather_profile.upper_fill)
	arena.sky_comparison.painted_material.set_shader_parameter("weather_overcast",weather_profile.upper_fill)
func apply_weather_lighting():
	if weather_profile.is_empty() or weather_profile.is_original:return
	var d=arena.daylight;var p=weather_profile
	var sky_color: Color=day_cycle.sky_tint if day_cycle.enabled else Color.WHITE
	var base_horizon: Vector3=Vector3(.62*sky_color.r,.74*sky_color.g,.86*sky_color.b) if day_cycle.enabled else weather_restore.horizon
	var fog_color=base_horizon.lerp(Vector3(.42*sky_color.r,.48*sky_color.g,.52*sky_color.b),float(p.upper_fill))
	arena.backdrop.horizon_color=fog_color
	for key in day_cycle.backdrop_materials():arena.backdrop.get(key).set_shader_parameter("sky_color",fog_color)
	d.environment.fog_light_color=Color(fog_color.x,fog_color.y,fog_color.z)
	d.sun.light_energy=d.energy*float(p.sun_gain);d.environment.ambient_light_energy=d.ambient*float(p.ambient_gain)
	var color: Color=d.sun.light_color
	arena.backdrop._mat.set_shader_parameter("daylight_sun",Vector3(color.r,color.g,color.b)*d.sun.light_energy/maxf(.001,d.original_energy))
	color=d.environment.ambient_light_color
	arena.backdrop._mat.set_shader_parameter("daylight_ambient",Vector3(color.r,color.g,color.b)*d.environment.ambient_light_energy/maxf(.001,d.original_ambient_energy))
	rain.material.set_shader_parameter("rain_tint",Vector3(sky_color.r,sky_color.g,sky_color.b))
	valley_mist.material.set_shader_parameter("mist_color",Vector3(.86*sky_color.r,.89*sky_color.g,.91*sky_color.b))

func update_ring_lighting() -> void:
	var Ring=preload("res://world/terrain_drive_ring.gd")
	var direction: Vector3=arena.daylight.sun.global_basis.z
	var up: Vector3=Ring.up_at(arena.camera.global_position)
	var day: float=smoothstep(-0.12,0.30,up.dot(direction)) if day_cycle.enabled else 1.0
	var phase: float=(day_cycle.hour-12.0)*TAU/24.0 if day_cycle.enabled else 0.0
	var axis=Vector3(0,-sin(day_cycle.SUN_TILT),cos(day_cycle.SUN_TILT))
	var planet=Vector3(.65,-.7,.3).normalized().rotated(axis,-phase)
	moonlight.global_basis=Basis.looking_at(-planet,Vector3.UP)
	moonlight.light_energy=.14*(1.0-day)*smoothstep(-.05,.20,up.dot(planet))*(1.0-float(weather_profile.get("upper_fill",0.0))*.85)
	moon_fill.global_position=arena.camera.global_position+up*3.0
	moon_fill.light_energy=moonlight.light_energy*1.9
	for water_surface in [water.material,landscape_water]:
		water_surface.set_shader_parameter("moon_direction",planet)
		water_surface.set_shader_parameter("moon_color",Vector3(.52,.66,1.0)*moonlight.light_energy)
	var sun_colour: Color=arena.daylight.sun.light_color
	landscape_water.set_shader_parameter("sun_direction",direction)
	landscape_water.set_shader_parameter("sun_color",Vector3(sun_colour.r,sun_colour.g,sun_colour.b)*arena.daylight.sun.light_energy)
	var water_tint: Color=day_cycle.sky_tint if day_cycle.enabled else Color.WHITE
	landscape_water.set_shader_parameter("light_tint",Vector3(water_tint.r,water_tint.g,water_tint.b))
	for surface in [arena.backdrop._mat,arena.backdrop._wall_mat]:
		surface.set_shader_parameter("cycle_moon",planet)
		surface.set_shader_parameter("cycle_moon_gain",.10*(1.0-float(weather_profile.get("upper_fill",0.0))*.85))
	arena.sky_comparison.painted_material.set_shader_parameter("planet_image",planet_texture)
	arena.sky_comparison.painted_material.set_shader_parameter("planet_direction",planet)
	for sky in [arena.sky_comparison.painted_material,arena.sky_comparison.original_sky.sky_material]:
		sky.set_shader_parameter("local_up",up)
		sky.set_shader_parameter("day",day)
		sky.set_shader_parameter("star_rot",(day_cycle.hour-12.0)*TAU/24.0 if day_cycle.enabled else 0.0)
		sky.set_shader_parameter("star_axis",Vector3(0,-sin(day_cycle.SUN_TILT),cos(day_cycle.SUN_TILT)))
	var materials: Array=[arena.backdrop._mat,arena.backdrop._wall_mat,upper]
	materials.append_array(cached.materials)
	for material in materials:
		material.set_shader_parameter("ring_cycle_enabled",day_cycle.enabled)
		if not day_cycle.enabled:continue
		material.set_shader_parameter("cycle_sun",direction)
		material.set_shader_parameter("cycle_origin",Ring.offset())
		material.set_shader_parameter("cycle_radius",Ring.Frame.CIRCUMFERENCE/TAU)
		material.set_shader_parameter("cycle_sun_gain",float(weather_profile.get("sun_gain",1.0)))
		material.set_shader_parameter("cycle_ambient_gain",float(weather_profile.get("ambient_gain",1.0)))
