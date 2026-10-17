extends RefCounted
static func start(skeleton: Skeleton3D,velocity: Vector3,impulse: Vector3) -> PhysicalBoneSimulator3D:
	var simulator=PhysicalBoneSimulator3D.new();skeleton.add_child(simulator)
	var size_factor=skeleton.get_bone_rest(skeleton.find_bone("Spine")).origin.length()/.25
	var hinges: Dictionary={}
	for index in range(skeleton.get_bone_count()):
		var label=String(skeleton.get_bone_name(index))
		if label in ["Root","Rifle","Muzzle"]: continue
		var bone=preload("res://world/aliens/ragdoll_body.gd").new();bone.name="Physics_"+label.replace(".","_");simulator.add_child(bone);bone.set("bone_name",label)
		var length=.25*size_factor;var children=skeleton.get_bone_children(index)
		if not children.is_empty(): length=skeleton.get_bone_rest(children[0]).origin.length()
		length=clampf(length,.12*size_factor,.55*size_factor)
		var radius=.1
		if label in ["Pelvis","Spine"]: radius=.19
		elif "Thigh" in label: radius=.12
		elif "Tail" in label or "Hand" in label: radius=.06
		elif label=="Head": radius=.16
		radius*=size_factor
		var capsule=CapsuleShape3D.new();capsule.radius=radius;capsule.height=maxf(length,radius*2)
		var shape=CollisionShape3D.new();shape.shape=capsule;bone.add_child(shape)
		bone.body_offset=Transform3D(Basis.IDENTITY,Vector3(0,length*.5,0))
		bone.joint_offset=Transform3D(Basis.IDENTITY,Vector3(0,-length*.5,0))
		bone.mass=7 if label in ["Pelvis","Spine"] else (3 if "Thigh" in label else 1)
		bone.friction=.9;bone.bounce=.02;bone.linear_damp=.9;bone.angular_damp=3.5;bone.collision_layer=8;bone.collision_mask=3;bone.gravity_scale=0
		if "Shin" in label or "Forearm" in label:
			var parent=skeleton.get_bone_parent(index)
			var upper=skeleton.get_bone_global_pose(parent).basis.orthonormalized()
			var lower=skeleton.get_bone_global_pose(index).basis.orthonormalized()
			var axis=upper.y.cross(lower.y)
			if axis.length()<.01: axis=lower.x
			axis=axis.normalized()
			var flex=upper.y.signed_angle_to(lower.y,axis)
			var maximum=deg_to_rad(140 if "Shin" in label else 150)
			hinges[index]={"axis":upper.inverse()*axis,"maximum":maximum}
			var z=lower.inverse()*axis;var x=z.cross(Vector3.UP).normalized()
			if x.length()<.1: x=z.cross(Vector3.RIGHT).normalized()
			bone.joint_offset=Transform3D(Basis(x,z.cross(x).normalized(),z),Vector3(0,-length*.5,0))
			bone.joint_type=PhysicalBone3D.JOINT_TYPE_HINGE
			bone.set("joint_constraints/angular_limit_enabled",true)
			bone.set("joint_constraints/angular_limit_lower",rad_to_deg(-flex))
			bone.set("joint_constraints/angular_limit_upper",rad_to_deg(maximum-flex))
		elif label!="Pelvis":
			bone.joint_type=PhysicalBone3D.JOINT_TYPE_CONE
			bone.set("joint_constraints/swing_span",35 if label in ["Spine","Neck","Head"] else 65)
			bone.set("joint_constraints/twist_span",20)
	simulator.physical_bones_start_simulation()
	# Keep the rendered skeleton rigid even during small solver anchor errors.
	var proportions=preload("res://world/aliens/ragdoll_proportions.gd").new();proportions.hinges=hinges;proportions.name="RagdollProportions";skeleton.add_child(proportions)
	for bone in simulator.get_children():
		bone.linear_velocity=(velocity+impulse+preload("res://world/terrain_drive_ring.gd").up_at(skeleton.global_position)*.6).limit_length(12)
		if "Spine" in String(bone.name): bone.angular_velocity=Vector3(1.5,0,.8)
	return simulator
