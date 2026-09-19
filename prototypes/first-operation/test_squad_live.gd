extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena);await process_frame
	var manager=arena.get_node("PracticeRange");var squad=manager.squads[0]
	arena.set_physics_process(false);arena.kit.set_physics_process(false)
	for other in manager.squads:
		other.set_physics_process(false)
		for member in other.members: member.set_physics_process(false)
	# Flat test lane keeps the live brain test independent of random cover placement.
	squad.home=Vector3(-65,0,-20);squad.set_physics_process(true)
	for i in range(5):
		var unit=squad.members[i];unit.position=Vector3(-65+(i-2)*2.5,1,-20);unit.destination=unit.position;unit.set_physics_process(true)
	arena.walker.position=Vector3(-65,.1,7);arena.camera.position=arena.walker.position+Vector3.UP*1.65
	await create_timer(2).timeout;assert(squad.mode==squad.Mode.COMBAT,"A visible player must activate the squad")
	var captain=squad.captain;captain.cooldown=0;captain.charge=.01;captain.aim=arena.walker.position+Vector3.UP;captain.attack(.02)
	var red=false
	for bolt in get_nodes_in_group("plasma_bolts"):
		if bolt.tint.r>.9 and bolt.tint.g<.1: red=true
	assert(red,"Captain must emit red plasma")
	assert(captain.cooldown<1)
	var grenade=preload("res://frag_grenade.gd").new();grenade.manager=manager;arena.add_child(grenade);grenade.position=captain.position+Vector3(3,1,0);grenade.freeze=true;captain.dive_cooldown=0
	await create_timer(.2).timeout;assert(captain.dive_time>0,"Nearby visible grenade must automatically cause a dive");grenade.queue_free()
	if OS.get_cmdline_user_args().has("--pictures"):
		arena.kit.overlay.hide();var start=captain.position
		for stage in ["flight","landing","recovery"]:
			await create_timer(.22 if stage=="flight" else (.35 if stage=="landing" else .6)).timeout
			arena.camera.position=captain.position+Vector3(0,2,-5);arena.camera.look_at(captain.position+Vector3.UP*.7)
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/dive-"+stage+".png")
		assert(captain.position.distance_to(start)>3,"Dive must translate through the world")
	captain.take_hit(1000,arena.walker.position,captain.position)
	var grunt=squad.members[1];var before=grunt.position
	await create_timer(1).timeout;assert(grunt.routed and grunt.position.distance_to(before)>1,"Routed grunts must actually move")
	assert(grunt.lizard.player.current_animation==grunt.lizard.clips.Flee)
	for weapon in grunt.lizard.weapons: assert(not weapon.visible)
	# Lost contact uses a remembered position; cover teams alternate without knowing the new player position.
	arena.walker.position=Vector3(240,20,35);squad.last_known=Vector3(-65,0,-30);squad.quiet=31;squad.advance_memory(.3,false);squad.issue_orders()
	assert(squad.mode==squad.Mode.HUNT)
	print("PASS: live acquisition, red rapid fire, automatic grenade dive, moving hands-up rout and remembered-position hunt")
	quit()

