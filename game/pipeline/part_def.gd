class_name PartDef
extends Resource

@export var label: String = ""
@export var body_plan: String = "biped"
@export var slot: String = ""
# Target to attach to: a Node3D found by name in the template. A Skeleton3D
# bone is one implementation of a socket (resolved via BoneAttachment3D).
@export var socket: String = ""
@export var mesh: Mesh
@export var offset_position: Vector3 = Vector3.ZERO
@export var offset_rotation_degrees: Vector3 = Vector3.ZERO
@export var offset_scale: Vector3 = Vector3.ONE
@export var thumbnail: Texture2D
