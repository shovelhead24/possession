extends Node3D
# Intel UHD stress harness — find the real potato budget before committing to a LOD approach.
# Open this scene, F6. Slowly orbiting camera keeps the GPU working. HUD shows live perf.
#
# Measures the numbers the clipmap-vs-quadtree decision hinges on:
#   - raw triangle throughput (how many tris hold 60/30 fps)
#   - vertex texture fetch cost (heightmap displacement in the vertex shader — clipmap needs it)
#   - draw-call sensitivity: SAME tris as one big mesh (clipmap-like) vs many tiles (quadtree-like)
#   - MultiMesh instance ceiling (foliage)
#   - overdraw (alpha foliage cards)
#
# Keys:
#   [1..5]  triangle budget preset (per side): 128 / 256 / 512 / 768 / 1024
#   [Q]     draw-call mode: ONE big mesh  <->  GRID of tiles (same tri budget split into 8x8)
#   [E]     toggle vertex-shader heightmap displacement (vertex texture fetch)
#   [Up/Dn] MultiMesh foliage count: 0 / 5k / 20k / 50k / 100k / 200k
#   [A]     toggle alpha-card overdraw layer
#   [R]     rebuild

const TRI_PRESETS := [128, 256, 512, 768, 1024]   # subdivisions per side
const FOLIAGE_PRESETS := [0, 5_000, 20_000, 50_000, 100_000, 200_000]
const TILE_GRID := 12   # tiled mode splits into TILE_GRID x TILE_GRID meshes (finer = clearer culling)
const TERRAIN_SIZE := 2000.0
const DISP := 120.0    # must match the shader's disp default (heightmap -> metres)

var tri_idx := 2
var foliage_idx := 1
var tiled := false
var displace := true
var overdraw := false
var cam_ground := false   # [G] toggle: aerial orbit (sees everything) vs ground (sees a wedge)

var _cam: Camera3D
var _hud: Label
var _mat: ShaderMaterial
var _heightmap: NoiseTexture2D
var _terrain_root: Node3D = null
var _foliage: MultiMeshInstance3D = null
var _overdraw_node: MultiMeshInstance3D = null
var _t := 0.0
var _fps_accum := 0.0
var _fps_samples := 0
var _fps_avg := 0.0
var _height_img: Image = null

func _ready() -> void:
	# vsync OFF so FPS shows true throughput — capped at 60 it hides how much headroom there is
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.004
	_heightmap = NoiseTexture2D.new()
	_heightmap.width = 512
	_heightmap.height = 512
	_heightmap.noise = noise
	await _heightmap.changed  # wait for the texture to generate
	_height_img = _heightmap.get_image()  # CPU samples the SAME texture the GPU displaces by

	_cam = Camera3D.new()
	_cam.far = 8000.0
	add_child(_cam)
	_cam.make_current()

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.62, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)

	_mat = ShaderMaterial.new()
	_mat.shader = load("res://mocks/uhd_stress.gdshader") as Shader
	_mat.set_shader_parameter("heightmap", _heightmap)

	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(12, 12)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud.add_theme_constant_override("outline_size", 4)
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	layer.add_child(_hud)

	_rebuild()

func _make_terrain_mesh(subdiv: int) -> Mesh:
	var pm := PlaneMesh.new()
	pm.size = Vector2(TERRAIN_SIZE, TERRAIN_SIZE) if not tiled else Vector2(TERRAIN_SIZE / float(TILE_GRID), TERRAIN_SIZE / float(TILE_GRID))
	pm.subdivide_width = subdiv
	pm.subdivide_depth = subdiv
	pm.material = _mat
	return pm

func _rebuild() -> void:
	if _terrain_root: _terrain_root.queue_free()
	_terrain_root = Node3D.new()
	add_child(_terrain_root)
	var subdiv: int = TRI_PRESETS[tri_idx]
	if tiled:
		var per_tile: int = maxi(1, int(subdiv / TILE_GRID))
		var mesh := _make_terrain_mesh(per_tile)
		var step := TERRAIN_SIZE / float(TILE_GRID)
		for gx in TILE_GRID:
			for gz in TILE_GRID:
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.position = Vector3((gx + 0.5) * step - TERRAIN_SIZE * 0.5, 0, (gz + 0.5) * step - TERRAIN_SIZE * 0.5)
				_terrain_root.add_child(mi)
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _make_terrain_mesh(subdiv)
		_terrain_root.add_child(mi)
	_build_foliage()
	_build_overdraw()

func _build_foliage() -> void:
	if _foliage: _foliage.queue_free()
	_foliage = null
	var n: int = FOLIAGE_PRESETS[foliage_idx]
	if n == 0: return
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0; cone.bottom_radius = 3.0; cone.height = 10.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.15, 0.3, 0.15)
	cone.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = n
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for i in n:
		var x := rng.randf_range(-TERRAIN_SIZE * 0.5, TERRAIN_SIZE * 0.5)
		var z := rng.randf_range(-TERRAIN_SIZE * 0.5, TERRAIN_SIZE * 0.5)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, _sample_height(x, z) + 4.0, z)))
	_foliage = MultiMeshInstance3D.new()
	_foliage.multimesh = mm
	add_child(_foliage)

func _sample_height(x: float, z: float) -> float:
	# same texture + same world->uv mapping the shader uses -> foliage sits ON the displaced terrain
	if not _height_img or not displace:
		return 0.0
	var u := clampf(x / TERRAIN_SIZE + 0.5, 0.0, 1.0)
	var v := clampf(z / TERRAIN_SIZE + 0.5, 0.0, 1.0)
	var px := int(u * float(_height_img.get_width() - 1))
	var py := int(v * float(_height_img.get_height() - 1))
	return _height_img.get_pixel(px, py).r * DISP

func _build_overdraw() -> void:
	if _overdraw_node: _overdraw_node.queue_free()
	_overdraw_node = null
	if not overdraw: return
	# stacked translucent alpha cards to stress fill rate / overdraw
	var quad := QuadMesh.new()
	quad.size = Vector2(60, 60)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.6, 0.7, 0.5, 0.25)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = 4000
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	for i in 4000:
		var x := rng.randf_range(-TERRAIN_SIZE * 0.4, TERRAIN_SIZE * 0.4)
		var z := rng.randf_range(-TERRAIN_SIZE * 0.4, TERRAIN_SIZE * 0.4)
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, rng.randf_range(10, 120), z)))
	_overdraw_node = MultiMeshInstance3D.new()
	_overdraw_node.multimesh = mm
	add_child(_overdraw_node)

func _process(delta: float) -> void:
	_mat.set_shader_parameter("do_disp", displace)
	_t += delta * 0.1
	if cam_ground:
		# stand near one edge, eye height, and slowly sweep the view across the terrain — most
		# of the ring is behind/beside you and gets frustum-culled (the real in-game case)
		var cx := -TERRAIN_SIZE * 0.46
		var cz := 0.0
		var y := _sample_height(cx, cz) + 3.0
		_cam.position = Vector3(cx, y, cz)
		var yaw := sin(_t * 3.0) * 1.1
		_cam.look_at(Vector3(cx + cos(yaw) * 200.0, y + 10.0, cz + sin(yaw) * 200.0), Vector3.UP)
	else:
		var rad := 900.0
		_cam.position = Vector3(cos(_t) * rad, 350, sin(_t) * rad)
		_cam.look_at(Vector3(0, 60, 0), Vector3.UP)
	_fps_accum += 1.0 / maxf(delta, 0.0001)
	_fps_samples += 1
	if _fps_samples >= 15:
		_fps_avg = _fps_accum / _fps_samples
		_fps_accum = 0.0; _fps_samples = 0
	_update_hud()

func _update_hud() -> void:
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var subdiv: int = TRI_PRESETS[tri_idx]
	_hud.text = "FPS avg: %.0f   frame: %.1f ms\ndraw calls: %d   primitives(tris): %s\n\nterrain: %d subdiv/side  |  mode: %s  |  vtx-displace: %s\ncamera: %s   foliage: %s   overdraw: %s\n\nCULLING TEST: [G] toggle camera, watch draw calls + tris drop on GROUND when TILED\n[1-5] tri budget  [Q] one-mesh/tiled  [E] displace  [Up/Dn] foliage  [A] overdraw  [G] cam  [R] rebuild" % [
		_fps_avg, 1000.0 / maxf(_fps_avg, 1.0),
		draw_calls, _commafmt(prims),
		subdiv, ("TILED %dx%d" % [TILE_GRID, TILE_GRID]) if tiled else "ONE MESH", "on" if displace else "off",
		"GROUND" if cam_ground else "AERIAL", _commafmt(FOLIAGE_PRESETS[foliage_idx]), "on" if overdraw else "off"]

func _commafmt(n: int) -> String:
	var s := str(n); var out := ""; var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out; c += 1
		if c % 3 == 0 and i > 0: out = "," + out
	return out

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				tri_idx = event.keycode - KEY_1; _rebuild()
			KEY_Q: tiled = not tiled; _rebuild()
			KEY_E: displace = not displace
			KEY_UP: foliage_idx = mini(foliage_idx + 1, FOLIAGE_PRESETS.size() - 1); _build_foliage()
			KEY_DOWN: foliage_idx = maxi(foliage_idx - 1, 0); _build_foliage()
			KEY_A: overdraw = not overdraw; _build_overdraw()
			KEY_G: cam_ground = not cam_ground
			KEY_R: _rebuild()
