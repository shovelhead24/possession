extends SceneTree

func _initialize() -> void: call_deferred("run")

func key(code: int) -> void:
	var event=InputEventKey.new();event.keycode=code;event.pressed=true
	root.push_input(event)
	event=InputEventKey.new();event.keycode=code;event.pressed=false;root.push_input(event)

func run() -> void:
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena)
	await process_frame
	var menu=arena.rex_menu;var actor=menu.rex()
	assert(not menu.indicators_visible and not menu.hud_visible and not menu.damage_visible,"Clean HUD defaults failed")
	for label in get_nodes_in_group("optional_hud_text"): assert(not label.visible,"HUD text visible by default")
	for label in get_nodes_in_group("enemy_damage_text"): assert(not label.visible,"Damage text visible by default")
	menu.set_indicators(true)
	key(KEY_6);assert(menu.opened,"6 did not open globally")
	menu.behavior.item_selected.emit(3)
	await create_timer(.2).timeout
	var held_position=actor.position
	await create_timer(.2).timeout
	assert(actor.position.distance_to(held_position)<.01,"Hold mode moved")
	menu.animation.item_selected.emit(5)
	await create_timer(.2).timeout
	assert(actor.preview_mode==5 and "left" in actor.diagnostic_animation(),"Animation selector failed")
	key(KEY_P);assert(paused,"P did not pause")
	var time=menu.simulation_time;var frame=actor.diagnostic_frame()
	await create_timer(.25,true,false,true).timeout
	assert(menu.simulation_time==time and actor.diagnostic_frame()==frame,"Simulation timer/animation advanced while paused")
	key(KEY_6);assert(not menu.opened,"6 could not close during pause")
	key(KEY_6);assert(menu.opened,"6 could not reopen during pause")
	key(KEY_P);assert(not paused,"P did not resume")
	menu.set_control(true);assert(menu.controlled and actor.behavior_mode==4,"Takeover failed")
	assert(not menu.opened and not arena.kit.overlay.visible,"Player gun overlay remained active")
	# Exercise manual movement without relying on keyboard timing in a test.
	menu.set_physics_process(false);actor.manual_move=Vector3.FORWARD
	var before=actor.position
	await create_timer(.7).timeout
	assert(actor.position.distance_to(before)>3,"Manual Rexy did not move")
	actor.manual_move=Vector3.ZERO
	var target=actor.manager.enemies[0];target.set_physics_process(false);target.dead=false
	var mouth=actor.mouth_point();target.position=Vector3(mouth.x,arena.height_at(mouth.x,mouth.z),mouth.z)
	actor.cached_prey=target;actor.target_scan_timer=1;actor.cooldown=0;actor.manual_bite=true
	await create_timer(.1).timeout
	assert(actor.bite_target==target,"Manual bite did not grab selected target")
	assert(menu.diamond.visible,"Selected-target diamond missing")
	menu.indicators_button.pressed.emit()
	await process_frame
	assert(not menu.indicators_visible and not menu.diamond.visible and not actor.bite_debug.visible,"Indicator toggle did not hide target/bite")
	for cone in get_nodes_in_group("combat_viewcones"): assert(not cone.visible,"Enemy viewcone stayed visible")
	var new_cone=preload("res://vision_debug.gd").new();new_cone.setup(20,60,Color.RED,1);arena.add_child(new_cone)
	await process_frame
	assert(not new_cone.visible,"Newly spawned viewcone ignored hidden setting")
	new_cone.queue_free()
	key(KEY_P);var paused_bite=actor.bite_time
	menu.indicators_button.pressed.emit()
	await process_frame
	assert(menu.indicators_visible and actor.bite_debug.visible,"Toggle could not restore indicators while paused")
	for cone in get_nodes_in_group("combat_viewcones"): assert(cone.visible,"Viewcone failed to restore")
	await create_timer(.15,true,false,true).timeout
	assert(actor.bite_time==paused_bite,"Bite advanced during pause")
	key(KEY_P)
	menu.set_control(false);assert(not menu.controlled and arena.kit.overlay.visible,"Release did not restore player")
	menu.set_open(false)
	var car=arena.kit.vehicles[0];arena.walker.position=car.position+car.global_basis.x*2
	arena.kit.toggle_vehicle();assert(arena.kit.driving==car,"Vehicle precondition failed")
	key(KEY_6);assert(menu.opened,"6 unavailable while driving")
	key(KEY_P);assert(paused,"P unavailable while driving")
	key(KEY_P)
	menu.set_control(true);assert(not arena.kit.is_physics_processing(),"Vehicle controls competed with Rexy")
	menu.set_control(false);assert(arena.kit.driving==car and arena.kit.is_physics_processing(),"Return to vehicle failed")
	arena.kit.toggle_vehicle()
	menu.set_open(true)
	menu.behavior.select(actor.behavior_mode)
	await process_frame
	await process_frame
	assert("SIM" in menu.hud.text,"Simulation timer missing")
	print("PASS: global 6, modes, preview selector, P pause/resume, frozen timer/frame/bite, manual movement/bite, target diamond, safe control return")
	if "--ui-preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Games/possession/logs/trex_controls_preview.png")
	quit()
