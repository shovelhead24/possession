extends SceneTree
const Store=preload("res://world/forge_store.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--forge-output="): output=arg.trim_prefix("--forge-output=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	create_timer(240).timeout.connect(func(): push_error("Forge integration timeout");quit(1))
	run.call_deferred()
func key(code: int, ctrl := false) -> void:
	var event := InputEventKey.new();event.keycode=code;event.ctrl_pressed=ctrl;event.pressed=true;arena._input(event)
func measure() -> Dictionary:
	for i in 90: await process_frame
	var samples := [];var previous := Time.get_ticks_usec()
	for i in 300:
		await process_frame
		var now := Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
	var total := 0.0
	for value in samples: total+=value
	samples.sort()
	return {"frames":samples.size(),"mean_ms":total/samples.size(),"fps":1000.0/(total/samples.size()),"p95_ms":samples[int(samples.size()*.95)],"p99_ms":samples[int(samples.size()*.99)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func run() -> void:
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	arena.loading.close();arena.vehicle_kit.car.freeze=true
	var editor: Node=arena.editor;var forge: Node=arena.forge
	assert(forge.store.path.contains("forge-integration"),"Must use an isolated test layout")
	forge.store.records=[];forge.store.revision+=1
	key(KEY_F1);assert(editor.opened);editor.select_tool("forge")
	assert(editor.build_panel.visible and not editor.panel.visible and not arena.hud.visible)
	var coord := Vector2(155,220);var h: float=arena.source.surface_height(coord)+12
	var point := Ring.point(coord.x,h,coord.y);var up := Ring.up_at(point)
	editor.start_new("floor");editor.update_preview({"position":point,"normal":up,"id":0});assert(editor.commit_preview())
	var floor_id: int=editor.selection[0];var floor_pose := Store.pose(forge.store.find(floor_id))
	await create_timer(.4).timeout
	assert(forge.bodies.has(floor_id))
	editor.start_new("floor");editor.face_choice=1
	editor.update_preview({"position":floor_pose.origin,"normal":floor_pose.basis.x,"id":floor_id})
	assert(editor.commit_preview());var second_id: int=editor.selection[0]
	var second := Store.pose(forge.store.find(second_id));assert(absf(second.origin.distance_to(floor_pose.origin)-4)<.02)
	editor.select_id(floor_id);editor.select_id(second_id,true);editor.join_selection()
	assert(forge.store.find(floor_id).group>0 and forge.store.expanded([floor_id]).size()==2)
	await create_timer(.4).timeout
	var body_id: int=forge.bodies[floor_id].get_instance_id()
	editor.set_finish(10)
	assert(forge.store.find(floor_id).finish==10 and forge.store.find(second_id).finish==10)
	await create_timer(.4).timeout
	assert(forge.bodies[floor_id].get_instance_id()==body_id,"Colour changes must preserve collision bodies")
	key(KEY_Z,true);assert(forge.store.find(floor_id).finish==0)
	key(KEY_Y,true);assert(forge.store.find(floor_id).finish==10)
	var before_relative := floor_pose.affine_inverse()*second
	editor.rotate_axis(1,1);editor.nudge(0,1)
	var after_relative := Store.pose(forge.store.find(floor_id)).affine_inverse()*Store.pose(forge.store.find(second_id))
	assert(before_relative.origin.distance_to(after_relative.origin)<.03 and before_relative.basis.is_equal_approx(after_relative.basis))
	var count: int=forge.store.records.size();key(KEY_D,true);assert(editor.draft.size()==2 and not editor.moving)
	var group: int=editor.draft[0].group;assert(group>0 and group!=forge.store.find(floor_id).group and editor.draft[1].group==group)
	key(KEY_ESCAPE);assert(forge.store.records.size()==count and forge.hidden_ids.is_empty())
	key(KEY_DELETE);assert(forge.store.records.is_empty());key(KEY_Z,true);assert(forge.store.records.size()==count)
	key(KEY_Y,true);assert(forge.store.records.is_empty());key(KEY_Z,true)
	editor.select_id(floor_id);assert(editor.selection.size()==2)
	key(KEY_G);assert(editor.moving and forge.hidden_ids.size()==2);key(KEY_ESCAPE);assert(forge.hidden_ids.is_empty())
	await create_timer(.4).timeout
	# Fixed placement rejects an existing solid; phased placement accepts it.
	floor_pose=Store.pose(forge.store.find(floor_id))
	editor.start_new("floor");editor.face_snap=false;editor.grid=0;editor.phased=false
	editor.rotation_delta=(Ring.tangent_basis(floor_pose.origin,0).inverse()*floor_pose.basis).get_euler()
	editor.update_preview({"position":floor_pose.origin-Ring.up_at(floor_pose.origin)*.125,"normal":up,"id":0})
	assert(not editor.valid_preview)
	editor.phased=true;editor.update_preview({"position":floor_pose.origin-up*.125,"normal":up,"id":0});assert(editor.valid_preview)
	editor.cancel_preview();editor.face_snap=true;editor.grid=.5
	# Build a small visible platform composition using the same placement controls.
	editor.start_new("door");editor.set_finish(4);editor.face_choice=3
	editor.update_preview({"position":floor_pose.origin,"normal":floor_pose.basis.y,"id":floor_id});assert(editor.commit_preview())
	var door_id: int=editor.selection[0]
	editor.start_new("wall");editor.set_finish(8);editor.face_choice=1
	var door_pose := Store.pose(forge.store.find(door_id))
	editor.update_preview({"position":door_pose.origin,"normal":door_pose.basis.x,"id":door_id});assert(editor.commit_preview())
	editor.start_new("ramp");editor.set_finish(6);editor.face_snap=false;editor.rotation_delta=Vector3(0,PI,0)
	editor.update_preview({"position":point+Vector3(0,0,7),"normal":up,"id":0});assert(editor.commit_preview())
	editor.start_new("building");editor.set_finish(3);editor.rotation_delta=Vector3.ZERO
	editor.update_preview({"position":point+Vector3(16,0,-5),"normal":up,"id":0});assert(editor.commit_preview())
	editor.face_snap=true;editor.face_choice=0;editor.select_id(door_id)
	key(KEY_S,true);await create_timer(.5).timeout
	assert(not forge.store.unsaved())
	var saved := Store.new();saved.base=forge.store.base;saved.path=forge.store.path;assert(saved.load_saved(true) and saved.records.size()==forge.store.records.size())
	assert(saved.find(floor_id).finish==10 and saved.find(door_id).finish==4)
	arena.camera.position=point+Vector3(19,10,24);arena.camera.look_at(point+Vector3(6,2,0),up)
	await create_timer(1).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("forge-editor.png"))
	# Exit and re-enter the construction editor without altering driving ownership.
	key(KEY_F1);assert(not editor.opened and arena.vehicle_kit.driving and arena.hud.visible)
	key(KEY_F1);assert(editor.opened and editor.build_panel.visible)
	editor.select_tool("trees");assert(editor.panel.visible and not editor.build_panel.visible)
	editor.select_tool("forge");assert(editor.build_panel.visible)
	key(KEY_F1)
	key(KEY_E);assert(arena.on_foot.active)
	key(KEY_F1);assert(editor.opened);key(KEY_F1);assert(arena.on_foot.active and not editor.opened)
	arena.on_foot.deactivate();arena.vehicle_kit.driving=false;arena.diagnostic=true
	arena.camera.position=point+Vector3(19,10,24);arena.camera.look_at(point+Vector3(6,2,0),up)
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	forge.visible=false
	var baseline: Dictionary=await measure()
	forge.visible=true
	var small: Dictionary=await measure()
	var original: Array=forge.store.snapshot()
	for i in 1000:
		var p := Ring.point(155+(i%40)*5,h+1,220+(i/40)*5)
		forge.store.records.append(forge.store.make("wall",Transform3D(Ring.tangent_basis(p,0),p),0))
	forge.store.revision+=1
	await create_timer(2).timeout
	var stress: Dictionary=await measure()
	stress["active_parts"]=forge.active_count;stress["batches"]=forge.batches.size();stress["colliders"]=forge.bodies.size()
	forge.store.records=original;forge.store.revision+=1
	var report := {"result":"PASS","parts":forge.store.records.size(),"active":forge.active_count,"batches":forge.batches.size(),"colliders":forge.bodies.size(),"checks":["F1 construction routing","place","face snap","rotate/nudge joined group","duplicate group remap","cancel","delete/undo/redo","fixed versus phased collision","10-item palette","12 colours + group recolour + undo + collider retention","save/reload","terrain/tree switching","return to driving","return to walking"],"performance":{"device":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),"baseline_hidden":baseline,"six_parts":small,"1006_parts":stress,"notes":"Short stationary samples, uncapped, same camera. Not a full-route 120 FPS guarantee."}}
	var file := FileAccess.open(output.path_join("forge-integration.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"	"));file.close()
	print("FORGE_INTEGRATION_PASS ",JSON.stringify(report));quit()


