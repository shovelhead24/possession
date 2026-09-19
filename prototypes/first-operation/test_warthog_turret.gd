extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var clock=preload("res://warthog_turret.gd").new()
	assert(clock.advance_trigger(.99,true)==0,"Cold turret must wait one second")
	assert(clock.advance_trigger(.011,true)==1,"Cold delay must end at one second")
	var early=0;var late=0
	for i in range(60): early+=clock.advance_trigger(1.0/60,true)
	for i in range(120): clock.advance_trigger(1.0/60,true)
	for i in range(60): late+=clock.advance_trigger(1.0/60,true)
	assert(late>early and late>=14 and late<=16,"Rate must ramp and settle at 900 RPM")
	for i in range(600): assert(clock.advance_trigger(.1,true)>0,"Sustained firing must not overheat")
	clock.bloom=1
	for i in range(1000): assert(rad_to_deg(clock.cone_direction(Vector3.FORWARD).angle_to(Vector3.FORWARD))<=2.001)
	clock.advance_trigger(3,false);assert(clock.spin==0 and clock.spread_degrees()==.2)
	clock.free()
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena);await process_frame
	var kit=arena.kit;var vehicle=kit.vehicles[0];var turret=kit.warthog_turret
	for squad in arena.get_node("PracticeRange").squads:
		squad.set_physics_process(false)
		for unit in squad.members: unit.set_physics_process(false)
	await create_timer(1).timeout
	arena.walker.global_position=vehicle.to_global(Vector3(0,0,3.5));kit.toggle_vehicle()
	assert(kit.gunning and kit.driving==vehicle,"E at rear must select gunner")
	await physics_frame;await physics_frame
	assert(not vehicle.controlled,"Gunner must not drive")
	kit.driver_look=Vector2(.7,.15);await physics_frame;await physics_frame
	assert(abs(turret.yaw.rotation.y-.7)<.001 and abs(turret.pitch.rotation.x-.15)<.001,"Mouse aim must move turret")
	var target=StaticBody3D.new();target.set_meta("target_hits",0);arena.add_child(target)
	target.position=arena.camera.global_position-arena.camera.global_basis.z*25
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3.ONE*8;collision.shape=box;target.add_child(collision)
	for mode in [0,1]:
		kit.warthog_menu.settings.camera_mode=mode;turret.update_camera()
		target.position=arena.camera.global_position-arena.camera.global_basis.z*25
		await physics_frame;await physics_frame
		var before=int(target.get_meta("target_hits"));turret.fire_round()
		assert(target.get_meta("target_hits")==before+1,"Both chase and first-person must hit the crosshair target")
	for i in range(30): turret.fire_round()
	assert(turret.spread_degrees()==2.0,"Continuous rounds must reach and cap spread")
	target.queue_free()
	if OS.get_cmdline_user_args().has("--pictures"):
		kit.set_physics_process(false);turret.set_physics_process(false)
		for mode in [0,1]:
			kit.warthog_menu.settings.camera_mode=mode;turret.update_camera()
			await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/turret-view-%d.png" % mode)
		arena.camera.position=vehicle.to_global(Vector3(6,4,6));arena.camera.look_at(turret.yaw.global_position+Vector3.UP*.5)
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/warthog-turret.png")
		for angle in [-PI/6,0.0,PI/6]:
			kit.driver_look=Vector2(0,angle);turret.pitch.rotation.x=angle;turret.yaw.rotation.y=0;turret.crouch=(angle+PI/6)/(PI/3)
			turret.pose_player.seek(turret.crouch*turret.pose_player.get_animation(turret.crouch_clip).length,true)
			for mode in [0,1]:
				kit.warthog_menu.settings.camera_mode=mode;turret.update_camera()
				if mode==0:
					arena.camera.position=vehicle.to_global(Vector3(4,3,4));arena.camera.look_at(turret.yaw.global_position+Vector3.UP*.7)
				await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/gunner-%d-%d.png" % [int(rad_to_deg(angle)),mode])
		kit.set_physics_process(true);turret.set_physics_process(true)
	# Mounted driver and gunner must both be visible targets, and plasma must hurt them.
	var enemy=arena.get_node("PracticeRange").enemies[0]
	enemy.global_position=vehicle.to_global(Vector3(0,0,18));enemy.global_position.y=arena.height_at(enemy.position.x,enemy.position.z)
	await physics_frame;assert(enemy.sees_player(),"Enemies must see the gunner")
	var manager=arena.get_node("PracticeRange");var health=manager.health
	var point=arena.walker.global_position+Vector3.UP
	var bolt=manager.plasma(point+Vector3.UP*2,Vector3.DOWN,8,true,enemy.get_rid());bolt.velocity=Vector3.DOWN*30
	await create_timer(.2).timeout;assert(manager.health<health,"Mounted gunner must take plasma damage")
	kit.toggle_vehicle();assert(not kit.driving and not kit.gunning,"E exits turret")
	arena.walker.global_position=vehicle.to_global(Vector3(-3,0,0));kit.toggle_vehicle();assert(kit.driving==vehicle and not kit.gunning,"Side interaction must still drive")
	await physics_frame;await physics_frame;assert(enemy.sees_player(),"Enemies must see the driver")
	health=manager.health;point=vehicle.global_position+Vector3.UP
	bolt=manager.plasma(point+Vector3.UP*4,Vector3.DOWN,8,true,enemy.get_rid());bolt.velocity=Vector3.DOWN*30
	await create_timer(.3).timeout;assert(manager.health<health,"Mounted driver must take plasma damage")
	kit.toggle_vehicle()
	print("PASS: cold delay, ramp, sustained fire, cone bounds, cooldown, rear entry, aim, hits, exit and driver entry")
	quit()
