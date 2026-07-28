extends Node3D
# Rudimentary cloud-card layer "just above our heads" (2026-07-28) -- replaces the sky-shader
# ring-in-sky backdrop, which turned out to be effectively invisible (occluded by the real 3D
# geometry everywhere except a seam). This is real geometry: flat quads scattered in a disc above
# the camera, alpha-cut from a shared noise texture. [Z] cycles type, [X] toggles visibility.
#
# Deliberately simple: "up" is treated as world +Y (not the ring's curved local-up) since clouds
# only matter within a few km of the camera, where the ring's curvature is negligible -- not worth
# the complexity for a vibes check.

const CLOUD_TYPES := [
	{"name": "cirrus",   "height": 6000.0, "count": 36, "size": 1100.0, "radius": 14000.0, "coverage": 0.30, "soft": 0.45},
	{"name": "cumulus",  "height": 2200.0, "count": 55, "size": 550.0,  "radius": 9000.0,  "coverage": 0.50, "soft": 0.30},
	{"name": "overcast", "height": 1600.0, "count": 110, "size": 650.0, "radius": 9000.0,  "coverage": 0.78, "soft": 0.40},
]
const REGEN_DIST := 3000.0   # regenerate the scatter once the camera drifts this far from last centre

var _type_idx := 1
var _mm_inst: MultiMeshInstance3D = null
var _mat: ShaderMaterial = null
var _cloud_tex: ImageTexture = null
var _last_gen_pos := Vector3(1e18, 0.0, 0.0)
var _visible := true

func _ready() -> void:
	_cloud_tex = _make_cloud_tex()
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://mocks/ring_clouds.gdshader") as Shader
	_mat.set_shader_parameter("cloud_tex", _cloud_tex)
	_apply_type_params()

func _make_cloud_tex() -> ImageTexture:
	# FastNoiseLite.get_image() is synchronous (unlike NoiseTexture2D, which generates async) --
	# fine here since this runs once at startup, not per-instance.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 4
	noise.frequency = 0.012
	var img := noise.get_image(256, 256)
	return ImageTexture.create_from_image(img)

func _apply_type_params() -> void:
	var t: Dictionary = CLOUD_TYPES[_type_idx]
	_mat.set_shader_parameter("coverage", t["coverage"])
	_mat.set_shader_parameter("softness", t["soft"])
	_last_gen_pos = Vector3(1e18, 0.0, 0.0)   # force a regen with the new density/size

func cycle_type() -> void:
	_type_idx = (_type_idx + 1) % CLOUD_TYPES.size()
	_apply_type_params()

func type_name() -> String:
	return CLOUD_TYPES[_type_idx]["name"]

func toggle_visible() -> void:
	_visible = not _visible
	if _mm_inst:
		_mm_inst.visible = _visible

func is_visible_flag() -> bool:
	return _visible

func set_day(day: float) -> void:
	if _mat:
		_mat.set_shader_parameter("day", day)

func update_around(cam_pos: Vector3) -> void:
	if cam_pos.distance_to(_last_gen_pos) < REGEN_DIST and _mm_inst:
		return
	_last_gen_pos = cam_pos
	_regen(cam_pos)

func _regen(cam_pos: Vector3) -> void:
	var t: Dictionary = CLOUD_TYPES[_type_idx]
	if _mm_inst:
		_mm_inst.queue_free()
	var quad := QuadMesh.new()
	quad.size = Vector2(t["size"], t["size"])
	quad.material = _mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	var n: int = t["count"]
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var radius: float = t["radius"]
	var height: float = t["height"]
	# lie the quad flat (its face, +Z in mesh space, ends up pointing +Y/up) -- cull_disabled means
	# which side faces the viewer (below, looking up) doesn't matter.
	var flat := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	for i in n:
		var a := rng.randf_range(0.0, TAU)
		var d := sqrt(rng.randf()) * radius   # sqrt so density is uniform per unit AREA, not per radius
		var pos := cam_pos + Vector3.UP * height + Vector3(cos(a) * d, rng.randf_range(-150.0, 150.0), sin(a) * d)
		var basis := flat.rotated(Vector3.UP, rng.randf() * TAU)
		mm.set_instance_transform(i, Transform3D(basis, pos))
	_mm_inst = MultiMeshInstance3D.new()
	_mm_inst.multimesh = mm
	_mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm_inst.visible = _visible
	add_child(_mm_inst)
