extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena)
	await process_frame
	var forest=arena.get_node("ArenaTrees")
	assert(forest.trees.size()>80)
	for tree in forest.trees:
		assert(absf(tree.position.y-arena.height_at(tree.position.x,tree.position.z)+.12)<.01)
		assert(absf(tree.position.x+65)>=13)
	if OS.get_cmdline_user_args().has("--pictures"):
		arena.set_physics_process(false);arena.kit.set_physics_process(false);arena.kit.overlay.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		var point=forest.trees[0].position
		for distance in [12,55,200]:
			arena.camera.position=point+Vector3(distance*.65,5,distance*.75);arena.camera.look_at(point+Vector3.UP*4);forest.update_lods()
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://captures/trees-%d.png" % distance)
	print("PASS: forest grounded, course clear, LODs rendered")
	quit()
