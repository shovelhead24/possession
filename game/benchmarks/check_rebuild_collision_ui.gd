extends SceneTree
var arena: Node3D
const Ring=preload("res://world/terrain_drive_ring.gd")
const OUTPUT="C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs/"
func _initialize() -> void:
	create_timer(300).timeout.connect(func(): push_error("COLLISION_UI_TIMEOUT");quit(1));run.call_deferred()
func key(code: int) -> void:
	var event := InputEventKey.new();event.pressed=true;event.keycode=code;arena._input(event)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUTPUT+name+".png")
func run() -> void:
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert(arena.forge.store.path.contains("collision-saves"))
	assert(arena.loading.brief.title.contains("plasma projectiles"))
	await shot("collision-loading-screen")
	arena.loading.close();arena.vehicle_kit.driving=false;arena.vehicle_kit.car.freeze=true
	key(KEY_F1);assert(arena.editor.opened)
	var debug: Node3D=arena.collision_debug
	assert(debug.buttons.size()==2 and not debug.enabled)
	key(KEY_TAB);assert(debug.hud_hidden and arena.hud.self_modulate.a==0 and arena.weapons.ammo_label.self_modulate.a==0)
	assert(arena.editor.tool_help.self_modulate.a==1 and debug.fps_label.visible)
	debug.buttons[0].button_pressed=true;assert(debug.enabled and debug.buttons[1].button_pressed)
	arena.camera.position=Ring.point(-9,7,214);arena.camera.look_at(Ring.point(5,-1,201),Vector3.UP)
	for i in 300:
		await process_frame
		if debug.queued.is_empty() and debug.overlays.size()>50: break
	assert(debug.overlays.size()>50)
	for entry in debug.overlays.values():
		for surface in entry.visual.mesh.get_surface_count(): assert(entry.visual.mesh.surface_get_primitive_type(surface)==Mesh.PRIMITIVE_LINES)
	await shot("collision-wireframes-editor")
	key(KEY_F1);assert(debug.enabled)
	await shot("collision-wireframes-clean")
	# Real imported Warthog settling on the player's copied layer-2 platform.
	var car: RigidBody3D=arena.vehicle_kit.car
	car.global_transform=Transform3D(Ring.tangent_basis(Ring.point(6,-1.075,201.625),0),Ring.point(6,-1.075,201.625))
	car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO
	await physics_frame;car.freeze=false;car.reset_physics_interpolation()
	await create_timer(2).timeout
	var layer_two_contacts := 0
	for corner in car.corners:
		if corner.grounded:
			var body: Variant=instance_from_id(corner.trace_collider)
			if is_instance_valid(body) and body.collision_layer&2: layer_two_contacts+=1
	assert(layer_two_contacts==4,"Imported Warthog must settle on construction with all four wheels")
	car.freeze=true
	var body := StaticBody3D.new();body.collision_layer=2;arena.add_child(body)
	var shape := CollisionShape3D.new();shape.shape=BoxShape3D.new();body.add_child(shape)
	body.position=arena.camera.position
	for i in 300:
		await process_frame
		if debug.overlays.has(shape.get_instance_id()): break
	assert(debug.overlays.has(shape.get_instance_id()))
	body.position+=Vector3(1,2,3);await process_frame;await process_frame
	assert(debug.overlays[shape.get_instance_id()].visual.global_position.distance_to(shape.global_position)<.01)
	shape.disabled=true;await create_timer(.3).timeout;assert(not debug.overlays.has(shape.get_instance_id()))
	shape.disabled=false
	for i in 300:
		await process_frame
		if debug.overlays.has(shape.get_instance_id()): break
	assert(debug.overlays.has(shape.get_instance_id()))
	var id := shape.get_instance_id();body.free();await create_timer(.3).timeout;assert(not debug.overlays.has(id))
	debug.buttons[1].button_pressed=false;assert(not debug.enabled and debug.overlays.is_empty())
	key(KEY_TAB);assert(not debug.hud_hidden and arena.hud.self_modulate.a==1 and not debug.is_processing())
	arena.on_foot.activate_at(Ring.point(6,-1.3,206));arena.on_foot.test_controls=true
	key(KEY_3);await create_timer(.3).timeout
	assert(arena.weapons.selected==2 and arena.weapons.models.size()==5)
	var shots: int=arena.weapons.shots;assert(arena.weapons.fire());assert(arena.weapons.shots==shots+1 and arena.weapons.ammo[2]==99)
	await create_timer(.04).timeout;await shot("plasma-glowing-shot")
	key(KEY_R);await create_timer(1.65).timeout;assert(arena.weapons.ammo[2]==100)
	await shot("plasma-rifle-in-game")
	key(KEY_Q);assert(arena.weapons.selected==0);key(KEY_3);assert(arena.weapons.selected==2)
	key(KEY_TAB);await process_frame;assert(debug.fps_label.visible and arena.weapons.ammo_label.self_modulate.a==0)
	await shot("plasma-rifle-fps-only")
	print("COLLISION_UI_PASS: Tab, both editor toggles, loaded/disabled/unloaded/moving shapes, clean off state; imported Warthog four layer-2 wheel contacts")
	quit()
