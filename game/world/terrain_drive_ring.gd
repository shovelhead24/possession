extends RefCounted
## Shared world/ring conversion for the curved driving terrain and its physics.
const Frame = preload("res://world/ring_frame.gd")
## Cartesian offset is held in scalar doubles, never accumulated in Vector3.
## Cached terrain stays in the original frame; gameplay uses local coordinates.
static var origin_x: float=0.0
static var origin_y: float=0.0
static var origin_z: float=0.0

static func offset() -> Vector3:return Vector3(origin_x,origin_y,origin_z)
static func reset_origin() -> void:
	origin_x=0.0;origin_y=0.0;origin_z=0.0
static func absolute_point(local: Vector3) -> Vector3:
	return Vector3(origin_x+local.x,origin_y+local.y,origin_z+local.z)
static func local_point(absolute: Vector3) -> Vector3:
	return Vector3(float(absolute.x)-origin_x,float(absolute.y)-origin_y,float(absolute.z)-origin_z)

static func point(arc: float, height: float, lateral: float) -> Vector3:
	var radius=Frame.CIRCUMFERENCE/TAU
	var theta=arc/radius;var radial=radius-height
	return Vector3(radial*sin(theta)-origin_x,height+2.0*radial*pow(sin(theta*.5),2.0)-origin_y,lateral-origin_z)

static func coordinates(world_point: Vector3) -> Vector3:
	var radius=Frame.CIRCUMFERENCE/TAU
	var x=origin_x+world_point.x;var y=origin_y+world_point.y
	return Vector3(atan2(x,radius-y)*radius,radius-sqrt(x*x+pow(radius-y,2.0)),origin_z+world_point.z)

static func up_at(world_point: Vector3) -> Vector3:
	return Frame.up(coordinates(world_point).x)

static func spinward_at(world_point: Vector3) -> Vector3:
	var arc := coordinates(world_point).x
	return Vector3(cos(arc/(Frame.CIRCUMFERENCE/TAU)),sin(arc/(Frame.CIRCUMFERENCE/TAU)),0)

static func tangent_basis(world_point: Vector3, yaw: float) -> Basis:
	var up := up_at(world_point)
	# Keep the existing forward heading (+lateral at yaw zero), but use a
	# proper rotation. +spinward/up/-lateral had determinant -1: it reflected
	# the body, driver and camera and reversed local wheel animation rotations.
	var basis := Basis(-spinward_at(world_point),up,Vector3.FORWARD)
	return Basis(up,yaw)*basis

static func tangent_yaw(world_point: Vector3, forward: Vector3) -> float:
	# Recover relative yaw from heading, not Euler angles of the ring-tilted body.
	return atan2(forward.dot(spinward_at(world_point)),forward.z)

static func warp_mesh(result: Dictionary) -> void:
	var vertices: PackedVector3Array=result.vertices
	var normals: PackedVector3Array=result.normals
	var radius := Frame.CIRCUMFERENCE/TAU
	for i in vertices.size():
		var flat := vertices[i]
		var theta := flat.x/radius
		var spinward := Vector3(cos(theta),sin(theta),0)
		var up := Vector3(-sin(theta),cos(theta),0)
		vertices[i]=Frame.position(flat.x,flat.y,flat.z)
		# The field normal is expressed in the source tangent frame. Rotate its
		# three axes into the same local ring frame as the curved vertex.
		if i<normals.size():
			var normal := normals[i]
			normals[i]=(spinward*normal.x+up*normal.y+Vector3.BACK*normal.z).normalized()
	result.vertices=vertices
	result.normals=normals
