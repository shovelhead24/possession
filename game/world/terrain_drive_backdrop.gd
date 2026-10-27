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
const NEAR_EXTENT := 8000.0
const NEAR_STEP := 128.0
var near_band: MeshInstance3D
var ownership_texture: ImageTexture
var ownership_keys: Array=[]
var ownership_origin := Vector2i(-256,-256)
## Shared by the per-frame backdrop update and optional time-of-day preview.
var horizon_color := Vector3(DAY_HORIZON.r,DAY_HORIZON.g,DAY_HORIZON.b)


func update_ownership() -> void:
	var keys: Array=arena.tile_entries.keys()
	# Dictionary insertion order stays stable until publication/eviction.
	if keys==ownership_keys: return
	ownership_keys=keys
	var image := Image.create(512,512,false,Image.FORMAT_R8)
	image.fill(Color.BLACK)
	for key in keys:
		var pixel: Vector2i=key-ownership_origin
		if pixel.x>=0 and pixel.y>=0 and pixel.x<512 and pixel.y<512:
			image.set_pixelv(pixel,Color.WHITE)
	if ownership_texture: ownership_texture.update(image)
	else: ownership_texture=ImageTexture.create_from_image(image)
	_mat.set_shader_parameter("ownership",ownership_texture)
	_mat.set_shader_parameter("ownership_origin",Vector2(ownership_origin))

func canonical_arc(arc: float) -> float:
	return wrapf(arc,-CIRCUMFERENCES[c_idx]*.5,CIRCUMFERENCES[c_idx]*.5)

func _ready() -> void:
	pass

func setup(owner_arena: Node3D) -> void:
	arena = owner_arena
	process_priority=100
	# Published 200 m tiles own the foreground; no fixed workshop opening.
	arena_extent=0.0
	var metadata: Dictionary=arena.source.metadata
	var spacing: float=metadata.m_per_px
	ownership_origin=Vector2i(floori(-float(metadata.camera_px[0])*spacing/200.0),floori(-(float(metadata.h)-2-float(metadata.camera_px[1]))*spacing/200.0))
	_cam = arena.camera
	for child in arena.get_children():
		if child is WorldEnvironment: _env=child.environment
		if child is DirectionalLight3D: _sun=child

	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.fractal_octaves = 4
	_noise.frequency = 1.0 / 9000.0
	_load_dem()
	_load_patches()
	_mat = ShaderMaterial.new()
	var shader := Shader.new()
	var source := FileAccess.get_file_as_string("res://mocks/ring_vibes.gdshader")
	source=source.replace("sat_tex : source_color, filter_linear;", "sat_tex : source_color, filter_linear_mipmap_anisotropic;")
	source = source.replace("uniform vec3 to_sun", "uniform float arena_extent = 96.0;\nuniform vec3 to_sun")
	# Use ring coordinates, not world X: the antipodal ring also has X near zero.
	source = source.replace("void fragment() {", "void fragment() {\n\tfloat local_arc = UV.x - ring_circumference * floor(UV.x / ring_circumference + 0.5);\n\tif (max(abs(local_arc), abs(UV.y)) < arena_extent) { discard; }")
	source = source.replace("UV.x / home_patch_size.x", "local_arc / home_patch_size.x")
	if true:
		source=source.replace("max(abs(local_arc), abs(UV.y)) < arena_extent", "abs(local_arc) < 8000.0 && max(abs(v_world_pos.x), abs(v_world_pos.z)) < arena_extent")
		source=source.replace("uniform vec3 to_sun", "uniform vec2 home_origin;\nuniform vec3 to_sun")
		source=source.replace("vec2(local_arc / home_patch_size.x, -UV.y / home_patch_size.y)", "home_origin + vec2(local_arc / home_patch_size.x, -UV.y / home_patch_size.y)")
	source=source.replace("uniform vec3 to_sun", "uniform sampler2D ownership : filter_nearest, repeat_disable;\nuniform vec2 ownership_origin = vec2(-256.0);\nuniform vec3 to_sun")
	source=source.replace("void fragment() {", "void fragment() {\n vec2 owner_uv=(vec2(UV.x-ring_circumference*floor(UV.x/ring_circumference+0.5),UV.y)/200.0+-ownership_origin)/512.0;\n if(all(greaterThanEqual(owner_uv,vec2(0.0))) && all(lessThan(owner_uv,vec2(1.0))) && texture(ownership,owner_uv).r>0.5) discard;")
	shader.code = source
	_mat.shader = shader
	if arena.source:
		var meta: Dictionary=arena.source.metadata
		_mat.set_shader_parameter("home_origin",Vector2(meta.camera_px[0],meta.camera_px[1])/Vector2(meta.w,meta.h))
	_mat.set_shader_parameter("arena_extent",arena_extent)
	_mat.set_shader_parameter("patch_col_tex", _patch_col_tex)
	_mat.set_shader_parameter("patch_count", _patch_rects.size())
	_mat.set_shader_parameter("patch_rect", _patch_rects)
	_mat.set_shader_parameter("patch_own", _patch_own)
	_mat.set_shader_parameter("patch_tint", _patch_tints)
	_mat.set_shader_parameter("ring_circumference", CIRCUMFERENCES[c_idx])
	_mat.set_shader_parameter("home_patch_size", Vector2(_dem_w * _dem_mpp, _dem_h * _dem_mpp))
	_build_arena_band()
	update_ownership()
	_cam.far=1200000.0
	_build_walls()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://mocks/ring_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	for i in _patch_names.size(): _preview_queue.append(i)
	preview_total = _preview_queue.size() + 1
	if arena.satellite_texture:
		# Share the full-resolution home image with the driving surface.
		_mat.set_shader_parameter("sat_tex",arena.satellite_texture)
		_mat.set_shader_parameter("has_sat",true)
		home_pending=false;previews_loaded=1
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
	# Patch lookups already wrap, but home DEM and procedural fallback did not.
	# Canonicalise BEFORE every source lookup, not just the fade-distance test.
	arc=canonical_arc(arc)
	if is_instance_valid(arena) and arena.source and maxf(absf(arc),absf(lat))<=NEAR_EXTENT:
		# Close streamed tiles and background scenery share the same ring-space
		# altitude. Do not flatten this local tier before _ring_pos bends it.
		return arena.source.surface_height(Vector2(arc,lat),128.0)
	var distance := maxf(absf(arc),absf(lat))
	return lerpf(-0.25, super._far_terrain_h(arc,lat), smoothstep(arena_extent*1.7,maxf(3500,arena_extent*3),distance))

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
	arcs=sorted_unique(arcs)
	arcs.append(circumference)
	var lateral: Array[float] = [-25000,-22000,-19000,-16000,-13000,-10000,-8000,-3500,-1000,-arena_extent*1.7,-arena_extent,0,arena_extent,arena_extent*1.7,1000,3500,8000,10000,13000,16000,19000,22000,25000]
	lateral=sorted_unique(lateral)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arc in arcs:
		for lat in lateral:
			st.set_uv(Vector2(arc,lat))
			st.add_vertex(_ring_pos(arc/_radius(),lat,_far_terrain_h(arc,lat)))
	# The near square is built separately at DEM-appropriate resolution. Do not
	# multiply that lateral resolution around the entire 3,000 km circumference.
	for i in arcs.size()-1:
		var middle := canonical_arc((arcs[i]+arcs[i+1])*.5)
		for j in lateral.size()-1:
			if absf(middle)<NEAR_EXTENT and absf((lateral[j]+lateral[j+1])*.5)<NEAR_EXTENT: continue
			var a := i*lateral.size()+j;var b := a+lateral.size()
			for index in [a,b,a+1,a+1,b,b+1]: st.add_index(index)
	st.generate_normals()
	_band = MeshInstance3D.new()
	_band.mesh = st.commit()
	_band.material_override = _mat
	_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_band)
	_build_near_band(arcs,lateral)

static func sorted_unique(values: Array[float]) -> Array[float]:
	values.sort();var result: Array[float]=[]
	for value in values:
		if result.is_empty() or absf(result[-1]-value)>.001: result.append(value)
	return result

func boundary_vertex(arc: float, lat: float, samples: Array[float], along_arc: bool) -> Vector3:
	var coordinate := arc if along_arc else lat
	for i in samples.size()-1:
		if coordinate>=samples[i] and coordinate<=samples[i+1]:
			var a := Vector2(samples[i],lat) if along_arc else Vector2(arc,samples[i])
			var b := Vector2(samples[i+1],lat) if along_arc else Vector2(arc,samples[i+1])
			var pa := _ring_pos(a.x/_radius(),a.y,_far_terrain_h(a.x,a.y))
			var pb := _ring_pos(b.x/_radius(),b.y,_far_terrain_h(b.x,b.y))
			return pa.lerp(pb,(coordinate-samples[i])/(samples[i+1]-samples[i]))
	return _ring_pos(arc/_radius(),lat,_far_terrain_h(arc,lat))

static func aligned_edge_height(source: RefCounted, point: Vector2, along_z: bool) -> float:
	var coordinate := point.y if along_z else point.x
	var lo := floorf(coordinate/128.0)*128.0
	var a := Vector2(point.x,lo) if along_z else Vector2(lo,point.y)
	var b := a+(Vector2(0,128) if along_z else Vector2(128,0))
	return lerpf(source.surface_height(a,128),source.surface_height(b,128),(coordinate-lo)/128.0)

func _build_near_band(arcs: Array[float], lateral: Array[float]) -> void:
	var coarse_arcs: Array[float]=[]
	for arc in arcs:
		var local := canonical_arc(arc)
		if absf(local)<=NEAR_EXTENT: coarse_arcs.append(local)
	coarse_arcs=sorted_unique(coarse_arcs)
	var xs: Array[float]=coarse_arcs.duplicate();var zs: Array[float]=[]
	for lat in lateral:
		if absf(lat)<=NEAR_EXTENT: zs.append(lat)
	var grid_start := ceili(-NEAR_EXTENT/NEAR_STEP)*int(NEAR_STEP) if arena.source else -int(NEAR_EXTENT)
	for coordinate in range(grid_start,int(NEAR_EXTENT),int(NEAR_STEP)):
		xs.append(float(coordinate));zs.append(float(coordinate))
	xs.append(NEAR_EXTENT);zs.append(NEAR_EXTENT)
	xs=sorted_unique(xs);zs=sorted_unique(zs)
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arc in xs:
		for lat in zs:
			var point := _ring_pos(arc/_radius(),lat,_far_terrain_h(arc,lat))
			if arena.source:
				point=_ring_pos(arc/_radius(),lat,arena.source.surface_height(Vector2(arc,lat),128.0))
			# Fine boundary vertices lie on the actual coarse edge segments, not
			# on a different sampled curve: no stitching job or hidden cracks.
			if absf(arc)==NEAR_EXTENT: point=boundary_vertex(arc,lat,lateral,false)
			elif absf(lat)==NEAR_EXTENT: point=boundary_vertex(arc,lat,coarse_arcs,true)
			st.set_uv(Vector2(arc,lat));st.add_vertex(point)
	for i in xs.size()-1:
		for j in zs.size()-1:
			if maxf(absf((xs[i]+xs[i+1])*.5),absf((zs[j]+zs[j+1])*.5))<arena_extent: continue
			var a := i*zs.size()+j;var b := a+zs.size()
			for index in [a,b,a+1,a+1,b,b+1]: st.add_index(index)
	st.generate_normals()
	near_band=MeshInstance3D.new();near_band.mesh=st.commit();near_band.material_override=_mat
	near_band.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(near_band)
	print("ARENA_BACKDROP extent=",arena_extent," near_vertices=",xs.size()*zs.size()," step=",NEAR_STEP)

func _update_arena_light() -> void:
	# Preserve the accepted foreground light and ambient settings in this stage.
	var to_sun := _sun.global_basis.z
	_sky_mat.set_shader_parameter("to_sun",to_sun)
	_sky_mat.set_shader_parameter("local_up",Vector3.UP)
	_sky_mat.set_shader_parameter("day",1.0)
	_sky_mat.set_shader_parameter("day_zenith",Vector3(DAY_ZENITH.r,DAY_ZENITH.g,DAY_ZENITH.b))
	_sky_mat.set_shader_parameter("day_horizon",horizon_color)
	for material in [_mat,_wall_mat,_field_mat]:
		if material == null: continue
		material.set_shader_parameter("to_sun",to_sun)
		material.set_shader_parameter("haze_density",haze_density)
		material.set_shader_parameter("sky_color",horizon_color)
func _process(_delta: float) -> void:
	if not background_ready: return
	update_ownership()
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
