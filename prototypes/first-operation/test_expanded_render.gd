extends "res://test_frame_diagnosis.gd"
func run() -> void:
	var started=Time.get_ticks_msec()
	arena=load("res://tactical.tscn").instantiate();root.add_child(arena);await process_frame
	print("BAKED_STARTUP_MS ",Time.get_ticks_msec()-started)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	arena.set_physics_process(false)
	var manager=arena.get_node("PracticeRange");manager.health=100000
	for place in [["spawn",Vector3(3.5,2,4.5),Vector3(0,2,-100)],["relay",Vector3(0,2,-267),Vector3(0,2,-310)],["forest",Vector3(-690,55,-60),Vector3(-630,10,-230)],["canyon",Vector3(650,65,-920),Vector3(540,-7,-1050)],["meeting",Vector3(350,45,-1180),Vector3(270,4,-1270)]]:
		arena.walker.position=place[1];arena.camera.position=place[1];arena.camera.look_at(place[2]);manager.stream_squads()
		await sample(place[0])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Games/possession/logs/expanded_"+place[0]+".png")
		print("ACTIVE_SQUADS ",manager.squads.size()," ENEMIES ",manager.enemies.size())
	arena.rex_menu.set_open(true)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Games/possession/logs/expanded_controls.png")
	print("PASS: rendered expanded arena and clean default overlays")
	quit()
