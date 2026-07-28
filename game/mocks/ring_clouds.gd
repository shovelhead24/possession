extends Node3D
# Cloud layers for ring_vibes. REUSES the April 2026 layered-FBM work (res://cloud_layer_shader.gdshader,
# from commit ae54493 "layered FBM plane approach (B)") rather than reinventing it -- that shader
# already solves the hard parts: world-space FBM (so planes never show tiling), a built-in horizon
# fade, fake normals from the density gradient (lit tops / shadowed sides), self-shadowing by
# density, and sunset scatter. Tuning constants below are lifted from the old cloud_system.gd.
#
# Superseded approach (2026-07-28, same day): scattered individual cloud "patch" quads -- read as
# obvious floating cards, not sky. Three big camera-following planes is the correct shape.
#
# Ring note: the planes are flat and world-axis-aligned, not bent to the ring's curvature. Over the
# ~28km plane the ring (R=477km) drops only ~200m at the edge, and the horizon fade hides that --
# not worth curving for a vibes check.

# 5 layers (was the old system's 3) -- more depth, each thinner, so the stack reads as volume
# rather than a few flat sheets. Per-layer alpha keeps the compounded opacity in check.
const CLOUD_ALTITUDES   := [800.0, 1300.0, 1900.0, 2500.0, 3200.0]
const CLOUD_TYPE_PARAMS := [                             # [noise_scale, noise_stretch_x]
	[0.00010, 1.0],   # low cumulus — largest rounded puffs
	[0.00014, 1.2],   # cumulus
	[0.00022, 1.5],   # altocumulus — medium wave patches
	[0.00026, 2.5],   # high altocumulus, starting to streak
	[0.00030, 6.0],   # cirrus — elongated wispy streaks
]
const LAYER_ALPHA := [0.85, 0.70, 0.60, 0.50, 0.45]      # higher layers thinner; stacked alpha compounds
# Rebalanced 2026-07-28 for the 5-layer stack. The first pass just interpolated the old 3-layer
# coverage curve out to 5 points while keeping its endpoints -- which ADDS two extra layers of
# cloud, so every preset read about one step heavier than its name (clear looked like fresh, fresh
# like overcast, overcast like heavy rain). Coverage is cut across the board to compensate; with
# 5 stacked layers the compounded alpha does the work that high per-layer coverage used to.
const WEATHER_PRESETS := {                               # per-layer [coverage, softness]
	"clear":    {"layers": [[0.00, 0.20], [0.00, 0.22], [0.04, 0.28], [0.10, 0.32], [0.20, 0.35]],
				 "brightness": 1.0, "self_shadow": 0.72},
	"fresh":    {"layers": [[0.20, 0.14], [0.13, 0.18], [0.05, 0.24], [0.02, 0.27], [0.01, 0.30]],
				 "brightness": 1.0, "self_shadow": 0.72},
	# overcast also read far too dark before: brightness 0.5 x heavy self-shadow (dense fbm -> low
	# self_shadow) compounded toward black. Thick overcast in life is bright-but-flat, not dark.
	"overcast": {"layers": [[0.55, 0.12], [0.50, 0.12], [0.44, 0.13], [0.34, 0.15], [0.24, 0.16]],
				 "brightness": 0.95, "self_shadow": 0.28},
}
const WEATHER_NAMES := ["clear", "fresh", "overcast"]   # [Z] cycles light -> heavy
const PLANE_SIZE := 28000.0                              # 28km across; half = horizon-fade radius
const LAYER_DIR_OFFSETS := [0.0, 20.0, 35.0, -10.0, -25.0]   # deg from base wind dir, per layer
const LAYER_SPEED_MULT  := [1.0, 0.78, 0.55, 0.42, 0.30]
const WIND_SPEED := 0.008
const WIND_DIR := Vector2(1.0, 0.0)

var _layers: Array[MeshInstance3D] = []
var _weather_idx := 0
var _visible := true

func _ready() -> void:
	_build_layers()
	_apply_weather()

func _build_layers() -> void:
	var shader := load("res://cloud_layer_shader.gdshader") as Shader
	if not shader:
		push_error("ring_clouds: cloud_layer_shader.gdshader not found")
		return
	var half := PLANE_SIZE * 0.5
	for i in CLOUD_ALTITUDES.size():
		var y: float = CLOUD_ALTITUDES[i]
		var tp: Array = CLOUD_TYPE_PARAMS[i]
		var verts := PackedVector3Array([
			Vector3(-half, 0.0, -half), Vector3(half, 0.0, -half),
			Vector3(-half, 0.0, half), Vector3(half, 0.0, half),
		])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("cloud_base", y - 200.0)
		mat.set_shader_parameter("cloud_top", y + 200.0)
		mat.set_shader_parameter("layer_t", float(i) / 2.0)
		mat.set_shader_parameter("plane_half_size", half)
		mat.set_shader_parameter("noise_scale", tp[0])
		mat.set_shader_parameter("noise_stretch", Vector2(tp[1], 1.0))
		mat.set_shader_parameter("layer_alpha", LAYER_ALPHA[i])
		var angle := deg_to_rad(LAYER_DIR_OFFSETS[i])
		var ca := cos(angle)
		var sa := sin(angle)
		mat.set_shader_parameter("wind_dir", Vector2(WIND_DIR.x * ca - WIND_DIR.y * sa, WIND_DIR.x * sa + WIND_DIR.y * ca))
		mat.set_shader_parameter("wind_speed", WIND_SPEED * LAYER_SPEED_MULT[i])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.position = Vector3(0.0, y, 0.0)
		mi.visible = _visible
		add_child(mi)
		_layers.append(mi)

func _apply_weather() -> void:
	var wp: Dictionary = WEATHER_PRESETS[WEATHER_NAMES[_weather_idx]]
	var layer_data: Array = wp["layers"]
	for i in _layers.size():
		var mat := _layers[i].material_override as ShaderMaterial
		if not mat:
			continue
		mat.set_shader_parameter("coverage", layer_data[i][0])
		mat.set_shader_parameter("softness", layer_data[i][1])
		mat.set_shader_parameter("self_shadow_amt", wp["self_shadow"])

func cycle_type() -> void:
	_weather_idx = (_weather_idx + 1) % WEATHER_NAMES.size()
	_apply_weather()

func type_name() -> String:
	return WEATHER_NAMES[_weather_idx]

func toggle_visible() -> void:
	_visible = not _visible
	for m in _layers:
		m.visible = _visible

func is_visible_flag() -> bool:
	return _visible

func set_day(day: float, to_sun := Vector3.UP) -> void:
	# brightness follows day/night; scatter warms the clouds when the sun is near the horizon
	var wp: Dictionary = WEATHER_PRESETS[WEATHER_NAMES[_weather_idx]]
	# night floor 0.4, not 0 -- lifted from the April tuning (commit 394352a, "raise night brightness
	# floor to 0.4 for legible night clouds"). Clouds that fade to black at night just vanish.
	var bright: float = lerpf(0.4, 1.0, day) * float(wp["brightness"])
	var scatter: float = clampf(1.0 - abs(to_sun.y) * 3.0, 0.0, 1.0) * day
	var sun_xz := Vector2(to_sun.x, to_sun.z)
	if sun_xz.length() > 0.001:
		sun_xz = sun_xz.normalized()
	for m in _layers:
		var mat := m.material_override as ShaderMaterial
		if not mat:
			continue
		mat.set_shader_parameter("cloud_brightness", bright)
		mat.set_shader_parameter("scatter", scatter)
		mat.set_shader_parameter("sun_dir_xz", sun_xz)

func update_around(cam_pos: Vector3) -> void:
	# planes follow the camera in XZ so they always reach the horizon in every direction; the FBM is
	# sampled in WORLD space, so the clouds themselves stay put as you move (no sliding-with-you
	# artifact) -- this is what the old shader's local-space _plane_offset horizon fade is built for.
	for i in _layers.size():
		_layers[i].position = Vector3(cam_pos.x, CLOUD_ALTITUDES[i], cam_pos.z)
