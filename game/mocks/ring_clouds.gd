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
# Per-layer shape/animation character. Without this every layer is the same fbm sliding linearly,
# which reads as flat uniform sheets. Gradient runs low->high: dense fluffy slow-churning cumulus
# up to wispy fast-churning cirrus.
# [warp_amount, warp_freq, warp_speed, evolve_speed, density_pow, macro_amount, macro_scale]
# NOTE on warp_speed/evolve_speed: these MUST stay well below the layer's effective wind_speed.
# First pass had them 4-45x HIGHER, so the shapes boiled in place far faster than they translated --
# reading as "baked in position, fading in and out" rather than drifting. Real cloud turbulence
# advects with the air mass and morphs slowly relative to its travel. Now ~15% / ~8% of wind speed.
const CLOUD_SHAPE := [
	[0.30, 0.55, 0.0024, 0.0013, 2.0, 0.55, 0.12],   # low cumulus — dense pinched centres, broad regions
	[0.45, 0.65, 0.0019, 0.0010, 1.7, 0.45, 0.15],   # cumulus
	[0.70, 0.80, 0.0013, 0.0007, 1.3, 0.35, 0.20],   # altocumulus — more shear
	[1.00, 1.00, 0.0010, 0.0005, 1.0, 0.25, 0.25],   # high altocumulus — streaking
	[1.60, 1.30, 0.0007, 0.0004, 0.8, 0.15, 0.30],   # cirrus — heavy warp, wispy tails
]
# Rebalanced 2026-07-28 for the 5-layer stack. The first pass just interpolated the old 3-layer
# coverage curve out to 5 points while keeping its endpoints -- which ADDS two extra layers of
# cloud, so every preset read about one step heavier than its name (clear looked like fresh, fresh
# like overcast, overcast like heavy rain). Coverage is cut across the board to compensate; with
# 5 stacked layers the compounded alpha does the work that high per-layer coverage used to.
const WEATHER_PRESETS := {                               # per-layer [coverage, softness]
	"clear":    {"layers": [[0.00, 0.20], [0.00, 0.22], [0.04, 0.28], [0.10, 0.32], [0.20, 0.35]],
				 "brightness": 1.0, "self_shadow": 0.72},
	# baked 2026-07-29 from live slider tuning (was coverage x2.21, opacity x1.57, softness x0.81,
	# brightness x1.29 on the previous values) -- user-approved "fresh" look.
	"fresh":    {"layers": [[0.44, 0.11], [0.29, 0.15], [0.11, 0.19], [0.04, 0.22], [0.02, 0.24]],
				 "brightness": 1.29, "self_shadow": 0.72, "alpha": [1.0, 1.0, 0.94, 0.79, 0.71]},
	# overcast also read far too dark before: brightness 0.5 x heavy self-shadow (dense fbm -> low
	# self_shadow) compounded toward black. Thick overcast in life is bright-but-flat, not dark.
	# raised again after the rebalance overshot -- read "pretty but not overcast". Still bright/flat
	# rather than storm-dark; the live sliders are the real answer for dialling this in.
	"overcast": {"layers": [[0.74, 0.11], [0.70, 0.11], [0.62, 0.12], [0.50, 0.14], [0.38, 0.15]],
				 "brightness": 0.95, "self_shadow": 0.28},
	# --- added 2026-08-04, once the portfolio stopped being all temperate --------------------
	# The coverage array is a VERTICAL PROFILE (800m cumulus -> 3200m cirrus), which the first
	# three only ever used as a single dial from empty to full. These use its shape.
	#
	# high thin streaks with nothing underneath: the arid sky, which is not the same as "clear"
	# -- an empty sky reads as missing, a cirrus sky reads as dry.
	"cirrus":   {"layers": [[0.00, 0.24], [0.00, 0.26], [0.03, 0.30], [0.16, 0.30], [0.46, 0.28]],
				 "brightness": 1.18, "self_shadow": 0.86, "alpha": [0.85, 0.70, 0.60, 0.62, 0.68]},
	# the dark one overcast deliberately is not. Overcast in life is bright-but-flat; this is
	# the low, heavy, genuinely dim sky, weighted to the bottom of the stack.
	"storm":    {"layers": [[0.90, 0.08], [0.86, 0.09], [0.72, 0.10], [0.52, 0.12], [0.28, 0.14]],
				 "brightness": 0.52, "self_shadow": 0.14, "alpha": [1.0, 1.0, 0.95, 0.80, 0.60]},
	# tropical: heavy below, a gap, then bright tops. That re-rise at the top layer is what
	# gives towering build-ups instead of a lid -- the profile the equator actually has, and
	# what java, palawan and halong were wearing temperate overcast for want of.
	"monsoon":  {"layers": [[0.82, 0.09], [0.66, 0.12], [0.40, 0.18], [0.46, 0.16], [0.62, 0.13]],
				 "brightness": 0.88, "self_shadow": 0.20, "alpha": [1.0, 0.92, 0.72, 0.80, 0.86]},
}
# [Z] cycles these in order, so keep them sorted light -> heavy
const WEATHER_NAMES := ["clear", "cirrus", "fresh", "monsoon", "overcast", "storm"]
# Arc extent is what lets the deck reach the horizon: at 120km a 1000m cloud sits 0.48 deg above
# horizontal (vs 4.1 deg at the old 14km, which is why it visibly stopped short of the horizon).
# Only possible because the sheet now bends with the ring -- see cloud_layer_shader.gdshader.
const PLANE_ARC := 240000.0                              # +/-120km along the arc
const ARC_SEGS := 64                                     # subdivision so the ring bend is a curve, not a flat quad
const LAT_SEGS := 4
const FADE_START := 0.5                                  # fraction of half-arc where the horizon fade begins
const LAYER_DIR_OFFSETS := [0.0, 20.0, 35.0, -10.0, -25.0]   # deg from base wind dir, per layer
const LAYER_SPEED_MULT  := [1.0, 0.78, 0.55, 0.42, 0.30]
const WIND_SPEED := 0.016   # doubled so the drift actually reads; [O] panel scales it live
const WIND_DIR := Vector2(1.0, 0.0)

var _layers: Array[MeshInstance3D] = []
var _weather_idx := 0
var _visible := true
# Smooth biome-driven weather. Presets used to be a manual [Z] cycle only, so a desert patch had
# the same sky as a delta. ring_vibes now calls transition_to() as the camera crosses biomes, and
# the blend is eased over WEATHER_BLEND seconds -- snapping the whole sky on a patch boundary would
# read as a glitch, not weather.
const WEATHER_BLEND := 25.0
var _wx_from := ""
var _wx_to := ""
var _wx_t := 1.0
var auto_weather := true          # [Z] switches to manual and stops biome overrides
# live tuning multipliers, driven by the debug sliders in ring_vibes.gd. These MULTIPLY the preset
# values rather than replacing them, so the presets stay meaningful and 1.0 == "as authored".
var ring_radius := 0.0    # set by ring_vibes before _ready(); 0 = flat planes (old behaviour)
var ring_width := 0.0
var wall_top := 4000.0    # matches ring_vibes' wall_top_h, for the wall-shadow test
var wall_shadow_soft := 400.0
var cov_mult := 1.0
var soft_mult := 1.0
var alpha_mult := 1.0
var warp_mult := 1.0
var bright_mult := 1.0
var wind_mult := 1.0     # drift speed (how fast clouds travel)
var churn_mult := 1.0    # warp/evolve speed (how fast they morph in place)

func _ready() -> void:
	_build_layers()
	_apply_weather()

func _build_layers() -> void:
	var shader := load("res://cloud_layer_shader.gdshader") as Shader
	if not shader:
		push_error("ring_clouds: cloud_layer_shader.gdshader not found")
		return
	var half := PLANE_ARC * 0.5
	var half_lat: float = ring_width * 0.5 if ring_width > 0.0 else 25000.0
	for i in CLOUD_ALTITUDES.size():
		var y: float = CLOUD_ALTITUDES[i]
		var tp: Array = CLOUD_TYPE_PARAMS[i]
		# subdivided strip: long in arc (bends with the ring), bounded in lat by the ring walls --
		# clouds shouldn't extend past the habitat edge, and the walls occlude that view anyway.
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var idx := PackedInt32Array()
		for a in ARC_SEGS + 1:
			var fx: float = lerpf(-half, half, float(a) / float(ARC_SEGS))
			for l in LAT_SEGS + 1:
				var fz: float = lerpf(-half_lat, half_lat, float(l) / float(LAT_SEGS))
				verts.append(Vector3(fx, 0.0, fz))
				norms.append(Vector3.UP)
		for a in ARC_SEGS:
			for l in LAT_SEGS:
				var v0 := a * (LAT_SEGS + 1) + l
				var v1 := v0 + LAT_SEGS + 1
				idx.append_array([v0, v1, v0 + 1, v0 + 1, v1, v1 + 1])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("cloud_base", y - 200.0)
		mat.set_shader_parameter("cloud_top", y + 200.0)
		mat.set_shader_parameter("layer_t", float(i) / float(CLOUD_ALTITUDES.size() - 1))
		mat.set_shader_parameter("plane_half_size", half)
		mat.set_shader_parameter("ring_radius", ring_radius)
		mat.set_shader_parameter("altitude", y)
		mat.set_shader_parameter("fade_start", FADE_START)
		mat.set_shader_parameter("ring_half_width", half_lat)
		mat.set_shader_parameter("wall_top", wall_top)
		mat.set_shader_parameter("wall_shadow_soft", wall_shadow_soft)
		mat.set_shader_parameter("noise_scale", tp[0])
		mat.set_shader_parameter("noise_stretch", Vector2(tp[1], 1.0))
		mat.set_shader_parameter("layer_alpha", LAYER_ALPHA[i])
		var sh: Array = CLOUD_SHAPE[i]
		mat.set_shader_parameter("warp_amount", sh[0])
		mat.set_shader_parameter("warp_freq", sh[1])
		mat.set_shader_parameter("warp_speed", sh[2])
		mat.set_shader_parameter("evolve_speed", sh[3])
		mat.set_shader_parameter("density_pow", sh[4])
		mat.set_shader_parameter("macro_amount", sh[5])
		mat.set_shader_parameter("macro_scale", sh[6])
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
		# shader writes world positions directly, so the node stays at origin; a generous custom AABB
		# stops Godot frustum-culling the sheet based on its (meaningless) local bounds.
		mi.position = Vector3.ZERO
		mi.custom_aabb = AABB(Vector3(-PLANE_ARC, -PLANE_ARC, -PLANE_ARC), Vector3(PLANE_ARC * 2.0, PLANE_ARC * 2.0, PLANE_ARC * 2.0))
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
		mat.set_shader_parameter("coverage", clampf(layer_data[i][0] * cov_mult, 0.0, 1.0))
		mat.set_shader_parameter("softness", clampf(layer_data[i][1] * soft_mult, 0.01, 0.5))
		mat.set_shader_parameter("self_shadow_amt", wp["self_shadow"])
		var base_alpha: float = wp["alpha"][i] if wp.has("alpha") else LAYER_ALPHA[i]
		mat.set_shader_parameter("layer_alpha", clampf(base_alpha * alpha_mult, 0.0, 1.0))
		mat.set_shader_parameter("warp_amount", CLOUD_SHAPE[i][0] * warp_mult)
		mat.set_shader_parameter("warp_speed", CLOUD_SHAPE[i][2] * churn_mult)
		mat.set_shader_parameter("evolve_speed", CLOUD_SHAPE[i][3] * churn_mult)
		mat.set_shader_parameter("wind_speed", WIND_SPEED * LAYER_SPEED_MULT[i] * wind_mult)

func retune() -> void:
	# re-apply everything after a slider moves (coverage/softness/alpha/warp all live here)
	_apply_weather()

func cycle_type() -> void:
	# manual override: stop biome-driven weather so the chosen preset sticks
	auto_weather = false
	_weather_idx = (_weather_idx + 1) % WEATHER_NAMES.size()
	_wx_t = 1.0
	_wx_from = ""
	_apply_weather()

func transition_to(name: String) -> void:
	if not auto_weather or not WEATHER_PRESETS.has(name):
		return
	var current: String = _wx_to if _wx_to != "" else str(WEATHER_NAMES[_weather_idx])
	if name == current and _wx_t >= 1.0:
		return
	# blend from wherever we currently ARE, so a mid-transition change doesn't jump back
	_wx_from = current if _wx_t >= 1.0 else _blend_name()
	_wx_to = name
	_wx_t = 0.0

func _blend_name() -> String:
	# mid-blend snapshot identity; the numbers are interpolated in _process, this is just for HUD
	return _wx_from if _wx_t < 0.5 else _wx_to

func _process(delta: float) -> void:
	if _wx_t >= 1.0 or _wx_from == "" or _wx_to == "":
		return
	_wx_t = minf(_wx_t + delta / WEATHER_BLEND, 1.0)
	var t: float = _wx_t * _wx_t * (3.0 - 2.0 * _wx_t)   # smoothstep ease
	var a: Dictionary = WEATHER_PRESETS[_wx_from]
	var b: Dictionary = WEATHER_PRESETS[_wx_to]
	for i in _layers.size():
		var mat := _layers[i].material_override as ShaderMaterial
		if not mat:
			continue
		var la: Array = a["layers"][i]
		var lb: Array = b["layers"][i]
		mat.set_shader_parameter("coverage", clampf(lerpf(la[0], lb[0], t) * cov_mult, 0.0, 1.0))
		mat.set_shader_parameter("softness", clampf(lerpf(la[1], lb[1], t) * soft_mult, 0.01, 0.5))
		mat.set_shader_parameter("self_shadow_amt", lerpf(a["self_shadow"], b["self_shadow"], t))
		var aa: float = a["alpha"][i] if a.has("alpha") else LAYER_ALPHA[i]
		var ab: float = b["alpha"][i] if b.has("alpha") else LAYER_ALPHA[i]
		mat.set_shader_parameter("layer_alpha", clampf(lerpf(aa, ab, t) * alpha_mult, 0.0, 1.0))
	if _wx_t >= 1.0:
		_weather_idx = WEATHER_NAMES.find(_wx_to)
		_wx_from = ""

func type_name() -> String:
	if _wx_t < 1.0 and _wx_from != "":
		return "%s->%s %d%%" % [_wx_from, _wx_to, int(_wx_t * 100.0)]
	return str(WEATHER_NAMES[_weather_idx]) + ("" if auto_weather else " (manual)")

func toggle_visible() -> void:
	_visible = not _visible
	for m in _layers:
		m.visible = _visible

func is_visible_flag() -> bool:
	return _visible

func set_day(day: float, to_sun := Vector3.UP) -> void:
	# brightness follows day/night; scatter warms the clouds when the sun is near the horizon
	# blended across a weather transition, or it snaps on the frame the preset index flips
	var wb: float = float(WEATHER_PRESETS[WEATHER_NAMES[_weather_idx]]["brightness"])
	if _wx_t < 1.0 and _wx_from != "" and _wx_to != "":
		var t: float = _wx_t * _wx_t * (3.0 - 2.0 * _wx_t)
		wb = lerpf(float(WEATHER_PRESETS[_wx_from]["brightness"]),
				   float(WEATHER_PRESETS[_wx_to]["brightness"]), t)
	# night floor 0.4, not 0 -- lifted from the April tuning (commit 394352a, "raise night brightness
	# floor to 0.4 for legible night clouds"). Clouds that fade to black at night just vanish.
	var bright: float = lerpf(0.4, 1.0, day) * wb * bright_mult
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
		mat.set_shader_parameter("sun_world", to_sun)   # true 3D direction, for the wall-shadow test

func update_around(cam_pos: Vector3) -> void:
	# the sheet follows the camera in RING coords (arc, lat) -- the shader bends it onto the cylinder
	# and samples noise in those same coords, so clouds stay put in the world as you move rather
	# than sliding along with you.
	if ring_radius <= 0.0:
		for i in _layers.size():
			_layers[i].position = Vector3(cam_pos.x, CLOUD_ALTITUDES[i], cam_pos.z)
		return
	var theta := atan2(cam_pos.x, ring_radius - cam_pos.y)
	var origin := Vector2(theta * ring_radius, cam_pos.z)
	for i in _layers.size():
		var mat := _layers[i].material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("plane_origin", origin)
