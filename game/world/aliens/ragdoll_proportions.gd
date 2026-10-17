extends SkeletonModifier3D
var hinges: Dictionary={}
func _process_modification() -> void:
	var skeleton=get_skeleton()
	for i in range(skeleton.get_bone_count()):
		skeleton.set_bone_pose_scale(i,Vector3.ONE)
		if String(skeleton.get_bone_name(i)) not in ["Root","Pelvis"]:
			skeleton.set_bone_pose_position(i,skeleton.get_bone_rest(i).origin)
		if hinges.has(i):
			var parent=skeleton.get_bone_parent(i)
			var upper=skeleton.get_bone_global_pose(parent).basis.orthonormalized()
			var lower=skeleton.get_bone_global_pose(i).basis.orthonormalized()
			var axis: Vector3=(upper*hinges[i].axis).normalized()
			var angle=clampf(upper.y.signed_angle_to(lower.y,axis),0,hinges[i].maximum)
			var direction=upper.y.rotated(axis,angle).normalized()
			var global_basis=Basis(axis,direction,axis.cross(direction).normalized()).orthonormalized()
			skeleton.set_bone_pose_rotation(i,(upper.inverse()*global_basis).get_rotation_quaternion())
