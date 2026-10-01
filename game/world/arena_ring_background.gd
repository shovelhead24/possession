extends "res://world/foundation_viewer.gd"
## Reuses the actual ring geometry, DEM splice fields, satellite previews and sky.
## This presentation layer has no collision or camera/input controller.
var arena: Node3D
var background_ready := false
var previews_loaded := 0
var preview_total := 0
var loading_home := false
var home_pending := true
var arena_extent := 96.0

func _ready() -> void:
	pass

func setup(owner_arena: Node3D) -> void:
	arena = owner_arena
	_cam = arena.camera
	_env = arena.world_environment.environment
	_sun = arena.sun
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.fractal_octaves = 4
	_noise.frequency = 1.0 / 9000.0
	_load_dem()
	_load_patches()
	_mat = ShaderMaterial.new()
	var shader := Shader.new()
	var source := FileAccess.get_file_as_string("res://mocks/ring_vibes.gdshader")
	source = source.replace("uniform vec3 to_sun", "uniform float arena_extent = 96.0;\nuniform vec3 to_sun")
	source = source.replace("void fragment() {", "void fragment() {\n\tif (max(abs(v_world_pos.x), abs(v_world_pos.z)) < arena_extent) { discard; }")
	shader.code = source
	_mat.shader = shader
	_mat.set_shader_parameter("arena_extent",arena_extent)
	_mat.set_shader_parameter("patch_col_tex", _patch_col_tex)
	_mat.set_shader_parameter("patch_count", _patch_rects.size())
	_mat.set_shader_parameter("patch_rect", _patch_rects)
	_mat.set_shader_parameter("patch_own", _patch_own)
	_mat.set_shader_parameter("patch_tint", _patch_tints)
	_mat.set_shader_parameter("ring_circumference", CIRCUMFERENCES[c_idx])
	_mat.set_shader_parameter("home_patch_size", Vector2(_dem_w * _dem_mpp, _dem_h * _dem_mpp))
	_build_arena_band()
	_build_walls()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://mocks/ring_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_clouds = preload("res://mocks/ring_clouds.gd").new()
	_clouds.ring_radius = _radius()
	_clouds.ring_width = WIDTHS[w_idx]
	_clouds.wall_top = wall_top_h
	add_child(_clouds)
	for i in _patch_names.size(): _preview_queue.append(i)
	preview_total = _preview_queue.size() + 1
	background_ready = true
	_update_arena_light()
	print("ARENA_RING ready circumference=", CIRCUMFERENCES[c_idx], " width=", WIDTHS[w_idx], " patches=", _patch_names.size())

func _load_dem() -> void:
	# Only the existing coarse height mip is needed for scenery. Images resolve
	# on the existing preview worker; the full home DEM is never decoded here.
	if not FileAccess.file_exists(DEM_META): return
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEM_META))
	var mip := "res://mocks/dem/millstreet_512.r16"
	if not FileAccess.file_exists(mip): return
	_dem = FileAccess.get_file_as_bytes(mip)
	_dem_w = 512
	_dem_h = 512
	_dem_mpp = float(meta.w) * float(meta.m_per_px) / 512.0
	_dem_cam = Vector2i(roundi(float(meta.camera_px[0]) * 512.0 / float(meta.w)), roundi(float(meta.camera_px[1]) * 512.0 / float(meta.h)))
	_dem_hscale = float(meta.get("h_scale", 16.0))

func _far_terrain_h(arc: float, lat: float) -> float:
	var distance := Vector2(wrapf(arc, -CIRCUMFERENCES[c_idx]/2, CIRCUMFERENCES[c_idx]/2), lat).length()
	return lerpf(-0.25, super._far_terrain_h(arc,lat), smoothstep(arena_extent*1.7,3500.0,distance))

func _build_arena_band() -> void:
	# Add closely spaced rows around the arena so the foreground/distant ground
	# meet without the old 262 km CDLOD hole. Curvature stays at the real radius.
	var arcs: Array[float] = []
	var circumference: float = CIRCUMFERENCES[c_idx]
	for i in BAND_SEGS:
		var arc := float(i) * circumference / BAND_SEGS
		if arc > 8000 and arc < circumference-8000: arcs.append(arc)
	for arc in [-8000.0,-3500.0,-1000.0,-arena_extent*1.7,-arena_extent,0.0,arena_extent,arena_extent*1.7,1000.0,3500.0,8000.0]:
		arcs.append(fposmod(arc,circumference))
	arcs.sort()
	arcs.append(circumference)
	var lateral: Array[float] = [-25000,-22000,-19000,-16000,-13000,-10000,-8000,-3500,-1000,-arena_extent*1.7,-arena_extent,0,arena_extent,arena_extent*1.7,1000,3500,8000,10000,13000,16000,19000,22000,25000]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arc in arcs:
		for lat in lateral:
			st.set_uv(Vector2(arc,lat))
			st.add_vertex(_ring_pos(arc/_radius(),lat,_far_terrain_h(arc,lat)))
	_grid_indices(st, arcs.size()-1, lateral.size()-1)
	st.generate_normals()
	_band = MeshInstance3D.new()
	_band.mesh = st.commit()
	_band.material_override = _mat
	_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_band)

func _update_arena_light() -> void:
	var to_sun := RingFrame.sun_direction(sun_angle,sun_tilt)
	var local_up := RingFrame.up(_cam.position.x,_radius())
	_sky_mat.set_shader_parameter("to_sun",to_sun)
	_sky_mat.set_shader_parameter("local_up",local_up)
	_sky_mat.set_shader_parameter("day",1.0)
	_sky_mat.set_shader_parameter("day_zenith",Vector3(DAY_ZENITH.r,DAY_ZENITH.g,DAY_ZENITH.b))
	_sky_mat.set_shader_parameter("day_horizon",Vector3(DAY_HORIZON.r,DAY_HORIZON.g,DAY_HORIZON.b))
	_sky_mat.set_shader_parameter("star_rot",sun_angle)
	_sky_mat.set_shader_parameter("star_axis",Vector3(0,-sin(sun_tilt),cos(sun_tilt)))
	_sun.basis = Basis.looking_at(-to_sun,Vector3.UP)
	_sun.light_energy = 0.85
	_sun.light_color = Color(1.0,0.95,0.86)
	_env.ambient_light_energy = 0.4
	for material in [_mat,_wall_mat,_field_mat]:
		if material == null: continue
		material.set_shader_parameter("to_sun",to_sun)
		material.set_shader_parameter("haze_density",haze_density)
		material.set_shader_parameter("sky_color",Vector3(DAY_HORIZON.r,DAY_HORIZON.g,DAY_HORIZON.b))
	_clouds.set_day(1.0,to_sun)
	_clouds.update_around(_cam.position)

func _process(_delta: float) -> void:
	if not background_ready: return
	_update_arena_light()
	if _preview_thread != null:
		if _preview_thread.is_alive(): return
		var img: Image = _preview_thread.wait_to_finish()
		_preview_thread = null
		if img != null:
			if loading_home:
				_mat.set_shader_parameter("sat_tex",ImageTexture.create_from_image(img))
				_mat.set_shader_parameter("has_sat",true)
			else:
				_patch_col_tex.update_layer(img,_preview_index)
			previews_loaded += 1
		else: push_warning("Arena ring imagery missing for preview " + str(_preview_index))
	if home_pending:
		home_pending = false
		loading_home = true
		_preview_thread = Thread.new()
		if _preview_thread.start(_decode_preview.bind("res://mocks/dem/millstreet")) != OK: _preview_thread = null
	elif not _preview_queue.is_empty():
		loading_home = false
		_preview_index = _preview_queue.pop_front()
		_preview_thread = Thread.new()
		if _preview_thread.start(_decode_preview.bind("res://mocks/dem/"+_patch_names[_preview_index])) != OK: _preview_thread = null

func _input(_event: InputEvent) -> void:
	pass

func _unhandled_input(_event: InputEvent) -> void:
	pass
