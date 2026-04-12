extends Node3D
# Spawns the ancient monolith gateway near spawn — two massive rectangular blocks
# flanking a passage, Forerunner-style (see design references/ancient structure.jpg)

# Gateway center in world space — 120m in front of player spawn
@export var gateway_center: Vector3 = Vector3(0, 0, -120)
# Gap between inner faces of the two monoliths
@export var gateway_width: float = 55.0
# Each monolith dimensions (width, height, depth)
@export var monolith_size: Vector3 = Vector3(38, 180, 38)

func _ready():
	_build()

func _build():
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.68, 0.66, 0.63)  # Pale grey ancient stone
	mat.roughness = 0.88
	mat.metallic = 0.0

	# Monolith centers — half-gap + half-width from gateway centre
	var half_span = (gateway_width + monolith_size.x) * 0.5

	# Base sits at Y=-60 so even on low terrain the blocks tower out of the ground
	var base_y = gateway_center.y - 60.0
	var center_y = base_y + monolith_size.y * 0.5

	_add_monolith(Vector3(gateway_center.x - half_span, center_y, gateway_center.z),
				  monolith_size, mat)
	_add_monolith(Vector3(gateway_center.x + half_span, center_y, gateway_center.z),
				  monolith_size, mat)

func _add_monolith(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	add_child(body)

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
	body.add_child(col)
