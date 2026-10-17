extends RefCounted
## Merge the seven skinned rifle pieces into one mesh with three material surfaces.
## Source vertices, weights, bind poses and materials are retained unchanged.
static func apply(root: Node) -> void:
	var parts: Array[MeshInstance3D]=[]
	for node in root.find_children("*","MeshInstance3D",true,false):
		if not "LizardSkin" in String(node.name): parts.append(node)
	if parts.size()<2: return
	var target=parts[0]
	var groups: Dictionary={}
	for part in parts:
		# This optimization is intentionally restricted to the verified rig layout.
		assert(part.get_parent()==target.get_parent() and part.transform.is_equal_approx(target.transform))
		assert(part.skeleton==target.skeleton and part.skin.get_bind_count()==target.skin.get_bind_count())
		for bind in part.skin.get_bind_count():
			assert(part.skin.get_bind_bone(bind)==target.skin.get_bind_bone(bind))
			assert(part.skin.get_bind_pose(bind).is_equal_approx(target.skin.get_bind_pose(bind)))
		for surface in part.mesh.get_surface_count():
			var material=part.mesh.surface_get_material(surface)
			if not groups.has(material): groups[material]=[]
			groups[material].append([part.mesh,surface])
	var merged=ArrayMesh.new()
	for material in groups:
		var builder=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry in groups[material]: builder.append_from(entry[0],entry[1],Transform3D.IDENTITY)
		builder.set_material(material);builder.commit(merged)
	target.mesh=merged
	for part in parts:
		if part!=target: part.get_parent().remove_child(part);part.free()
