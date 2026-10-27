extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
const Origin=preload("res://world/performance_floating_origin.gd")
const Forge=preload("res://world/forge_store.gd")
func _initialize():run.call_deferred()
func run():
	Ring.reset_origin()
	var scene=Node3D.new();root.add_child(scene)
	var service=Origin.new();scene.add_child(service);service.setup(scene);service.enabled=false
	var car=RigidBody3D.new();car.freeze=true;scene.add_child(car)
	var camera=Camera3D.new();scene.add_child(camera)
	var effect=MeshInstance3D.new();camera.add_child(effect);effect.position=Vector3(0,0,-1)
	var point=Ring.point(-809197.144,1622.0,-8685.961)
	car.position=point;car.basis=Ring.tangent_basis(point,0);camera.position=point+car.basis.y*4
	car.linear_velocity=Vector3(2,3,4);car.angular_velocity=Vector3(.1,.2,.3)
	var velocity=car.linear_velocity;var spin=car.angular_velocity;var basis=car.basis
	var ring_before=Ring.coordinates(car.position);var eye=camera.position-car.position
	var store=Forge.new();var record=store.make("wall",car.transform)
	var saved=JSON.stringify(record)
	service.rebase(point)
	assert(car.position.length()<1)
	assert(Ring.coordinates(car.position).distance_to(ring_before)<.15)
	assert(car.linear_velocity==velocity and car.angular_velocity==spin and car.basis==basis)
	assert((camera.position-car.position).distance_to(eye)<.001)
	assert(effect.position==Vector3(0,0,-1),"Camera child must not shift twice")
	assert(Forge.pose(record).origin.distance_to(car.position)<.15)
	assert(JSON.stringify(record)==saved,"Persistent placement records must not change")
	var local=car.position
	car.position+=Vector3(0,.001,0)
	assert(absf(car.position.y-local.y-.001)<.00001,"Millimetre movement must survive")
	for delta in [Vector3(256,0,0),Vector3(-512,128,64),Vector3(256,-128,-64)]:service.rebase(delta)
	assert(car.position.distance_to(local+Vector3(0,.001,0))<.0001)
	for path in ["performance_demo.gd","terrain_drive_stream.gd","terrain_drive_destruction.gd","tree_patch.gd","forge_world.gd","actor_world.gd","aliens/manager.gd","aliens/trex.gd","aliens/trex_grounding.gd","performance_rain.gd","sky_cached_billboards.gd"]:
		assert(load("res://world/"+path)!=null)
	print("FLOATING_ORIGIN_TEST_PASS coordinates, velocity, hierarchy, save record, millimetre motion, repeated shifts")
	quit()
