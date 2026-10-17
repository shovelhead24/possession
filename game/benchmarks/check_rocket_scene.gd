extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/outputs/"
const Ring=preload("res://world/terrain_drive_ring.gd")
func _initialize():
	create_timer(300).timeout.connect(func(): push_error("ROCKET_SCENE_TIMEOUT");quit(1))
	run.call_deferred()
func run():
	root.size=Vector2i(1366,768)
	var arena=load("res://world/sky_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path and "sky-test" in arena.destruction.save_path)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"rocket-ready-briefing.png")
	arena.loading.close()
	if arena.editor.opened: arena.editor.toggle()
	arena.controller.set_physics_process(false)
	arena.vehicle_kit.test_controls=true;arena.vehicle_kit.test_throttle=0;arena.vehicle_kit.test_brake=true
	assert(arena.on_foot.exit_vehicle())
	var weapon=arena.weapons
	var event=InputEventKey.new();event.keycode=KEY_6;event.pressed=true;assert(weapon.handle_input(event))
	assert(weapon.selected==5 and weapon.models.size()==6)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for frame in 15: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"rocket-first-person.png")
	# Aim into nearby ground for real weapon-fired impact craters.
	arena.on_foot.set_physics_process(false);arena.on_foot.set_process(false)
	var p=arena.on_foot.global_position;var up=Ring.up_at(p)
	arena.camera.look_at(p+Ring.spinward_at(p)*12,up)
	var before=arena.destruction.completed
	assert(weapon.fire());assert(weapon.ammo[5]==1)
	while weapon.cooldown>0: await physics_frame
	assert(weapon.fire());assert(weapon.ammo[5]==0 and not weapon.fire())
	while arena.destruction.completed<before+2: await process_frame
	assert(weapon.start_reload())
	while weapon.reload_time>0: await physics_frame
	assert(weapon.ammo[5]==2)
	var pad=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_Y;pad.pressed=true
	assert(weapon.handle_input(pad) and weapon.selected==0)
	print("PASS full scene: weapon 6, two impact craters, empty magazine guard, reload, controller cycle; briefing and first-person screenshots captured")
	quit()
