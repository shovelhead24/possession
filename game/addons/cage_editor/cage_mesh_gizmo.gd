@tool
class_name CageMeshGizmoPlugin
extends EditorNode3DGizmoPlugin

var _drag_id: int = -2        # vertex id being dragged (-2 = none)
var _drag_mirror: int = -1    # mirror vertex of _drag_id

var _face_drag_id: int = -1           # face id being dragged
var _face_drag_origins: Array = []    # Array[Vector3] — original vert positions
var _face_drag_center: Vector3        # original face center in local space
var _face_drag_mirror_id: int = -1
var _face_drag_mirror_origins: Array = []

func _init() -> void:
	create_material("wire", Color(1.0, 0.55, 0.1), false, true)
	create_material("wire_sel", Color(0.2, 1.0, 0.45), false, true)
	create_handle_material("handles")
	create_handle_material("face_handles")

func _get_gizmo_name() -> String:
	return "CageMesh"

func _has_gizmo(node: Node3D) -> bool:
	return node is CageMesh

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var cage := gizmo.get_node_3d() as CageMesh
	if cage.vertices.size() == 0:
		return

	# Build selected-face edge set for highlight
	var sel_edges: Dictionary = {}
	if cage.selected_face >= 0 and cage.selected_face < cage.faces.size():
		var sf: PackedInt32Array = cage.faces[cage.selected_face]
		for i in sf.size():
			var a: int = sf[i]
			var b: int = sf[(i + 1) % sf.size()]
			sel_edges["%d_%d" % [mini(a, b), maxi(a, b)]] = true

	var lines := PackedVector3Array()
	var sel_lines := PackedVector3Array()
	var seen: Dictionary = {}
	for face: PackedInt32Array in cage.faces:
		for i in face.size():
			var a: int = face[i]
			var b: int = face[(i + 1) % face.size()]
			var k := "%d_%d" % [mini(a, b), maxi(a, b)]
			if not seen.has(k):
				seen[k] = true
				if sel_edges.has(k):
					sel_lines.append(cage.vertices[a])
					sel_lines.append(cage.vertices[b])
				else:
					lines.append(cage.vertices[a])
					lines.append(cage.vertices[b])

	if lines.size() > 0:
		gizmo.add_lines(lines, get_material("wire", gizmo), false)
	if sel_lines.size() > 0:
		gizmo.add_lines(sel_lines, get_material("wire_sel", gizmo), false)

	# Vertex handles (primary)
	gizmo.add_handles(cage.vertices, get_material("handles", gizmo), [], false, false)

	# Face centroid handles (secondary)
	var face_centers := PackedVector3Array()
	for fi in cage.faces.size():
		face_centers.append(cage.face_center(fi))
	gizmo.add_handles(face_centers, get_material("face_handles", gizmo), [], false, true)

func _get_handle_name(_gizmo: EditorNode3DGizmo, id: int, secondary: bool) -> String:
	return "Face %d" % id if secondary else "Vertex %d" % id

func _get_handle_value(gizmo: EditorNode3DGizmo, id: int, secondary: bool) -> Variant:
	var cage := gizmo.get_node_3d() as CageMesh
	if secondary:
		# Return original vert positions of the face so we can restore on cancel
		var arr: Array = []
		for vi: int in (cage.faces[id] as PackedInt32Array):
			arr.append(cage.vertices[vi])
		return arr
	return cage.vertices[id]

func _set_handle(gizmo: EditorNode3DGizmo, id: int, secondary: bool,
		camera: Camera3D, screen_pos: Vector2) -> void:
	var cage := gizmo.get_node_3d() as CageMesh

	if secondary:
		# Face drag — select on first touch, move all verts
		if _face_drag_id != id:
			_face_drag_id = id
			cage.selected_face = id
			_face_drag_center = cage.face_center(id)
			_face_drag_origins.clear()
			for vi: int in (cage.faces[id] as PackedInt32Array):
				_face_drag_origins.append(cage.vertices[vi])
			# Symmetry: cache mirror face
			_face_drag_mirror_id = cage.mirror_face(id) if cage.symmetry else -1
			_face_drag_mirror_origins.clear()
			if _face_drag_mirror_id >= 0:
				for vi: int in (cage.faces[_face_drag_mirror_id] as PackedInt32Array):
					_face_drag_mirror_origins.append(cage.vertices[vi])

		var world_c := cage.global_transform * _face_drag_center
		var hit := Plane(camera.global_transform.basis.z, world_c).intersects_ray(
				camera.project_ray_origin(screen_pos),
				camera.project_ray_normal(screen_pos))
		if hit:
			var local_hit: Vector3 = cage.global_transform.affine_inverse() * hit
			var delta := local_hit - _face_drag_center
			var face: PackedInt32Array = cage.faces[id]
			for i in face.size():
				cage.vertices[face[i]] = _face_drag_origins[i] + delta
			if _face_drag_mirror_id >= 0:
				var mface: PackedInt32Array = cage.faces[_face_drag_mirror_id]
				var mdelta := Vector3(-delta.x, delta.y, delta.z)
				for i in mface.size():
					cage.vertices[mface[i]] = _face_drag_mirror_origins[i] + mdelta
			cage._rebuild()
			_redraw(gizmo)
		return

	# Vertex drag — cache mirror on first touch
	if _drag_id != id:
		_drag_id = id
		_drag_mirror = cage.mirror_vert(id) if cage.symmetry else -1

	var world_v := cage.global_transform * cage.vertices[id]
	var hit := Plane(camera.global_transform.basis.z, world_v).intersects_ray(
			camera.project_ray_origin(screen_pos),
			camera.project_ray_normal(screen_pos))
	if hit:
		var local_hit: Vector3 = cage.global_transform.affine_inverse() * hit
		cage.vertices[id] = local_hit
		if _drag_mirror >= 0:
			cage.vertices[_drag_mirror] = Vector3(-local_hit.x, local_hit.y, local_hit.z)
		cage._rebuild()
		_redraw(gizmo)

func _commit_handle(gizmo: EditorNode3DGizmo, id: int, secondary: bool,
		restore: Variant, cancel: bool) -> void:
	var cage := gizmo.get_node_3d() as CageMesh

	if secondary:
		_face_drag_id = -1
		_face_drag_mirror_id = -1
		if cancel:
			var arr: Array = restore
			var face: PackedInt32Array = cage.faces[id]
			for i in face.size():
				cage.vertices[face[i]] = arr[i]
			cage._rebuild()
		_redraw(gizmo)
		return

	_drag_id = -2
	_drag_mirror = -1
	if cancel:
		cage.vertices[id] = restore
		cage._rebuild()
	_redraw(gizmo)
