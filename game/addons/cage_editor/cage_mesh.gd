@tool
class_name CageMesh
extends Node3D

@export var vertices: PackedVector3Array = PackedVector3Array()
@export var faces: Array = []

@export var subdivision_levels: int = 2:
	set(v):
		subdivision_levels = clampi(v, 0, 4)
		_rebuild()

var _preview: MeshInstance3D = null

func _ready() -> void:
	_ensure_preview()
	if vertices.size() > 0:
		_rebuild()

func set_template(v: PackedVector3Array, f: Array) -> void:
	vertices = v
	faces = f
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
	# No owner set — won't be serialised with the scene
	add_child(_preview)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.78, 0.82)
	mat.roughness = 0.7
	mat.metallic = 0.1
	_preview.material_override = mat
