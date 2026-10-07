extends RefCounted
## Preserves the tactical prototype's authored dimensions, openings and furniture.
## Source: first-operation/study.gd build_fob; tactical.gd build_fob/building.
var stone := material(Color(0.34,0.35,0.30))
var metal := material(Color(0.16,0.20,0.22),0.4)
var purple := material(Color(0.59,0.3,0.94),0.0,true)
var dark := material(Color(0.025,0.035,0.05))

static func material(color: Color, metallic := 0.0, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.8
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.6
	return mat

func solid(root: Node3D, position: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = position
	root.add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	mesh.add_child(body)
	body.add_child(shape)

func cylinder(root: Node3D, position: Vector3, radius: float, height: float, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = height
	mesh.mesh = cylinder_mesh
	mesh.material_override = mat
	mesh.position = position
	root.add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	mesh.add_child(body)
	body.add_child(collision)

func label(root: Node3D, title: String, position: Vector3, range_end := 160.0) -> void:
	var node := Label3D.new()
	node.text = title
	node.position = position
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.pixel_size = 0.012
	node.visibility_range_end = range_end
	root.add_child(node)

func fob() -> Node3D:
	var root := Node3D.new()
	root.name = "FriendlyFOB"
	solid(root,Vector3.ZERO,Vector3(18,0.2,20),stone)
	for x in [-8.0,8.0]:
		solid(root,Vector3(x,1,0),Vector3(0.4,2,18),stone)
		for z in [-7.0,6.0]: solid(root,Vector3(x,2.1,z),Vector3(0.5,4.2,0.5),metal)
	solid(root,Vector3(0,4.25,6),Vector3(16.5,0.25,6),metal)
	solid(root,Vector3(0,0.45,0),Vector3(2.3,0.9,1.4),metal)
	solid(root,Vector3(0,0.95,0),Vector3(3.7,0.12,2.8),dark)
	# The old table's route diagram remains a visual, without mission-state input.
	solid(root,Vector3(0,1.12,0),Vector3(3.3,0.02,2.45),purple)
	for point in [Vector3(0,1.2,0.85),Vector3(0,1.2,-0.15),Vector3(-1.05,1.2,-0.9),Vector3(1.05,1.2,-0.9)]:
		cylinder(root,point,0.11,0.045,purple)
	solid(root,Vector3(4,0.7,-6),Vector3(1.3,1.4,0.6),metal)
	solid(root,Vector3(-5,0.45,4),Vector3(2,0.9,0.9),metal)
	label(root,"PLANNING",Vector3(0,2,-0.7),30)
	label(root,"SUPPORT TERMINAL",Vector3(4,1.9,-6),30)
	label(root,"REARM",Vector3(-5,1.9,4),30)
	label(root,"FRIENDLY FOB",Vector3(0,7,0),450)
	return root

func building(root: Node3D, origin: Vector3) -> void:
	solid(root,origin+Vector3(0,-0.1,0),Vector3(12,0.2,14),stone)
	solid(root,origin+Vector3(0,3.3,0),Vector3(12.6,0.3,14.6),metal)
	solid(root,origin+Vector3(0,1.6,-7),Vector3(12,3.2,0.4),stone)
	for x in [-3.5,3.5]: solid(root,origin+Vector3(x,1.6,7),Vector3(5,3.2,0.4),stone)
	solid(root,origin+Vector3(0,2.85,7),Vector3(2,0.7,0.4),stone)
	for x in [-6.0,6.0]:
		solid(root,origin+Vector3(x,0.5,0),Vector3(0.4,1,14),stone)
		solid(root,origin+Vector3(x,2.8,0),Vector3(0.4,0.8,14),stone)
		for z in [-5.5,0.0,5.5]: solid(root,origin+Vector3(x,1.7,z),Vector3(0.4,1.4,3),stone)

func relay() -> Node3D:
	var root := Node3D.new()
	root.name = "RelayCompound"
	# Translate the old compound centre z=-307 to the root; preserve every opening.
	for x in [-20.0,20.0]: solid(root,Vector3(x,1.4,26),Vector3(32,2.8,0.7),stone)
	solid(root,Vector3(-36,1.4,0),Vector3(0.7,2.8,52),stone)
	solid(root,Vector3(0,1.4,-26),Vector3(72,2.8,0.7),stone)
	for z in [16.0,-13.0]: solid(root,Vector3(36,1.4,z),Vector3(0.7,2.8,20),stone)
	building(root,Vector3(-19,0,-2))
	building(root,Vector3(18,0,-8))
	solid(root,Vector3(0,1,7),Vector3(5,2,4),stone)
	cylinder(root,Vector3(0,5,7),0.17,7,metal)
	solid(root,Vector3(0,8,7),Vector3(4,0.5,1),metal)
	solid(root,Vector3(0,8,6.45),Vector3(3.4,0.12,0.08),purple)
	solid(root,Vector3(0,0.8,10.2),Vector3(1.2,1.6,0.6),metal)
	label(root,"RELAY COMPOUND",Vector3(0,11,0),450)
	return root
