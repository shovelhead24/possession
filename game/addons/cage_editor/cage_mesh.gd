@tool
class_name CageMesh
extends Node3D

@export var vertices: PackedVector3Array = PackedVector3Array()
@export var faces: Array = []

@export var subdivision_levels: int = 2:
	set(v):
		subdivision_levels = clampi(v, 0, 4)
		_rebuild()

var selected_face: int = -1
var symmetry: bool = true

var _preview: MeshInstance3D = null

func _ready() -> void:
	_ensure_preview()
	if vertices.size() > 0:
		_rebuild()

func set_template(v: PackedVector3Array, f: Array) -> void:
	vertices = v
	faces = f
	selected_face = -1
	_rebuild()

func _rebuild() -> void:
	_ensure_preview()
	if vertices.size() == 0 or faces.is_empty():
		return
	_preview.mesh = CageSubdivider.subdivide(vertices, faces, subdivision_levels)

func _ensure_preview() -> void:
	if _preview and is_instance_valid(_preview):
		return
	_preview = MeshInstance3D.new()
	_preview.name = "__preview__"
	add_child(_preview)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.78, 0.82)
	mat.roughness = 0.7
	mat.metallic = 0.1
	_preview.material_override = mat

# ── Queries ───────────────────────────────────────────────────────────────────

func face_center(fi: int) -> Vector3:
	var face: PackedInt32Array = faces[fi]
	var c := Vector3.ZERO
	for vi in face:
		c += vertices[vi]
	return c / face.size()

func face_normal(fi: int) -> Vector3:
	var face: PackedInt32Array = faces[fi]
	if face.size() < 3:
		return Vector3.UP
	var a := vertices[face[0]]
	var b := vertices[face[1]]
	var c := vertices[face[2]]
	return (b - a).cross(c - a).normalized()

# Returns mirror vertex index (across X=0) or -1 if none / on centerline.
func mirror_vert(vi: int) -> int:
	var v := vertices[vi]
	if abs(v.x) < 0.001:
		return -1
	for mi in vertices.size():
		if mi == vi:
			continue
		var m := vertices[mi]
		if abs(m.x + v.x) < 0.025 and abs(m.y - v.y) < 0.025 and abs(m.z - v.z) < 0.025:
			return mi
	return -1

# Returns mirror face index (across X=0) or -1 if none / symmetric face.
func mirror_face(fi: int) -> int:
	var c := face_center(fi)
	if abs(c.x) < 0.025:
		return -1
	for mfi in faces.size():
		if mfi == fi:
			continue
		var mc := face_center(mfi)
		if abs(mc.x + c.x) < 0.06 and abs(mc.y - c.y) < 0.06 and abs(mc.z - c.z) < 0.06:
			return mfi
	return -1

# ── Operations ────────────────────────────────────────────────────────────────

func extrude_selected() -> void:
	if selected_face < 0 or selected_face >= faces.size():
		return
	var fi := selected_face
	var mfi := mirror_face(fi) if symmetry else -1
	_extrude_face(fi)
	if mfi >= 0:
		_extrude_face(mfi)
	_rebuild()

func inset_selected(amount: float = 0.25) -> void:
	if selected_face < 0 or selected_face >= faces.size():
		return
	var fi := selected_face
	var mfi := mirror_face(fi) if symmetry else -1
	_inset_face(fi, amount)
	if mfi >= 0:
		_inset_face(mfi, amount)
	_rebuild()

func scale_selected(factor: float) -> void:
	if selected_face < 0 or selected_face >= faces.size():
		return
	_scale_face(selected_face, factor)
	if symmetry:
		var mfi := mirror_face(selected_face)
		if mfi >= 0:
			_scale_face(mfi, factor)
	_rebuild()

# ── Internals ─────────────────────────────────────────────────────────────────

func _extrude_face(fi: int) -> void:
	var face: PackedInt32Array = faces[fi]
	var ns := face.size()
	var new_vis := PackedInt32Array()
	for i in ns:
		new_vis.append(vertices.size())
		vertices.append(vertices[face[i]])
	for i in ns:
		var a: int = face[i]
		var b: int = face[(i + 1) % ns]
		var na: int = new_vis[i]
		var nb: int = new_vis[(i + 1) % ns]
		faces.append(PackedInt32Array([a, b, nb, na]))
	faces[fi] = new_vis

func _inset_face(fi: int, amount: float) -> void:
	var face: PackedInt32Array = faces[fi]
	var ns := face.size()
	var center := Vector3.ZERO
	for vi in face:
		center += vertices[vi]
	center /= ns
	var inner := PackedInt32Array()
	for vi in face:
		inner.append(vertices.size())
		vertices.append(vertices[vi].lerp(center, amount))
	for i in ns:
		var a: int = face[i]
		var b: int = face[(i + 1) % ns]
		var ia: int = inner[i]
		var ib: int = inner[(i + 1) % ns]
		faces.append(PackedInt32Array([a, b, ib, ia]))
	faces[fi] = inner

func _scale_face(fi: int, factor: float) -> void:
	var face: PackedInt32Array = faces[fi]
	var center := Vector3.ZERO
	for vi in face:
		center += vertices[vi]
	center /= face.size()
	for vi in face:
		vertices[vi] = center + (vertices[vi] - center) * factor
