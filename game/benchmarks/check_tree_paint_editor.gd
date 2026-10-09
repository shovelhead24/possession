extends SceneTree
const Ring = preload("res://world/terrain_drive_ring.gd")
var output := ""
var arena: Node3D

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-output="): output=arg.trim_prefix("--tree-output=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	# This check invokes Save; require explicit isolated paths for BOTH files.
	assert(Array(OS.get_cmdline_user_args()).any(func(arg): return arg.begins_with("--drive-edits-file=")))
	assert(Array(OS.get_cmdline_user_args()).any(func(arg): return arg.begins_with("--tree-paint-file=")))
	create_timer(240).timeout.connect(func(): push_error("Editor paint timeout");quit(1))
	run.call_deferred()

func run() -> void:
	arena=load("res://world/tree_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play: await process_frame
	arena.vehicle_kit.driving=false;arena.vehicle_kit.car.freeze=true
	arena.loading.ready_to_enter=true;arena.loading.close()
	var target: Vector3=arena.tree_view_ground(Vector2(310,350))
	arena.camera.position=target+Ring.up_at(target)*45+Vector3(0,0,28)
	arena.camera.look_at(target,Ring.up_at(target))
	var editor: Node=arena.editor;var painter: Node=arena.painted_trees
	assert(painter.store.records.is_empty(),"Use a fresh paint file")
	editor.toggle();editor.paint_button.pressed.emit();editor.radius_control.value=14
	assert(editor.tool=="trees" and editor.tree_rows.visible)
	await process_frame
	Input.warp_mouse(arena.camera.unproject_position(target))
	await process_frame
	var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	assert(editor.handle_input(event))
	assert(editor.painting,"Editor did not start paint at terrain cursor")
	await create_timer(.15).timeout
	event.pressed=false;editor.handle_input(event)
	while painter.busy(): await physics_frame
	var count: int=painter.store.records.size();assert(count>0)
	var undo_key := InputEventKey.new();undo_key.keycode=KEY_Z;undo_key.ctrl_pressed=true;undo_key.pressed=true
	editor.handle_input(undo_key);await process_frame;await process_frame
	assert(painter.store.records.is_empty())
	undo_key.keycode=KEY_Y;editor.handle_input(undo_key);await process_frame;await process_frame
	assert(painter.store.records.size()==count)
	undo_key.keycode=KEY_S;editor.handle_input(undo_key)
	await create_timer(.4).timeout
	assert(not painter.store.unsaved() and FileAccess.file_exists(painter.store.path))
	editor.erase_button.pressed.emit();editor.radius_control.value=14
	event.pressed=true;editor.handle_input(event);event.pressed=false;editor.handle_input(event)
	while painter.busy(): await physics_frame
	assert(painter.store.records.size()<count)
	editor.undo();await process_frame;await process_frame;assert(painter.store.records.size()==count)
	editor.paint_button.pressed.emit()
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("tree-paint-editor.png"))
	# Original terrain tools remain available with their usual controls.
	editor.select_tool("hill");assert(editor.strength_row.visible and not editor.tree_rows.visible)
	editor.select_tool("mountain");assert(editor.mountain_rows.visible and not editor.tree_rows.visible)
	editor.select_tool("trees");assert(not editor.strength_row.visible and not editor.mountain_rows.visible)
	editor.toggle();assert(not editor.opened and not editor.painting)
	print("TREE_PAINT_EDITOR_PASS painted=",count," input paint/erase, Ctrl+Z/Y/S, terrain tool switching")
	quit()
