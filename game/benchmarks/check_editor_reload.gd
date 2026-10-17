extends SceneTree
const Store=preload("res://world/forge_store.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
func _initialize():
	create_timer(240).timeout.connect(func(): push_error("Editor reload timeout");quit(1))
	run.call_deferred()
func run():
	root.size=Vector2i(1366,768)
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	arena.loading.close()
	assert("editor-reload-test" in arena.forge.store.path)
	assert("editor-reload-test" in arena.actors.store.path)
	arena.editor.toggle();arena.editor.select_tool("forge")
	var world_id=arena.get_instance_id();var stream_id=arena.streamer.get_instance_id();var tree_id=arena.painted_trees.get_instance_id()
	var store_id=arena.forge.store.get_instance_id();var actor_store_id=arena.actors.store.get_instance_id()
	var point=arena.vehicle_kit.car.global_position+Vector3(10,2,0)
	var before=arena.forge.store.snapshot()
	var record=arena.forge.store.make("floor",Transform3D(Ring.tangent_basis(point,0),point))
	arena.forge.store.records.append(record);arena.forge.store.commit(before)
	arena.editor.select_id(record.id);arena.editor.start_move(false)
	arena.editor.angle_step=45;arena.editor.grid=1;arena.editor.rotation_delta=Vector3(.2,.3,0)
	var saved_records=arena.forge.store.snapshot();var undo_size=arena.forge.store.undo_stack.size();var actor_records=arena.actors.store.snapshot()
	var camera_pose=arena.camera.transform
	for i in 3:
		arena.dev_reload.request()
		while arena.dev_reload.busy: await process_frame
		assert("reloaded in" in arena.dev_reload.last_result,arena.dev_reload.last_result)
		assert(arena.get_instance_id()==world_id and arena.streamer.get_instance_id()==stream_id and arena.painted_trees.get_instance_id()==tree_id)
		assert(arena.forge.store.get_instance_id()==store_id and arena.actors.store.get_instance_id()==actor_store_id)
		assert(arena.forge.store.records==saved_records and arena.forge.store.undo_stack.size()==undo_size)
		assert(arena.actors.store.records==actor_records and arena.camera.transform==camera_pose)
		assert(arena.editor.opened and arena.editor.tool=="forge" and arena.editor.angle_step==45 and arena.editor.grid==1)
		assert(arena.editor.draft.size()==1 and arena.editor.moving and arena.forge.hidden_ids==[record.id])
		assert(arena.editor.preview_nodes.size()==1)
	arena.editor.cancel_preview();arena.editor.select_tool("forge")
	var floor_pose=Store.pose(record)
	arena.camera.position=point+Vector3(6,6,10);arena.camera.look_at(point)
	arena.editor.start_new("block");arena.editor.update_preview({"id":record.id,"position":point+Vector3(.7,.125,.4),"normal":Vector3.UP})
	arena.editor.set_physics_process(false)
	for i in 4: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs/edge-snap-editor.png")
	arena.editor.cancel_preview();arena.editor.select_tool("actors");arena.editor.begin_place("crate")
	# Preview visibility/cleanup is managed without changing the actor layout.
	arena.editor.object_preview.configure("crate",arena);arena.editor.object_preview.place(point,30)
	assert(arena.editor.object_preview.visible)
	arena.editor.select_tool("forge");assert(not arena.editor.object_preview.visible)
	print("PASS repeated editor reload: resident world, unsaved stores, undo, camera, move draft and settings retained; actor cursor cleanup")
	quit()
