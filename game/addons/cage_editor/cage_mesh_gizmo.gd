@tool
class_name CageMeshGizmoPlugin
extends EditorNode3DGizmoPlugin

func _init() -> void:
	create_material("wire", Color(1.0, 0.55, 0.1), false, true)
	create_handle_material("handles")

func _get_gizmo_name() -> String:
	return "CageMesh"

func _has_gizmo(node: Node3D) -> bool:
	return node is CageMesh

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var cage := gizmo.get_node_3d() as CageMesh
	if cage.vertices.size() == 0:
		return

	# Wireframe cage edges
	var lines := PackedVector3Array()
	var seen: Dictionary = {}
	for face: PackedInt32Array in cage.faces:
		for i in face.size():
			var a: int = face[i]
			var b: int = face[(i + 1) % face.size()]
			var k := "%d_%d" % [mini(a, b), maxi(a, b)]
			if not seen.has(k):
				seen[k] = true
				lines.append(cage.vertices[a])
				lines.append(cage.vertices[b])
	gizmo.add_lines(lines, get_material("wire", gizmo), false)

	# Vertex handles
	gizmo.add_handles(cage.vertices, get_material("handles", gizmo), [])

func _get_handle_name(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> String:
	return "Vertex %d" % id

func _get_handle_value(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> Variant:
	return (gizmo.get_node_3d() as CageMesh).vertices[id]

func _set_handle(gizmo: EditorNode3DGizmo, id: int, _secondary: bool,
		camera: Camera3D, screen_pos: Vector2) -> void:
	var cage := gizmo.get_node_3d() as CageMesh
	var world_v := cage.global_transform * cage.vertices[id]
	var origin := camera.project_ray_origin(screen_pos)
	var dir    := camera.project_ray_normal(screen_pos)
	var plane  := Plane(camera.global_transform.basis.z, world_v)
	var hit    := plane.intersects_ray(origin, dir)
	if hit:
		cage.vertices[id] = cage.global_transform.affine_inverse() * hit
		cage._rebuild()
		_redraw(gizmo)

func _commit_handle(gizmo: EditorNode3DGizmo, id: int, _secondary: bool,
		restore: Variant, cancel: bool) -> void:
	var cage := gizmo.get_node_3d() as CageMesh
	if cancel:
		cage.vertices[id] = restore
		cage._rebuild()
	_redraw(gizmo)
