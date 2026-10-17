extends SkeletonModifier3D
const Ring=preload("res://world/terrain_drive_ring.gd")

# Applied after AnimationPlayer and discarded by Skeleton3D after skinning:
# corrections never feed back into the next frame's authored leg pose.
var actor: Node3D
var legs: Array=[]
var last_feet: Array[Vector3]=[]
var last_targets: Array[Vector3]=[]
var last_head := Vector3.ZERO
var last_head_pose := Transform3D.IDENTITY
var has_pose := false
var ground_up := Vector3.UP
var source_foot_heights: Array=[]
var settle_weight := 0.0
var mouth_bones: Array[int]=[]
var last_mouth := Vector3.ZERO
var neck_bone := -1
var jaw_bone := -1
var spine_bone := -1

func setup(owner_actor: Node3D) -> void:
	actor=owner_actor
	var rig=get_skeleton()
	neck_bone=rig.find_bone("jt_Neck1_C_05");jaw_bone=rig.find_bone("jt_Jaw_C_09")
	spine_bone=rig.find_bone("jt_Spine1_C_03")
	for bone_name in ["jt_Tongue1_C_010","jt_Tongue2_C_011"]:
		mouth_bones.append(rig.find_bone(bone_name))
	for names in [["jt_Ankle_R_00","jt_Knee_R_040","jt_Thigh_R_039","jt_Foot_R_041"],
		["jt_Ankle_L_052","jt_Knee_L_051","jt_Thigh_L_050","jt_Foot_L_053"]]:
		var indices: Array[int]=[]
		for bone_name in names: indices.append(rig.find_bone(bone_name))
		if not indices.has(-1): legs.append(indices)

func support(point: Vector3) -> Vector3:
	return actor.surface_point(point,0.0)

func surface_normal(point: Vector3,span: float=1.0) -> Vector3:
	var up=Ring.up_at(point);var basis=Ring.tangent_basis(point,0)
	var x=(support(point+basis.x*span)-support(point-basis.x*span)).normalized()
	var z=(support(point+basis.z*span)-support(point-basis.z*span)).normalized()
	var normal=z.cross(x).normalized()
	return normal if normal.dot(up)>.35 else up

func bone_world(rig: Skeleton3D,index: int) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(index).origin)

func _process_modification() -> void:
	if not is_instance_valid(actor) or not actor.runtime_active or legs.size()!=2 or actor.root_bone<0: return
	var rig=get_skeleton()
	var feet: Array[Vector3]=[]
	for leg in legs: feet.append(bone_world(rig,leg[3]))
	var up=Ring.up_at(actor.global_position)
	source_foot_heights=[(feet[0]-actor.global_position).dot(up),(feet[1]-actor.global_position).dot(up)]
	var pivot=(feet[0]+feet[1])*.5
	pivot-=up*(pivot-actor.global_position).dot(up)
	# Fit across the footprint rather than following every tiny ground ripple.
	ground_up=surface_normal(pivot,2.5)
	var tilt=Quaternion(up,ground_up)
	var rotation=Basis(tilt)
	var pivot_support=actor.surface_point(pivot,.05)
	var correction=Transform3D(rotation,pivot_support-rotation*pivot)
	var root_pose=rig.global_transform*rig.get_bone_global_pose(actor.root_bone)
	rig.set_bone_global_pose(actor.root_bone,rig.global_transform.affine_inverse()*correction*root_pose)
	var attack=actor.attack_pose()
	for item in [[spine_bone,attack.x*.35,attack.y*.25],[neck_bone,attack.x,attack.y],[jaw_bone,-attack.z,0.0]]:
		if item[0]<0 or (absf(item[1])<.00001 and absf(item[2])<.00001): continue
		var world_pose=rig.global_transform*rig.get_bone_global_pose(item[0])
		world_pose.basis=Basis(actor.global_basis.y,item[2])*Basis(actor.global_basis.x,item[1])*world_pose.basis
		rig.set_bone_global_pose(item[0],rig.global_transform.affine_inverse()*world_pose)
	last_feet.clear();last_targets.clear()
	for side in legs.size():
		var leg: Array=legs[side]
		var foot: int=leg[3]
		var target=bone_world(rig,foot)
		# A raised foot takes a short settling step under its hip. Already-planted
		# feet retain their authored horizontal placement instead of sliding in.
		var landing=bone_world(rig,leg[2])-actor.global_basis.z*.5
		var settle_step=settle_weight*smoothstep(.8,1.4,source_foot_heights[side])
		target+=(landing-target).slide(up)*settle_step
		# Preserve authored sole thickness and swing height. Only the terrain
		# beneath each foot changes; airborne feet must not be glued to the floor.
		var foot_normal=surface_normal(target)
		# Clearance is perpendicular to the sole, not vertical. On a 45-degree
		# slope its vertical equivalent is larger, otherwise toes sink downhill.
		var clearance=lerpf(maxf(.55,source_foot_heights[side]),.66,settle_weight)
		target=support(target)+up*clearance/maxf(.35,foot_normal.dot(up))
		if side==0 and actor.attack_kind==3 and actor.bite_time>0 and actor.attack_elapsed()>=1.25 and actor.attack_elapsed()<2.4:
			target=support(actor.stomp_point)+up*(.66+actor.stomp_lift())
		var foot_pose=rig.get_bone_global_pose(foot)
		var foot_world_basis=rig.global_basis*foot_pose.basis
		foot_world_basis=Basis(Quaternion(ground_up,foot_normal))*foot_world_basis
		# The existing CCD bends the leg; this is not a root teleport or leg stretch.
		var local_target=rig.to_local(target)
		# Three-joint CCD follows this digitigrade rig's existing bend, keeping
		# all segment lengths intact (no stretched/shrunken legs).
		for iteration in (20 if settle_weight>0.01 else 10):
			if bone_world(rig,foot).distance_to(target)<.015: break
			for joint in leg.slice(0,3):
				var pose=rig.get_bone_global_pose(joint)
				var current=rig.get_bone_global_pose(foot).origin-pose.origin
				var wanted=local_target-pose.origin
				if current.length_squared()<.000001 or wanted.length_squared()<.000001: continue
				var turn=Quaternion(current.normalized(),wanted.normalized())
				pose.basis=Basis(turn)*pose.basis
				rig.set_bone_global_pose(joint,pose)
		foot_pose=rig.get_bone_global_pose(foot)
		foot_pose.basis=rig.global_basis.inverse()*foot_world_basis
		rig.set_bone_global_pose(foot,foot_pose)
		last_feet.append(bone_world(rig,foot));last_targets.append(target)
	if actor.head_bone>=0:
		last_head_pose=rig.global_transform*rig.get_bone_global_pose(actor.head_bone)
		last_head=last_head_pose.origin
		has_pose=true
	if mouth_bones.size()==2 and not mouth_bones.has(-1):
		var tongue_base=bone_world(rig,mouth_bones[0]);var tongue_tip=bone_world(rig,mouth_bones[1])
		last_mouth=tongue_tip+(tongue_tip-tongue_base).normalized()*.35
		actor.update_attack_attachment()
