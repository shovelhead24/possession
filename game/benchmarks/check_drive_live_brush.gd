extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
const Editor=preload("res://world/terrain_drive_editor.gd")
class AimedEditor extends Editor:
	var target:=Vector3.ZERO
	func pick(_far_surface := false) -> Dictionary:
		var origin:Vector3=arena.camera.position
		var direction:Vector3=(target-origin).normalized()
		return arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*500,1))
	func over_panel() -> bool:
		return false
var scene: Node3D
func _initialize() -> void:
	create_timer(180).timeout.connect(func(): push_error("LIVE_BRUSH_TIMEOUT");quit(1))
	run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800)
	scene=load("res://world/terrain_drive.tscn").instantiate();root.add_child(scene)
	while not scene.ready_to_play: await process_frame
	scene.loading.close()
	scene.editor.queue_free();await process_frame
	var editor:=AimedEditor.new();scene.add_child(editor);editor.setup(scene);scene.editor=editor;editor.toggle()
	editor.radius_control.value=12;editor.strength=4
	var h:float=scene.source.surface_height(Vector2(230,320))
	scene.camera.position=Ring.point(230,h+65,370)
	scene.camera.look_at(Ring.point(230,h+3,320),Ring.up_at(scene.camera.position))
	editor.target=Ring.point(208,h,320)
	var hit:=editor.pick();assert(not hit.is_empty())
	var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
	scene._input(down)
	var started:=Time.get_ticks_usec();var previous:=started;var frames:=[];var publications:=[];var last_publication:int=scene.destruction.publications
	while (Time.get_ticks_usec()-started)/1000000.0<4:
		var elapsed:float=(Time.get_ticks_usec()-started)/1000000.0
		editor.target=Ring.point(208+elapsed*11,h,320)
		await process_frame
		var now:=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
		if scene.destruction.publications!=last_publication:
			last_publication=scene.destruction.publications;publications.append(scene.destruction.last_update_ms)
	var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;scene._input(up)
	while not editor.input_strokes.is_empty() or scene.destruction.busy(): await process_frame
	assert(scene.destruction.publications>=12,"Live brush did not publish frequently")
	assert(scene.destruction.undo_stack.size()==1,"Held mouse produced multiple undo steps")
	editor.save();while editor.save_when_ready: await process_frame
	assert(not scene.destruction.unsaved(),"Save did not include last queued brush dose")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-07/co/outputs/continuous-terrain-brush.png")
	frames.sort();publications.sort()
	print("LIVE_BRUSH_PASS ",JSON.stringify({"publications":scene.destruction.publications,"features":scene.destruction.cuts.size(),"median_update_ms":publications[publications.size()/2],"frame_p95_ms":frames[int(frames.size()*.95)],"frame_worst_ms":frames.back(),"save":scene.destruction.save_path}))
	quit()

