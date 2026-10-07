extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena);await process_frame
	var kit=arena.kit;var manager=arena.get_node("PracticeRange");var car=kit.vehicles[0]
	kit.set_physics_process(false);arena.set_physics_process(false)
	for squad in manager.squads:
		squad.set_physics_process(false)
		for unit in squad.members: unit.set_physics_process(false)
	var impacts=car.get_children().filter(func(n): return n.get_script()==preload("res://vehicle_impacts.gd"))[0]
	impacts.set_physics_process(false);car.freeze=true;car.set_physics_process(false);car.global_transform=Transform3D(Basis.IDENTITY,Vector3(-65,10,-20))
	var hull=car.get_node("ChassisCollision")
	assert(hull.shape.size.z>4.3 and hull.shape.size.x>1.5,"Hull must cover the visible chassis")
	var grunt=manager.enemies[1];grunt.position=car.to_global(Vector3(0,0,-2.35))
	car.velocity=Vector3.ZERO;impacts._physics_process(.016);assert(not grunt.dead,"Parked contact must not kill")
	car.velocity=Vector3(0,0,-10);impacts._physics_process(.016)
	assert(grunt.dead and grunt.lizard.ragdoll.is_simulating_physics(),"Forward impact must kill and start physical ragdoll")
	assert(grunt.lizard.ragdoll.get_node("Physics_Pelvis").linear_velocity.z< -5,"Ragdoll must carry impact momentum")
	var elite=manager.enemies[0];elite.position=car.to_global(Vector3(0,0,2.35));car.velocity=Vector3(0,0,8);impacts.previous_velocity=Vector3.ZERO;impacts._physics_process(.016)
	assert(elite.dead,"Reverse impact must kill the captain")
	assert(manager.enemies[2].routed,"Run-over captain death must trigger morale")
	var outside=manager.enemies[2];outside.position=car.to_global(Vector3(4,0,-2));car.velocity=Vector3(0,0,-10);impacts.previous_velocity=Vector3.ZERO;impacts._physics_process(.016);assert(not outside.dead,"Near miss must not kill")
	var wheel=car.corners[0];var victim=manager.enemies[3];victim.position=car.to_global(wheel.hub.position+Vector3(0,-.35,-wheel.radius))
	car.velocity=Vector3(0,0,-10);impacts._physics_process(.016);assert(victim.dead,"Tyre envelope must register outside the hull")
	# Restore the enlarged hull and verify the original suspension still supports it.
	car.global_transform=Transform3D(Basis.IDENTITY,Vector3(-65,2,4));car.velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO;car.freeze=false;car.set_physics_process(true);car.set_controls(0,0,true)
	await create_timer(3).timeout
	assert(car.grounded_count>=3 and car.global_position.y>-.3,"Enlarged hull must still settle on its suspension")
	car.controlled=true;car.set_controls(1,0,false);var start=car.position
	await create_timer(2).timeout;assert(car.position.distance_to(start)>1,"Enlarged hull must still drive")
	# Repeated exits must never let the capsule kick the vehicle or act as suspension ground.
	assert(arena.walker.get_rid() in car.suspension_exclusions)
	kit.set_physics_process(true);car.set_controls(0,0,true);car.controlled=false
	await create_timer(2).timeout
	var peak_exit_speed=0.0
	for cycle in range(8):
		arena.walker.position=car.to_global(Vector3(-3,0,0) if cycle%2==0 else Vector3(0,0,3.5))
		kit.toggle_vehicle();assert(kit.driving==car)
		await create_timer(.12).timeout
		kit.toggle_vehicle();assert(kit.driving==null)
		for step in range(15):
			await physics_frame;peak_exit_speed=maxf(peak_exit_speed,absf(car.linear_velocity.y))
		assert(not arena.walker in car.get_collision_exceptions(),"Exit must restore normal collisions after the handoff")
	assert(peak_exit_speed<2.0,"Exiting must not launch the Warthog")
	print("EXIT_PEAK_VERTICAL_SPEED ",peak_exit_speed)
	var tank=kit.vehicles[1];var tank_impacts=tank.get_children().filter(func(n): return n.get_script()==preload("res://vehicle_impacts.gd"))[0]
	tank_impacts.set_physics_process(false);tank.velocity=Vector3(0,0,-8)
	var target=manager.enemies[5];target.position=tank.to_global(Vector3(0,0,-3.4));tank_impacts._physics_process(.016);assert(target.dead,"Tank must also run enemies over")
	print("PASS: hull coverage, parked safety, forward/reverse kills, ragdoll momentum, morale, near misses, wheel strikes, suspension and driving");quit()
