extends RefCounted
static func start(skeleton: Skeleton3D,velocity: Vector3,impulse: Vector3) -> PhysicalBoneSimulator3D:
	var simulator=PhysicalBoneSimulator3D.new();skeleton.add_child(simulator)
	for index in range(skeleton.get_bone_count()):
		var label=String(skeleton.get_bone_name(index))
		if label in ["Root","Rifle","Muzzle"]: continue
		var bone=PhysicalBone3D.new();bone.name="Physics_"+label.replace(".","_");simulator.add_child(bone);bone.set("bone_name",label)
		var length=.25;var children=skeleton.get_bone_children(index)
		if not children.is_empty(): length=skeleton.get_bone_rest(children[0]).origin.length()
		length=clampf(length,.12,.55)
		var radius=.1
		if label in ["Pelvis","Spine"]: radius=.19
		elif "Thigh" in label: radius=.12
		elif "Tail" in label or "Hand" in label: radius=.06
		elif label=="Head": radius=.16
		var capsule=CapsuleShape3D.new();capsule.radius=radius;capsule.height=maxf(length,radius*2)
		var shape=CollisionShape3D.new();shape.shape=capsule;bone.add_child(shape)
		bone.body_offset=Transform3D(Basis.IDENTITY,Vector3(0,length*.5,0))
		bone.joint_offset=Transform3D(Basis.IDENTITY,Vector3(0,-length*.5,0))
		bone.mass=7 if label in ["Pelvis","Spine"] else (3 if "Thigh" in label else 1)
		bone.friction=.9;bone.bounce=.05;bone.linear_damp=.5;bone.angular_damp=2;bone.collision_layer=4;bone.collision_mask=1
		bone.joint_type=PhysicalBone3D.JOINT_TYPE_CONE if label!="Pelvis" else PhysicalBone3D.JOINT_TYPE_NONE
		if label!="Pelvis":
			bone.set("joint_constraints/swing_span",35 if label in ["Spine","Neck","Head"] else 65)
			bone.set("joint_constraints/twist_span",25 if "Shin" in label or "Forearm" in label else 45)
	simulator.physical_bones_start_simulation()
	for bone in simulator.get_children():
		bone.linear_velocity=velocity+impulse+Vector3.UP*.6
		if "Spine" in String(bone.name): bone.angular_velocity=Vector3(1.5,0,.8)
	return simulator
