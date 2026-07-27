extends Node3D
# CDLOD terrain prototype (terrain-lod branch). Quadtree subdivides toward the camera; each node
# draws one shared unit grid scaled to its size; the shader morphs between LOD levels seamlessly.
# Job: prove morphing kills the LOD pop without being miserable to implement. Open scene, F6.
#
# Controls: click to capture mouse; WASD + Space/Ctrl fly, Shift boost; [M] LOD-colour view;
#           [F] auto-fly forward (hands-free, to watch LOD update); ESC release.

const GRID := 16                 # quads per node side (matches shader `grid`)
const MAX_LEVEL := 9             # 0 = finest leaves .. MAX_LEVEL = coarsest roots
const LEAF_SIZE := 128.0         # world size of a level-0 node
const BASE_RANGE := 200.0        # lod_range[0]; doubles each level -> ~102km draw distance
const TERRAIN_SIZE := 262144.0   # ~262km span (4x4 roots of 65km) — room for distant mountains
const DISP := 800.0              # mountain height scale
const FEATURE := 3500.0          # heightmap tiling period (mountain spacing)
const POOL := 1200
const RING_RADIUS := 318309.9    # 2000km circumference / TAU (the decided ring)
const DEM_R16 := "res://mocks/dem/millstreet.r16"
const DEM_META := "res://mocks/dem/millstreet.json"
const BUILD := 13   # bump on each change; HUD shows this + the .gd mtime so stale runs are obvious
const SKIRT := 0.15   # skirt depth as fraction of node size — hides the residual hairline cracks

var _grid_mesh: ArrayMesh
var _pool: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _used := 0
var _lod_range: Array[float] = []
var _heightmap: NoiseTexture2D
var _dem_tex: ImageTexture = null
var _dem_cam := Vector2.ZERO
var _dem_mpp := 23.45
var _dem_size := Vector2.ZERO
var _use_dem := true
var _cam: Camera3D
var _hud: Label
var _cam_xz := Vector2.ZERO
var _look := Vector2.ZERO
var _captured := false
var _show_lod := false
var _autofly := false
var _fps := 0.0
var _build_stamp := ""
# live-tunable morph params (no rebuild — _emit reads these every frame). Defaults = the values
# tuned live to hairline cracks: late narrow morph (0.9->1.0) + horizontal metric.
var _morph_lo := 0.9
var _morph_hi := 1.0
var _morph_horiz := true   # horizontal beat 3D — 3D was swamped by camera altitude
var _range_scale := 1.0    # scales all LOD ranges
var _curve := true         # [C] ring curvature on/off (compare flat vs curved)

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var mt := FileAccess.get_modified_time("res://mocks/cdlod.gd")
	_build_stamp = "build %d  (%s)" % [BUILD, Time.get_datetime_string_from_unix_time(mt).replace("T", " ")]
	print("cdlod ", _build_stamp)
	_recompute_ranges()

	var noise := FastNoiseLite.new()
	noise.frequency = 0.0025
	noise.fractal_octaves = 5
	_heightmap = NoiseTexture2D.new()
	_heightmap.width = 1024
	_heightmap.height = 1024
	_heightmap.seamless = true   # tiles cleanly so mountains recur across the ring
	_heightmap.noise = noise
	await _heightmap.changed
	_load_dem_texture()

	_grid_mesh = _build_unit_grid()

	_cam = Camera3D.new()
	_cam.far = 400000.0   # see across the ring
	_cam.position = Vector3(0, 260, 0)
	add_child(_cam)
	_cam.make_current()

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.64, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.68, 0.8)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var shader := load("res://mocks/cdlod.gdshader") as Shader
	for i in POOL:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("heightmap", _heightmap)
		mat.set_shader_parameter("terrain_size", TERRAIN_SIZE)
		mat.set_shader_parameter("disp", DISP)
		mat.set_shader_parameter("grid", float(GRID))
		mat.set_shader_parameter("feature", FEATURE)
		mat.set_shader_parameter("ring_radius", RING_RADIUS)
		if _dem_tex:
			mat.set_shader_parameter("dem_tex", _dem_tex)
			mat.set_shader_parameter("dem_cam", _dem_cam)
			mat.set_shader_parameter("dem_mpp", _dem_mpp)
			mat.set_shader_parameter("dem_size", _dem_size)
		var mi := MeshInstance3D.new()
		mi.mesh = _grid_mesh
		mi.material_override = mat
		mi.visible = false
		add_child(mi)
		_pool.append(mi)
		_mats.append(mat)

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(12, 12)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud.add_theme_constant_override("outline_size", 4)
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	layer.add_child(_hud)

func _load_dem_texture() -> void:
	# real Millstreet DEM -> a float (RF) GPU texture the CDLOD vertex shader can sample.
	# Half-res (every 2nd pixel) to keep the build loop quick; still ~47 m/texel.
	if not (FileAccess.file_exists(DEM_R16) and FileAccess.file_exists(DEM_META)):
		print("cdlod: no DEM found — using procedural noise")
		_use_dem = false
		return
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEM_META))
	var w := int(meta["w"])
	var h := int(meta["h"])
	var mpp := float(meta["m_per_px"])
	var cam_px: Array = meta["camera_px"]
	var raw := FileAccess.get_file_as_bytes(DEM_R16)   # u16 little-endian
	var dw := w / 2
	var dh := h / 2
	var floats := PackedFloat32Array()
	floats.resize(dw * dh)
	for y in dh:
		var sy := y * 2
		for x in dw:
			floats[y * dw + x] = float(raw.decode_u16((sy * w + x * 2) * 2)) / 16.0  # metres
	var img := Image.create_from_data(dw, dh, false, Image.FORMAT_RF, floats.to_byte_array())
	_dem_tex = ImageTexture.create_from_image(img)
	_dem_cam = Vector2(float(cam_px[0]) * 0.5, float(cam_px[1]) * 0.5)
	_dem_mpp = mpp * 2.0
	_dem_size = Vector2(dw, dh)
	print("cdlod: DEM texture %dx%d, mpp=%.1f" % [dw, dh, _dem_mpp])

func _ring_pt(arc: float, lat: float, h: float) -> Vector3:
	# CPU mirror of the shader's flat->ring transform (for correct curved AABBs)
	if not _curve:
		return Vector3(arc, h, lat)
	var theta := arc / RING_RADIUS
	var rr := RING_RADIUS - h
	return Vector3(rr * sin(theta), RING_RADIUS - rr * cos(theta), lat)

func _recompute_ranges() -> void:
	_lod_range.clear()
	for l in MAX_LEVEL + 1:
		_lod_range.append(BASE_RANGE * _range_scale * pow(2.0, l))

func _build_unit_grid() -> ArrayMesh:
	# unit grid in [0,1] on X/Z (Y=0), plus a skirt ribbon around the perimeter whose bottom verts
	# are marked Y=-1 — the shader drops those below the terrain to hide residual hairline cracks.
	var verts: Array[Vector3] = []
	var idx: Array[int] = []
	for i in GRID + 1:
		for j in GRID + 1:
			verts.append(Vector3(float(i) / GRID, 0.0, float(j) / GRID))
	for i in GRID:
		for j in GRID:
			var a := i * (GRID + 1) + j
			var b := a + GRID + 1
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	# skirt: for each of the 4 edges, a vertical ribbon (top on the edge, bottom marked y=-1).
	# cull_disabled, so winding doesn't matter here.
	var edges := [
		func(k: int) -> Vector3: return Vector3(float(k) / GRID, 0.0, 0.0),      # south
		func(k: int) -> Vector3: return Vector3(float(k) / GRID, 0.0, 1.0),      # north
		func(k: int) -> Vector3: return Vector3(0.0, 0.0, float(k) / GRID),      # west
		func(k: int) -> Vector3: return Vector3(1.0, 0.0, float(k) / GRID),      # east
	]
	for edge in edges:
		for k in GRID:
			var t0: Vector3 = edge.call(k)
			var t1: Vector3 = edge.call(k + 1)
			var base := verts.size()
			verts.append(t0)                                   # top 0
			verts.append(t1)                                   # top 1
			verts.append(Vector3(t0.x, -1.0, t0.z))            # bottom 0 (marker)
			verts.append(Vector3(t1.x, -1.0, t1.z))            # bottom 1 (marker)
			idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in verts:
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)
	for i in idx:
		st.add_index(i)
	return st.commit()

func _select(ox: float, oz: float, size: float, level: int) -> void:
	if _used >= POOL:
		return
	if level > 0:
		# distance to the node's NEAREST point (not centre) — keeps neighbouring tiles within one
		# LOD level far more reliably, which is the condition the morph needs to close seams. 3D
		# (clamped in XZ, full cam height) so it stays altitude-aware.
		var nx := clampf(_cam.position.x, ox, ox + size)
		var nz := clampf(_cam.position.z, oz, oz + size)
		if _cam.position.distance_to(Vector3(nx, 0.0, nz)) < _lod_range[level - 1]:
			var h := size * 0.5
			_select(ox, oz, h, level - 1)
			_select(ox + h, oz, h, level - 1)
			_select(ox, oz + h, h, level - 1)
			_select(ox + h, oz + h, h, level - 1)
			return
	_emit(ox, oz, size, level)

func _emit(ox: float, oz: float, size: float, level: int) -> void:
	var mi := _pool[_used]
	var mat := _mats[_used]
	var band_near: float = 0.0 if level == 0 else _lod_range[level - 1]
	var band_far: float = _lod_range[level]
	mat.set_shader_parameter("node_origin", Vector2(ox, oz))
	mat.set_shader_parameter("node_size", size)
	mat.set_shader_parameter("morph_start", lerpf(band_near, band_far, _morph_lo))
	mat.set_shader_parameter("morph_end", lerpf(band_near, band_far, _morph_hi))
	mat.set_shader_parameter("lod_tint", float(level) / float(MAX_LEVEL))
	mat.set_shader_parameter("show_lod", _show_lod)
	# AABB from the node's (possibly curved) corners so frustum culling matches the shader output.
	var aabb := AABB(_ring_pt(ox, oz, DISP), Vector3.ZERO)
	for cx in [ox, ox + size]:
		for cz in [oz, oz + size]:
			aabb = aabb.expand(_ring_pt(cx, cz, DISP))
			aabb = aabb.expand(_ring_pt(cx, cz, -DISP - size * SKIRT))
	mi.custom_aabb = aabb.grow(size * 0.5)   # half-tile margin = soft overlap, less peripheral pop
	mi.visible = true
	_used += 1

func _rebuild_lod() -> void:
	_used = 0
	var root_size: float = LEAF_SIZE * pow(2.0, MAX_LEVEL)
	var roots := int(ceil(TERRAIN_SIZE / root_size))
	var half := roots * root_size * 0.5
	for gx in roots:
		for gz in roots:
			_select(gx * root_size - half, gz * root_size - half, root_size, MAX_LEVEL)
	for i in range(_used, _pool.size()):
		_pool[i].visible = false
	var cp := Vector3(_cam.position.x, _cam.position.y, _cam.position.z)
	for i in _used:
		_mats[i].set_shader_parameter("cam_pos", cp)
		_mats[i].set_shader_parameter("morph_horizontal", _morph_horiz)
		_mats[i].set_shader_parameter("skirt", SKIRT)
		_mats[i].set_shader_parameter("curve", _curve)
		_mats[i].set_shader_parameter("use_dem", _use_dem and _dem_tex != null)

func _process(delta: float) -> void:
	_fps = lerpf(_fps, 1.0 / maxf(delta, 0.0001), 0.1)
	if _autofly:
		_cam.position += -_cam.global_basis.z * 60.0 * delta
	_fly(delta)
	_cam_xz = Vector2(_cam.position.x, _cam.position.z)
	_rebuild_lod()
	_update_hud()

func _fly(delta: float) -> void:
	if not _captured:
		return
	var spd := 400.0 if Input.is_key_pressed(KEY_SHIFT) else 90.0
	var d := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): d -= _cam.global_basis.z
	if Input.is_key_pressed(KEY_S): d += _cam.global_basis.z
	if Input.is_key_pressed(KEY_A): d -= _cam.global_basis.x
	if Input.is_key_pressed(KEY_D): d += _cam.global_basis.x
	if Input.is_key_pressed(KEY_SPACE): d += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL): d -= Vector3.UP
	if d != Vector3.ZERO:
		_cam.position += d.normalized() * spd * delta

func _update_hud() -> void:
	var dc := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_hud.text = "cdlod %s\nFPS: %.0f   draw calls: %d   tris: %s   nodes: %d   cam h: %.0f m\n\nMORPH:  start [ / ] = %.2f    end ; / ' = %.2f    [H] metric: %s\nRANGE:  , / . scale = %.2f   [C] curve: %s\n\n[M] LOD colour: %s   [F] auto-fly: %s   [R] reset params\nclick=capture  WASD+Space/Ctrl fly  Shift boost  ESC release" % [
		_build_stamp, _fps, dc, str(prims), _used, _cam.position.y,
		_morph_lo, _morph_hi, "horizontal" if _morph_horiz else "3D",
		_range_scale, "ON" if _curve else "off",
		"ON" if _show_lod else "off", "ON" if _autofly else "off"]
	_hud.text += "   [D] DEM: %s" % ("real" if (_use_dem and _dem_tex) else ("noise" if _dem_tex else "noise (no DEM)"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_captured = true
	if event is InputEventMouseMotion and _captured:
		_look -= event.relative * 0.0022
		_look.y = clampf(_look.y, -1.55, 1.55)
		_cam.rotation = Vector3(_look.y, _look.x, 0)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_captured = false
			KEY_M:
				_show_lod = not _show_lod
			KEY_F:
				_autofly = not _autofly
			KEY_BRACKETLEFT:
				_morph_lo = clampf(_morph_lo - 0.05, 0.0, _morph_hi - 0.05)
			KEY_BRACKETRIGHT:
				_morph_lo = clampf(_morph_lo + 0.05, 0.0, _morph_hi - 0.05)
			KEY_SEMICOLON:
				_morph_hi = clampf(_morph_hi - 0.05, _morph_lo + 0.05, 1.0)
			KEY_APOSTROPHE:
				_morph_hi = clampf(_morph_hi + 0.05, _morph_lo + 0.05, 1.0)
			KEY_H:
				_morph_horiz = not _morph_horiz
			KEY_C:
				_curve = not _curve
			KEY_D:
				if _dem_tex: _use_dem = not _use_dem
			KEY_COMMA:
				_range_scale = maxf(0.25, _range_scale - 0.25); _recompute_ranges()
			KEY_PERIOD:
				_range_scale = minf(4.0, _range_scale + 0.25); _recompute_ranges()
			KEY_R:
				_morph_lo = 0.9; _morph_hi = 1.0; _morph_horiz = true; _range_scale = 1.0; _recompute_ranges()
