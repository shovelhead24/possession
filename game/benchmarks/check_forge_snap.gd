extends SceneTree
const Parts=preload("res://world/forge_parts.gd")
func _initialize():
	var target=Transform3D(Basis.from_euler(Vector3(.2,.4,.1)),Vector3(4,2,3))
	var moving=Basis.from_euler(Vector3(.5,.8,.3))
	for axis in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]:
		var n=target.basis*axis
		var centre=Parts.face_center(target,Vector3(4,3,2),n)
		var result=Parts.snap_face(target,Vector3(4,3,2),moving,Vector3(2,5,3),n,centre,true)
		assert(result.basis.is_equal_approx(moving))
		assert(Parts.face_center(result,Vector3(2,5,3),-n).is_equal_approx(centre))
		var aimed=centre+target.basis*(Vector3.UP if abs(axis.y)<.5 else Vector3.RIGHT)*.4
		result=Parts.snap_face(target,Vector3(4,3,2),moving,Vector3(2,5,3),n,aimed)
		assert(result.basis.is_equal_approx(moving))
		assert((result.origin-n*Parts.support(moving,Vector3(2,5,3),n)).is_equal_approx(aimed))
	var size=Vector3(4,2,6)
	var target_pose=Transform3D.IDENTITY
	var pose=Parts.snap_face(target_pose,size,Basis.IDENTITY,Vector3(2,1,2),Vector3.UP,Vector3(.3,1,.2))
	var edge=Parts.snap_edge(target_pose,size,pose,Vector3(2,1,2),Vector3.UP,Vector3(0,5,10))
	assert(not edge.is_empty() and edge.a.z==3 and edge.b.z==3)
	assert(is_equal_approx(edge.pose.origin.z,2) and edge.pose.basis==pose.basis)
	var reversed=Parts.snap_edge(target_pose,size,pose,Vector3(2,1,2),Vector3.UP,Vector3(0,5,-10))
	assert(is_equal_approx(reversed.pose.origin.z,-2))
	pose.origin.x=20
	assert(Parts.snap_edge(target_pose,size,pose,Vector3(2,1,2),Vector3.UP,Vector3(0,5,10)).is_empty())
	assert(Parts.boxes_overlap(Transform3D.IDENTITY,Vector3.ONE,Transform3D(Basis(Vector3.UP,.4),Vector3(.7,0,0)),Vector3.ONE))
	assert(not Parts.boxes_overlap(Transform3D.IDENTITY,Vector3.ONE,Transform3D(Basis(Vector3.UP,.4),Vector3(4,0,0)),Vector3.ONE))
	var world=preload("res://world/forge_world.gd").new()
	var record=world.store.make("block",Transform3D.IDENTITY)
	world.store.records=[record];world.reindex()
	var candidate=world.overlapping_snap_target(Transform3D(Basis.IDENTITY,Vector3(1.4,0,0)),Vector3.ONE,[],Vector3(5,4,5))
	assert(not candidate.is_empty() and candidate.id==record.id)
	assert(world.overlapping_snap_target(Transform3D.IDENTITY,Vector3.ONE,[record.id],Vector3(5,4,5)).is_empty())
	world.free()
	print("PASS: six faces, preserved rotations, centre coincidence, aimed surface placement, camera-nearest edge and overlap gate")
	quit()

