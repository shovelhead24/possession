extends SceneTree
var scene: Node3D
func _initialize() -> void:
	create_timer(600).timeout.connect(func(): push_error("Stress geometry timed out");quit(1))
	run.call_deferred()

func run() -> void:
	scene=load("res://world/sdf_stress_course.tscn").instantiate();root.add_child(scene)
	while not scene.live_kit() or not scene.far_terrain.finished(): await process_frame
	var space := scene.get_world_3d().direct_space_state
	for station in 12:
		var z := -120.0-station*44.0
		scene.camera.position=Vector3(-14,4,z)
		while not scene.neighborhood_ready(scene.camera.position): await process_frame
		await physics_frame
		var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-14,4,z),Vector3(-14,16,z),1))
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-14,4,z),Vector3(-14,-24,z),1))
		var lane := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-14,4,z+10),Vector3(-14,4,z-10),1))
		if roof.is_empty() or floor_hit.is_empty() or not lane.is_empty():
			push_error("Course collision failed station "+str(station)+" roof="+str(roof)+" floor="+str(floor_hit)+" lane="+str(lane));quit(1);return
		print("STRESS_GEOMETRY_STATION ",station," z=",z," floor=",floor_hit.position.y," roof=",roof.position.y)
		# Inner right-hand curved bore: curve midpoint is displaced by +8m in X.
		var bore := Vector3(38,3,z)
		scene.camera.position=bore
		while not scene.neighborhood_ready(bore): await process_frame
		await physics_frame
		var tunnel := space.intersect_ray(PhysicsRayQueryParameters3D.create(bore-Vector3.UP,bore+Vector3.UP,1))
		if not tunnel.is_empty(): push_error("Curved bore blocked at station "+str(station));quit(1);return
	for tier in 3:
		var z := -150.0-tier*176.0
		scene.camera.position=Vector3(95,65,z+60)
		scene.camera.look_at(Vector3(-14,8,z))
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://stress-tier-%d.png" % (tier+1))
	print("STRESS_GEOMETRY_PASS stations=12 curved_bores=12 direction=-Z");quit()
