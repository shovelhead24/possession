extends SceneTree
var arena: Node3D
var output="C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs"
func _initialize():
	create_timer(240).timeout.connect(func(): push_error("Alien world timeout");quit(1))
	run.call_deferred()
func capture(name):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name))
func sample(label):
	await create_timer(2).timeout
	var cpu_start=arena.aliens.telemetry()
	var draws=0.0;var times=[];var previous=Time.get_ticks_usec();var total=0.0;var manager_total=0.0
	for i in 240:
		await process_frame
		var now=Time.get_ticks_usec();var elapsed=(now-previous)/1000.0;previous=now;times.append(elapsed);total+=elapsed
		manager_total+=arena.aliens.physics_usec
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	times.sort()
	var result={"draws":draws/240,"mean_ms":total/240,"fps":240000/total,"p95_ms":times[228],"manager_usec":manager_total/240,"actors":arena.aliens.enemies.size(),"bolts":arena.aliens.bolts.bolts.size()}
	var cpu_end=arena.aliens.telemetry()
	result["actor_cpu_ms_per_render_frame"]=(cpu_end.actor_usec_total-cpu_start.actor_usec_total)/240000.0
	result["animation_cpu_ms_per_render_frame"]=(cpu_end.animation_usec_total-cpu_start.animation_usec_total)/240000.0
	for counter in ["motion_usec_total","path_usec_total","sense_usec_total","capsule_changes_total"]:
		result[counter+"_per_frame"]=(cpu_end[counter]-cpu_start[counter])/240.0
	result["shadow_casters"]=cpu_end.shadow_casters
	print("ALIEN_WORLD_PROFILE ",label," ",JSON.stringify(result));return result
func run():
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert(arena.forge.store.path.contains("collision-saves"))
	await capture("alien-shadow-loading.png")
	arena.loading.close();arena.vehicle_kit.car.freeze=true
	var m=arena.aliens
	m.health=100000 # Profile continuous combat without defeat/respawn changing the view.
	for i in 100:
		if m.enemies.size()>=5: break
		await create_timer(.25).timeout
	assert(m.enemies.size()>=5,"Actual edited terrain must spawn a patrol")
	print("ALIEN_WORLD_SPAWN ",m.enemies.size()," positions ",m.enemies.map(func(u): return str(u.position)))
	arena.vehicle_kit.driving=false;arena.diagnostic=true
	arena.on_foot.active=false
	var squad=m.squads[0];var centre=squad.home;var up=preload("res://world/terrain_drive_ring.gd").up_at(centre)
	var basis=preload("res://world/terrain_drive_ring.gd").tangent_basis(centre,0)
	arena.camera.position=centre+basis*Vector3(13,6,20);arena.camera.look_at(centre+up,up)
	await create_timer(8).timeout
	await capture("alien-shadow-world.png")
	var positions=m.enemies.map(func(u): return u.global_position)
	await create_timer(4).timeout
	var moving=0
	for i in positions.size():
		if is_instance_valid(m.enemies[i]) and positions[i].distance_to(m.enemies[i].global_position)>.4: moving+=1
	assert(moving>0,"Patrols must move on edited terrain")
	var results={}
	# Same camera, alien component hidden and paused versus live patrols.
	m.process_mode=Node.PROCESS_MODE_DISABLED;m.hide()
	results.baseline=await sample("hidden_paused")
	m.process_mode=Node.PROCESS_MODE_INHERIT;m.show()
	results.patrol=await sample("patrol_shadows")
	# Hold the identical pose and viewpoint when isolating the shadow pass cost.
	m.process_mode=Node.PROCESS_MODE_DISABLED
	results.frozen_shadows=await sample("frozen_shadows")
	for unit in m.enemies: unit.lizard.body_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	results.frozen_no_shadows=await sample("frozen_no_shadows")
	for unit in m.enemies:
		unit.lizard.body_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if unit.lizard.shadow_enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.process_mode=Node.PROCESS_MODE_INHERIT
	m.process_mode=Node.PROCESS_MODE_DISABLED
	results.frozen_visible=await sample("frozen_visible")
	m.hide()
	results.baseline_repeat=await sample("hidden_paused_repeat")
	m.process_mode=Node.PROCESS_MODE_INHERIT;m.show()
	var feet=m.safe_spawn(centre+basis*Vector3(0,0,22));assert(feet!=Vector3.INF)
	arena.on_foot.activate_at(feet);arena.on_foot.set_physics_process(false);arena.on_foot.set_process(false)
	arena.camera.position=feet+up*1.54;arena.camera.look_at(centre+up,up)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	m.process_mode=Node.PROCESS_MODE_DISABLED;m.hide()
	results.combat_view_baseline=await sample("combat_view_hidden_paused")
	m.process_mode=Node.PROCESS_MODE_INHERIT;m.show()
	for unit in squad.members:
		unit.face(feet-unit.position,1);unit.sight_timer=0;unit.cooldown=0
	squad.report_contact(feet);squad.issue_orders()
	results.combat=await sample("combat")
	await capture("alien-shadow-combat.png")
	assert(m.health<100000 or m.bolts.bolts.size()>0,"Combat must fire or hurt player")
	var tab=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;arena._input(tab)
	assert(arena.collision_debug.hud_hidden and arena.hud.self_modulate.a==0 and arena.collision_debug.fps_label.visible)
	await create_timer(.6).timeout
	for unit in m.enemies: assert(not unit.label.visible)
	await capture("alien-shadow-hud-hidden.png")
	arena._input(tab)
	# Diagnostic isolation only: hold AI and hide tree visuals/proxies at the same foot view.
	m.process_mode=Node.PROCESS_MODE_DISABLED;m.hide()
	results.foot_baseline_repeat=await sample("foot_baseline_repeat")
	arena.trees.hide();arena.painted_trees.hide();arena.daylight.proxies.hide()
	results.foot_without_tree_rendering=await sample("foot_without_tree_rendering")
	var file=FileAccess.open(output.path_join("alien-shadow-performance.json"),FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
	print("TACTICAL_ALIENS_WORLD_PASS: loaded terrain placement, moving patrol, rendered briefing, combat, HUD toggle")
	quit()
