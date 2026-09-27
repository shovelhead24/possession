extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena)
	await process_frame
	arena.flying=true;arena.terrain_editor.enabled=true
	arena.camera.position=Vector3(270,110,-1130);arena.camera.look_at(Vector3(270,3,-1270))
	arena.rex_menu.set_indicators(true)
	for i in 60: await process_frame
	assert(arena.terrain_editor.marker.visible and arena.terrain_editor.aim.is_finite())
	var found=false
	for line in get_nodes_in_group("combat_viewcones"):
		if line is MeshInstance3D and line.mesh is ImmediateMesh:
			assert(line.visible and line.mesh.get_surface_count()>0);found=true
	assert(found,"Missing patrol path lines")
	assert(arena.get_node("PatrolDiagnostics").lines.visible and arena.get_node("PatrolDiagnostics").lines.mesh!=null)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Games/possession/logs/patrol_brush.png")
	arena.rex_menu.set_indicators(false)
	for line in get_nodes_in_group("combat_viewcones"): assert(not line.visible)
	arena.rex_menu.set_open(true)
	var scroll=arena.rex_menu.panel.get_child(0);scroll.scroll_vertical=1000
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Games/possession/logs/terrain_controls.png")
	print("PASS: flight brush, populated patrol mesh, toggle off and editor menu render")
	quit()
