extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena);await process_frame
	var kit=arena.kit;var car=kit.vehicles[0];var tank=kit.vehicles[1]
	assert(kit.reload_audio.stream.data.size()>1000)
	await create_timer(3).timeout
	kit.set_physics_process(false);arena.set_physics_process(false)
	var old_power=car.front_power_percent;var old_brake=car.front_brake_percent
	car.controlled=true;car.set_controls(1,0,true);car.front_power_percent=100;car.front_brake_percent=0;car._physics_process(.016)
	for c in car.corners:
		assert(c.drive_allocation==(car.engine_force*2 if c.front else 0))
		assert(c.brake_allocation==(0 if c.front else car.brake_strength*2))
	car.front_power_percent=old_power;car.front_brake_percent=old_brake
	car.set_controls(0,0,true);car.controlled=false
	var dirt=car.get_node("WheelDirt")
	car.linear_velocity=Vector3(0,0,-8);dirt._process(.016);assert(dirt.emitters[0].emitting)
	for c in car.corners: c.grounded=false
	dirt._process(.016)
	for p in dirt.emitters: assert(not p.emitting,"No dust while airborne")
	kit.driving=tank;kit.menu=kit.tank_menu
	tank.position=Vector3(-90,3,30);kit.driver_look=Vector2(.7,.1);tank._process(1)
	assert(tank.turret.rotation.y>.5 and tank.barrel.rotation.x>0)
	tank.set_process(false);tank.turret.rotation.y=0;tank.barrel.rotation.x=0
	var target=StaticBody3D.new();target.set_meta("target_hits",0);var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,2,1);shape.shape=box;target.add_child(shape);arena.add_child(target)
	target.position=tank.barrel.global_position-Vector3(0,0,15)
	await physics_frame;await physics_frame
	assert(tank.fire_cannon());assert(target.get_meta("target_hits")==1);assert(not tank.fire_cannon(),"Cannon reload must block repeats")
	var wall=StaticBody3D.new();var wall_shape=CollisionShape3D.new();wall_shape.shape=box;wall.add_child(wall_shape);arena.add_child(wall);wall.position=tank.barrel.global_position-Vector3(0,0,2)
	await physics_frame;await physics_frame
	tank.cooldown=0;tank.fire_cannon();assert(target.get_meta("target_hits")==1,"Breech ray must stop at nearby cover")
	wall.queue_free();target.queue_free()
	if OS.get_cmdline_user_args().has("--pictures"):
		kit.overlay.hide();tank.position=Vector3(-29,1,9);tank.turret.rotation.y=.7;tank.barrel.rotation.x=.15
		arena.camera.position=Vector3(-23,5,1);arena.camera.look_at(tank.position+Vector3.UP*1.7)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/tank-turret.png")
		kit.menu.set_open(true)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/tank-menu.png")
		kit.menu.set_open(false);kit.driving=car;kit.menu=kit.warthog_menu
		car.controlled=true;car.set_controls(.7,0,false);car.linear_velocity=Vector3(0,0,-8)
		arena.camera.position=car.position+Vector3(5,2,5);arena.camera.look_at(car.position+Vector3.UP)
		await create_timer(.35).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/wheel-dirt.png")
	print("PASS: axle splits, dust contact gating, reload audio, tank aiming, cannon hit/reload/cover")
	quit()
