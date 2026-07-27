extends Node3D
# CDLOD terrain prototype (terrain-lod branch). Quadtree subdivides toward the camera; each node
# draws one shared unit grid scaled to its size; the shader morphs between LOD levels seamlessly.
# Job: prove morphing kills the LOD pop without being miserable to implement. Open scene, F6.
#
# Controls: click to capture mouse; WASD + Space/Ctrl fly, Shift boost; [M] LOD-colour view;
#           [F] auto-fly forward (hands-free, to watch LOD update); ESC release.

const GRID := 16                 # quads per node side (matches shader `grid`)
const MAX_LEVEL := 4             # 0 = finest leaves .. MAX_LEVEL = coarsest roots
const LEAF_SIZE := 128.0         # world size of a level-0 node
const BASE_RANGE := 200.0        # lod_range[0]; doubles each level
const TERRAIN_SIZE := 4096.0
const DISP := 300.0
const POOL := 400

var _grid_mesh: ArrayMesh
var _pool: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _used := 0
var _lod_range: Array[float] = []
var _heightmap: NoiseTexture2D
var _cam: Camera3D
var _hud: Label
var _cam_xz := Vector2.ZERO
var _look := Vector2.ZERO
var _captured := false
var _show_lod := false
var _autofly := false
var _fps := 0.0

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for l in MAX_LEVEL + 1:
		_lod_range.append(BASE_RANGE * pow(2.0, l))

	var noise := FastNoiseLite.new()
	noise.frequency = 0.0025
	noise.fractal_octaves = 5
	_heightmap = NoiseTexture2D.new()
	_heightmap.width = 1024
	_heightmap.height = 1024
	_heightmap.noise = noise
	await _heightmap.changed

	_grid_mesh = _build_unit_grid()

	_cam = Camera3D.new()
	_cam.far = 12000.0
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

func _build_unit_grid() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in GRID + 1:
		for j in GRID + 1:
			st.set_uv(Vector2(float(i) / GRID, float(j) / GRID))
			st.add_vertex(Vector3(float(i) / GRID, 0.0, float(j) / GRID))
	for i in GRID:
		for j in GRID:
			var a := i * (GRID + 1) + j
			var b := a + GRID + 1
			st.add_index(a); st.add_index(a + 1); st.add_index(b)
			st.add_index(a + 1); st.add_index(b + 1); st.add_index(b)
	return st.commit()

func _select(ox: float, oz: float, size: float, level: int) -> void:
	if _used >= POOL:
		return
	if level > 0:
		var center := Vector2(ox + size * 0.5, oz + size * 0.5)
		if center.distance_to(_cam_xz) < _lod_range[level - 1]:
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
	mat.set_shader_parameter("morph_start", lerpf(band_near, band_far, 0.6))
	mat.set_shader_parameter("morph_end", band_far)
	mat.set_shader_parameter("lod_tint", float(level) / float(MAX_LEVEL))
	mat.set_shader_parameter("show_lod", _show_lod)
	# AABB matching THIS node's actual world region (shader outputs world pos; instance is identity)
	# — with a lateral margin for the coarse-morph, so frustum culling is correct, not gap-inducing.
	mi.custom_aabb = AABB(Vector3(ox - size * 0.1, -DISP, oz - size * 0.1),
		Vector3(size * 1.2, 2.0 * DISP, size * 1.2))
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
	_hud.text = "FPS: %.0f   draw calls: %d   tris: %s\nnodes: %d   cam height: %.0f m\nLOD ranges: %s\n\n[M] LOD colour: %s   [F] auto-fly: %s\nclick=capture  WASD+Space/Ctrl fly  Shift boost  ESC release" % [
		_fps, dc, str(prims), _used, _cam.position.y,
		str(_lod_range), "ON" if _show_lod else "off", "ON" if _autofly else "off"]

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
