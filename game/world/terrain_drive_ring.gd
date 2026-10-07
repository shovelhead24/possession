extends RefCounted
## Shared world/ring conversion for the curved driving terrain and its physics.
const Frame = preload("res://world/ring_frame.gd")

static func point(arc: float, height: float, lateral: float) -> Vector3:
	return Frame.position(arc,height,lateral)

static func coordinates(world_point: Vector3) -> Vector3:
	return Frame.coordinates(world_point)

static func up_at(world_point: Vector3) -> Vector3:
	return Frame.up(coordinates(world_point).x)

static func spinward_at(world_point: Vector3) -> Vector3:
	var arc := coordinates(world_point).x
	return Vector3(cos(arc/(Frame.CIRCUMFERENCE/TAU)),sin(arc/(Frame.CIRCUMFERENCE/TAU)),0)

static func tangent_basis(world_point: Vector3, yaw: float) -> Basis:
	var up := up_at(world_point)
	var basis := Basis(spinward_at(world_point),up,Vector3.FORWARD)
	return Basis(up,yaw)*basis

static func warp_mesh(result: Dictionary) -> void:
	var vertices: PackedVector3Array=result.vertices
	var normals: PackedVector3Array=result.normals
	var radius := Frame.CIRCUMFERENCE/TAU
	for i in vertices.size():
		var flat := vertices[i]
		var theta := flat.x/radius
		var spinward := Vector3(cos(theta),sin(theta),0)
		var up := Vector3(-sin(theta),cos(theta),0)
		vertices[i]=point(flat.x,flat.y,flat.z)
		# The field normal is expressed in the source tangent frame. Rotate its
		# three axes into the same local ring frame as the curved vertex.
		if i<normals.size():
			var normal := normals[i]
			normals[i]=(spinward*normal.x+up*normal.y+Vector3.FORWARD*normal.z).normalized()
	result.vertices=vertices
	result.normals=normals
