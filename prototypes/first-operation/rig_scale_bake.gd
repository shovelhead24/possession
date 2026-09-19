extends RefCounted
# PhysicalBone3D expects unscaled world-space bodies. Bake uniform import/actor scale
# into vertices, bind poses, joint translations and animation keys before simulation.
static func apply(root: Node3D, factor: float) -> void:
	var stack: Array=[[root,factor]]
	while not stack.is_empty():
		var entry=stack.pop_back();var node: Node=entry[0];var inherited: float=entry[1]
		var scale=inherited
		if node is Node3D:
			scale*=node.scale.x
			node.position*=inherited;node.basis=node.basis.orthonormalized()
		if node is Skeleton3D:
			for i in range(node.get_bone_count()):
				var rest: Transform3D=node.get_bone_rest(i);rest.origin*=scale;node.set_bone_rest(i,rest)
				node.set_bone_pose_position(i,node.get_bone_pose_position(i)*scale)
		if node is MeshInstance3D:
			var mesh=ArrayMesh.new()
			for i in range(node.mesh.get_surface_count()):
				var arrays=node.mesh.surface_get_arrays(i);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				for j in range(vertices.size()): vertices[j]*=scale
				arrays[Mesh.ARRAY_VERTEX]=vertices;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(i,node.mesh.surface_get_material(i))
			node.mesh=mesh
			if node.skin:
				node.skin=node.skin.duplicate()
				for i in range(node.skin.get_bind_count()):
					var bind: Transform3D=node.skin.get_bind_pose(i);bind.origin*=scale;node.skin.set_bind_pose(i,bind)
		if node is AnimationPlayer:
			# Every animated translation in this asset targets its single skeleton.
			for name in node.get_animation_list():
				var animation=node.get_animation(name)
				for track in range(animation.get_track_count()):
					if animation.track_get_type(track)==Animation.TYPE_POSITION_3D:
						for key in range(animation.track_get_key_count(track)):
							animation.track_set_key_value(track,key,animation.track_get_key_value(track,key)*(1.3/2.4)*factor)
		for child in node.get_children(): stack.append([child,scale])
