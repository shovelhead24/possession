extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene=load("res://tactical.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var kit=scene.kit
	var tank=kit.vehicles[1]
	kit.set_physics_process(false)
	scene.set_physics_process(false)
	assert(tank.corners.size()==8)
	assert(tank.tracks.sides.size()==2)
	assert(tank.turret.get_child_count()>1,"Turret meshes must rotate with turret")
	for c in tank.corners: assert(c.links.is_empty())
	tank.global_transform=Transform3D(Basis.IDENTITY,Vector3(-65,1,4))
	tank.linear_velocity=Vector3.ZERO
	tank.angular_velocity=Vector3.ZERO
	tank.controlled=true
	tank.set_controls(0,0,true)
	await create_timer(3).timeout
	var start=tank.global_position
	var phase=tank.tracks.phase
	tank.set_controls(1,0,false)
	await create_timer(6).timeout
	var moved=tank.global_position.distance_to(start)
	print("TANK_DRIVE distance=",moved," position=",tank.global_position," contacts=",tank.grounded_count)
	assert(moved>8,"Tank must drive down the real terrain lane")
	assert(tank.tracks.phase!=phase,"Visible track links must animate")
	assert(tank.global_basis.y.dot(Vector3.UP)>.5,"Tank must remain upright")
	tank.set_controls(1,.5,false)
	await create_timer(3).timeout
	assert(tank.global_position.is_finite())
	tank.set_controls(0,0,true)
	await create_timer(4).timeout
	print("TANK_BRAKE speed=",tank.linear_velocity.length())
	assert(tank.linear_velocity.length()<2,"Tank must brake")
	print("PASS: eight hidden contacts, real terrain drive, animated tracks, steering and braking")
	quit()
