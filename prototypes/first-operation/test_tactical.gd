extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene=load("res://tactical.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var space=scene.get_world_3d().direct_space_state
	for x in [-32.0,25.0]:
		for z in [-50.0,-90.0,-140.0,-190.0,-240.0,-270.0]:
			var query=PhysicsRayQueryParameters3D.create(Vector3(x,40,z),Vector3(x,-15,z))
			var hit=space.intersect_ray(query)
			assert(not hit.is_empty(),"Missing route collision")
			assert(absf(hit.position.y-scene.height_at(x,z))<0.2,"Rendered/physical terrain diverged")
	# Door is open at body height; adjacent wall blocks the same traversal.
	assert(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-19,1.5,-299),Vector3(-19,1.5,-307))).is_empty(),"Door blocked")
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-23,1.5,-299),Vector3(-23,1.5,-307))).is_empty(),"Wall has no collision")
	assert(scene.height_at(-32,-140)-scene.height_at(25,-140)>10,"Approaches lack vertical separation")
	# A gully hides a standing player from a cross-valley observer on the west slope.
	var observer=Vector3(-60,scene.height_at(-60,-140)+1.65,-140)
	var target=Vector3(25,scene.height_at(25,-140)+1.65,-140)
	assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(observer,target)).is_empty(),"Gully has no terrain concealment")
	for i in range(90): await physics_frame
	assert(scene.walker.is_on_floor(),"Player failed to settle on physical ground")
	print("PASS: route collision matches mesh; door open/wall solid; ridge separation; gully sightline blocked; player grounded")
	quit()
