extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena);await process_frame
	var manager=arena.get_node("PracticeRange");var kit=arena.kit
	assert(manager.squads.size()==4 and manager.enemies.size()==20)
	for squad in manager.squads:
		squad.set_physics_process(false);assert(squad.members.size()==5);var leaders=0
		for member in squad.members:
			member.set_physics_process(false)
			if member.elite: leaders+=1
		assert(leaders==1)
	arena.set_physics_process(false);kit.set_physics_process(false)
	var squad=manager.squads[0];var elite=squad.captain;var grunt=squad.members[1]
	assert(is_equal_approx(elite.lizard.scale.x/grunt.lizard.scale.x,1.5));assert(elite.health>grunt.health)
	assert(elite.lizard.clips.size()==14,"All movement and idle clips must import")
	squad.report_contact(Vector3(20,0,-80));squad.advance_memory(29,false);assert(squad.mode==squad.Mode.HOLD)
	squad.advance_memory(1.1,false);assert(squad.mode==squad.Mode.HUNT)
	squad.clock=0;squad.issue_orders();var moves=0
	for member in squad.members:
		if member.pace>0: moves+=1
	assert(moves==2,"First hunting pair advances while three cover")
	squad.clock=5;squad.issue_orders();assert(squad.covering_team==1)
	squad.advance_memory(270,false);assert(squad.mode==squad.Mode.PATROL)
	squad.report_contact(Vector3(10,0,-70));elite.take_hit(1000,Vector3(10,0,-70),elite.position)
	for member in squad.members.slice(1): assert(member.routed and member.gait=="Flee")
	var frag=preload("res://frag_grenade.gd").new()
	assert(not frag.update_fuse(2,false,0,0),"Apex in midair is not rest")
	assert(not frag.update_fuse(.6,true,0,0));assert(not frag.update_fuse(.2,true,1,0));assert(frag.resting==0)
	assert(not frag.update_fuse(1.99,true,0,0));assert(frag.update_fuse(.02,true,0,0));frag.free()
	var diver=manager.squads[1].captain;diver.position=Vector3(-200,arena.height_at(-200,0),0)
	await physics_frame;await physics_frame
	assert(diver.begin_dive(diver.position+Vector3.RIGHT*4));assert(diver.dive_direction.x<0)
	assert(manager.cover.rocks.size()>20);assert(manager.navigation.path(Vector3(-90,0,-30),Vector3(-90,0,-180)).size()>2)
	# Blast rays respect a thin wall, while an exposed unit takes damage.
	var wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,4,.3);shape.shape=box;wall.add_child(shape);arena.add_child(wall);wall.position=Vector3(200,60,76)
	var victim=manager.squads[2].members[1];victim.position=Vector3(200,59.4,74)
	await physics_frame;await physics_frame
	frag=preload("res://frag_grenade.gd").new();frag.manager=manager;arena.add_child(frag);frag.position=Vector3(200,60,78);frag.freeze=true
	assert(not frag.clear_blast(victim.position+Vector3.UP*.6,victim));var hp=victim.health;frag.detonate();assert(victim.health==hp)
	wall.queue_free();await physics_frame;await physics_frame
	frag=preload("res://frag_grenade.gd").new();frag.manager=manager;arena.add_child(frag);frag.position=Vector3(200,60,78);frag.freeze=true;frag.detonate();assert(victim.health<hp)
	# Let a real thrown rigid body settle; this exercises contact reporting and sleeping.
	frag=preload("res://frag_grenade.gd").new();frag.manager=manager;arena.add_child(frag);frag.position=Vector3(-65,1,15)
	for step in range(60):
		await create_timer(.05).timeout
		if frag.stopped: break
	assert(frag.stopped and frag.freeze and frag.linear_velocity==Vector3.ZERO,"Slow grenade must be stopped")
	await create_timer(1.7).timeout;assert(is_instance_valid(frag),"Stopped grenade must wait two seconds")
	await create_timer(.4).timeout;assert(not is_instance_valid(frag),"Stopped grenade must detonate after two seconds")
	if OS.get_cmdline_user_args().has("--pictures"):
		kit.overlay.hide();var leader=manager.squads[3].captain;var small=manager.squads[3].members[1]
		leader.position=Vector3(90,arena.height_at(90,-120),-120);small.position=leader.position+Vector3(2,0,0);small.position.y=arena.height_at(small.position.x,small.position.z)
		leader.rotation.y=0;small.rotation.y=0;leader.lizard.play("Idle");small.lizard.play("Idle")
		arena.camera.position=leader.position+Vector3(4,2,-6);arena.camera.look_at(leader.position+Vector3(1,1,0))
		await create_timer(.3).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/elite-and-grunt.png")
		small.lizard.set_fleeing(true);small.lizard.play("Flee");leader.lizard.play("Crouch")
		await create_timer(.3).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/flee-and-crouch.png")
		leader.lizard.play("Dive");await create_timer(.3).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/elite-dive.png")
		arena.camera.position=Vector3(220,100,-260);arena.camera.look_at(Vector3(80,0,-240));await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/squad-landscape.png")
	print("PASS: four 1+4 squads, 1.5x elite, 14 clips, 30s hunt, alternating advance, 300s patrol, captain morale, grenade rest reset, blast cover, physical fuse, dive and navigation")
	quit()
