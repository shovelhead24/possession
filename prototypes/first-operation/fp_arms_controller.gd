extends Node3D
class_name FPArmsController

# Controls finger poses for FP arms skeleton
# Attach this script to the FPArms node

var skeleton: Skeleton3D = null

# Bone indices (cached for performance)
var bone_indices: Dictionary = {}

# Finger bone names for left hand
const LEFT_FINGER_BONES = {
	"thumb": ["L_thumb1_04", "L_thumb2_05", "L_thumb3_06"],
	"index": ["L_point1_08", "L_point2_09", "L_point3_010"],
	"middle": ["L_middle1_012", "L_middle2_013", "L_middle3_00"],
	"ring": ["L_ring1_016", "L_ring2_017", "L_ring3_018"],
	"pinky": ["L_pink1_020", "L_pink2_021", "L_pink3_022"]
}

# Finger bone names for right hand
const RIGHT_FINGER_BONES = {
	"thumb": ["R_thumb1_027", "R_thumb2_028", "R_thumb3_029"],
	"index": ["R_point1_031", "R_point2_032", "R_point3_033"],
	"middle": ["R_middle1_035", "R_middle2_036", "R_middle3_037"],
	"ring": ["R_ring1_040", "R_ring2_041", "R_ring3_042"],
	"pinky": ["R_pink1_044", "R_pink2_045", "R_pink3_046"]
}

# Pose presets - rotation angles in degrees for each finger joint
# [base, middle, tip] rotations around X axis (curl)
const POSE_OPEN: Dictionary = {
	"thumb": [0.0, 0.0, 0.0],
	"index": [0.0, 0.0, 0.0],
	"middle": [0.0, 0.0, 0.0],
	"ring": [0.0, 0.0, 0.0],
	"pinky": [0.0, 0.0, 0.0]
}

const POSE_GRIP_CARBINE: Dictionary = {
	"thumb": [-20.0, -30.0, -20.0],  # Thumb wraps around
	"index": [-50.0, -60.0, -45.0],  # Trigger finger - slightly less curled
	"middle": [-70.0, -80.0, -60.0],  # Full grip
	"ring": [-75.0, -85.0, -65.0],   # Full grip
	"pinky": [-80.0, -85.0, -65.0]   # Full grip
}

const POSE_GRIP_RAILGUN: Dictionary = {
	"thumb": [-25.0, -35.0, -25.0],  # Thumb wraps around larger grip
	"index": [-45.0, -55.0, -40.0],  # Trigger finger
	"middle": [-65.0, -75.0, -55.0],  # Full grip
	"ring": [-70.0, -80.0, -60.0],   # Full grip
	"pinky": [-75.0, -80.0, -60.0]   # Full grip
}

func _ready():
	# Find the skeleton in the imported GLTF scene
	find_skeleton(self)

	if skeleton:
		cache_bone_indices()
		# Hide left arm by collapsing its root bone
		var left_arm_idx = skeleton.find_bone("L_arm_01")
		if left_arm_idx >= 0:
			skeleton.set_bone_pose_scale(left_arm_idx, Vector3.ZERO)
		# Start with carbine grip (right hand only)
		apply_pose_to_hand(POSE_GRIP_CARBINE, RIGHT_FINGER_BONES, false)
		print("FPArmsController: Skeleton found with ", skeleton.get_bone_count(), " bones")
	else:
		print("FPArmsController: WARNING - No skeleton found!")

func find_skeleton(node: Node):
	if node is Skeleton3D:
		skeleton = node
		return
	for child in node.get_children():
		find_skeleton(child)
		if skeleton:
			return

func cache_bone_indices():
	if not skeleton:
		return

	# Cache all finger bone indices
	for finger_name in LEFT_FINGER_BONES:
		for bone_name in LEFT_FINGER_BONES[finger_name]:
			var idx = skeleton.find_bone(bone_name)
			if idx >= 0:
				bone_indices[bone_name] = idx

	for finger_name in RIGHT_FINGER_BONES:
		for bone_name in RIGHT_FINGER_BONES[finger_name]:
			var idx = skeleton.find_bone(bone_name)
			if idx >= 0:
				bone_indices[bone_name] = idx

func apply_finger_pose(finger_bones: Array, rotations: Array, is_left: bool):
	if not skeleton:
		return

	for i in range(mini(finger_bones.size(), rotations.size())):
		var bone_name = finger_bones[i]
		if bone_name in bone_indices:
			var bone_idx = bone_indices[bone_name]
			var rest_pose = skeleton.get_bone_rest(bone_idx)

			# Create rotation around local X axis (curl finger)
			var curl_angle = deg_to_rad(rotations[i])
			var curl_rotation = Quaternion(Vector3.RIGHT, curl_angle)

			# Apply rotation to the bone
			var new_transform = rest_pose
			new_transform.basis = Basis(curl_rotation) * rest_pose.basis
			skeleton.set_bone_pose_rotation(bone_idx, new_transform.basis.get_rotation_quaternion())

func apply_pose_to_hand(pose: Dictionary, finger_bones_map: Dictionary, is_left: bool):
	for finger_name in pose:
		if finger_name in finger_bones_map:
			apply_finger_pose(finger_bones_map[finger_name], pose[finger_name], is_left)

func apply_pose_to_both_hands(pose: Dictionary):
	apply_pose_to_hand(pose, LEFT_FINGER_BONES, true)
	apply_pose_to_hand(pose, RIGHT_FINGER_BONES, false)

# Called by player when switching weapons
func set_weapon_pose(weapon_name: String):
	match weapon_name.to_lower():
		"carbine":
			apply_pose_to_hand(POSE_GRIP_CARBINE, RIGHT_FINGER_BONES, false)
		"railgun":
			apply_pose_to_hand(POSE_GRIP_RAILGUN, RIGHT_FINGER_BONES, false)
		"open", "none":
			apply_pose_to_hand(POSE_OPEN, RIGHT_FINGER_BONES, false)
		_:
			apply_pose_to_hand(POSE_GRIP_CARBINE, RIGHT_FINGER_BONES, false)
