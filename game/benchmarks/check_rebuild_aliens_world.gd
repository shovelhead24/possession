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
	var draws=0.0;var times=[];var previous=Time.get_ticks_usec();var total=0.0;var manager_total=0.0
	for i in 240:
		await process_frame
		var now=Time.get_ticks_usec();var elapsed=(now-previous)/1000.0;previous=now;times.append(elapsed);total+=elapsed
		manager_total+=arena.aliens.physics_usec
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	times.sort()
	var result={"draws":draws/240,"mean_ms":total/240,"fps":240000/total,"p95_ms":times[228],"manager_usec":manager_total/240,"actors":arena.aliens.enemies.size(),"bolts":arena.aliens.bolts.bolts.size()}
	print("ALIEN_WORLD_PROFILE ",label," ",JSON.stringify(result));return result
func run():
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert(arena.forge.store.path.contains("collision-saves"))
	await capture("tactical-aliens-loading.png")
	arena.loading.close();arena.vehicle_kit.car.freeze=true
	var m=arena.aliens
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
	await capture("tactical-aliens-world.png")
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
	results.patrol=await sample("patrol")
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
	await capture("tactical-aliens-combat.png")
	assert(m.health<100 or m.bolts.bolts.size()>0,"Combat must fire or hurt player")
	var tab=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;arena._input(tab)
	assert(arena.collision_debug.hud_hidden and arena.hud.self_modulate.a==0 and arena.collision_debug.fps_label.visible)
	await create_timer(.6).timeout
	for unit in m.enemies: assert(not unit.label.visible)
	await capture("tactical-aliens-hud-hidden.png")
	arena._input(tab)
	var file=FileAccess.open(output.path_join("tactical-aliens-performance.json"),FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
	print("TACTICAL_ALIENS_WORLD_PASS: loaded terrain placement, moving patrol, rendered briefing, combat, HUD toggle")
	quit()
