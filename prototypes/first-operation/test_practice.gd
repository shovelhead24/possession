extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena);await process_frame
	var range_node=arena.get_node("PracticeRange");var kit=arena.kit
	for squad in range_node.squads: squad.set_physics_process(false)
	var guard=preload("res://practice_enemy.gd").new();guard.kind=1;guard.arena=arena;guard.manager=range_node;arena.add_child(guard);guard.set_physics_process(false);var hp=guard.health
	guard.take_hit(25,guard.position+Vector3(0,0,-5),guard.position+Vector3.UP)
	assert(guard.health==hp and guard.shield==45,"Frontal shield must absorb damage")
	guard.take_hit(25,guard.position+Vector3(0,0,5),guard.position+Vector3.UP)
	assert(guard.health==hp-25,"Flanking must bypass shield")
	var heavy=preload("res://practice_enemy.gd").new();heavy.kind=2;heavy.arena=arena;heavy.manager=range_node;arena.add_child(heavy);heavy.set_physics_process(false);hp=heavy.health
	heavy.take_hit(25,Vector3.ZERO,heavy.position+Vector3.UP*2)
	assert(heavy.health==hp-50,"Heavy eye must be vulnerable")
	kit.select_weapon(0);kit.ammo.Carbine=0;var count=kit.shot_count;kit.use_weapon();assert(kit.shot_count==count)
	kit.reload_weapon();await create_timer(1.7).timeout;assert(kit.ammo.Carbine==24)
	range_node.reset();await process_frame
	if OS.get_cmdline_user_args().has("--pictures"):
		arena.set_physics_process(false);kit.set_physics_process(false);kit.overlay.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		arena.camera.position=Vector3(38,3,-48);arena.camera.look_at(Vector3(38,1,-65))
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/practice-types.png")
		arena.camera.position=Vector3(-13,1.4,5);arena.camera.look_at(Vector3(-17,.65,9))
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/suspension-connected.png")
		var forest=arena.get_node("ArenaTrees");var point=forest.trees[0].position
		arena.camera.position=point+Vector3(36,5,42);arena.camera.look_at(point+Vector3.UP*4);forest.update_lods()
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/trees-final.png")
	print("PASS: guard shield and flank, heavy weakpoint, empty magazine and reload; practice reset")
	quit()

