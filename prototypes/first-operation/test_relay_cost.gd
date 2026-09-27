extends "res://test_frame_diagnosis.gd"
func run():
	arena=load("res://tactical.tscn").instantiate();root.add_child(arena);await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);arena.set_physics_process(false)
	arena.walker.position=Vector3(0,2,-267);arena.camera.position=arena.walker.position;arena.camera.look_at(Vector3(0,2,-310))
	var manager=arena.get_node("PracticeRange");manager.health=100000;manager.stream_squads()
	await sample("relay_live")
	for actor in manager.tyrants:
		if is_instance_valid(actor): actor.set_physics_process(false);actor.grounding.active=false
	await sample("rex_ai_grounding_off")
	for squad in manager.squads: squad.set_physics_process(false)
	for unit in manager.enemies: unit.repath=10000
	await sample("alien_navigation_off")
	for unit in manager.enemies: unit.set_physics_process(false)
	await sample("alien_physics_off")
	for unit in manager.enemies: unit.lizard.process_mode=Node.PROCESS_MODE_DISABLED
	await sample("alien_animation_off")
	quit()
