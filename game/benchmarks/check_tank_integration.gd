extends SceneTree
var arena: Node3D
func _initialize():
	create_timer(180).timeout.connect(func(): push_error("Tank integration timeout");quit(1))
	run.call_deferred()
func sample() -> Dictionary:
	for i in 30: await process_frame
	var samples=[];var last=Time.get_ticks_usec()
	for i in 180:
		await process_frame
		var now=Time.get_ticks_usec();samples.append((now-last)/1000.0);last=now
	var total=0.0
	for t in samples: total+=t
	samples.sort()
	return {"mean_ms":total/samples.size(),"p95_ms":samples[171],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
func run():
	root.size=Vector2i(1366,768);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	arena.loading.close()
	assert("editor-reload-test" in arena.actors.store.path and "editor-reload-test" in arena.forge.store.path)
	var kit=arena.vehicle_kit;var tank=kit.vehicles[1]
	assert(tank.has_method("fire_cannon") and kit.tank_menu)
	var ground=arena.aliens.ground(tank.global_position+tank.global_basis.x*4)
	assert(not ground.is_empty());arena.on_foot.activate_at(ground.position)
	assert(arena.on_foot.enter_vehicle(),arena.on_foot.notice)
	assert(kit.car==tank and kit.menu==kit.tank_menu)
	assert(not kit.driver_model.visible)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var look=InputEventMouseMotion.new();look.relative=Vector2(650,0);kit.handle_input(look);assert(absf(kit.driver_look.x)>1.6);kit.driver_look=Vector2.ZERO
	kit.menu.set_open(true);assert(not tank.fire_cannon());kit.menu.set_open(false)
	for i in 60: await physics_frame
	assert(tank.grounded_count>0)
	assert(arena.on_foot.exit_vehicle(),arena.on_foot.notice)
	kit.select_vehicle(kit.original_car);assert(kit.menu==kit.warthog_menu)
	arena.editor.toggle();arena.editor.select_tool("actors");arena.editor.begin_place("tank")
	arena.editor.commit_at(tank.global_position+Vector3(15,0,0))
	var authored=arena.actors.store.find(arena.editor.actor_id)
	assert(authored.kind=="tank")
	assert(arena.actors.spawn_actor(authored))
	var extra=arena.actors.live[authored.id]
	assert(extra.has_method("fire_cannon") and extra.corners.size()==8)
	kit.select_vehicle(extra);assert(kit.menu==kit.tank_menu and kit.menu.car==extra)
	kit.select_vehicle(kit.original_car);arena.actors.retire(authored.id,false)
	await process_frame
	arena.editor.object_preview.configure("tank",arena);arena.editor.object_preview.hide()
	# Fixed camera, paused actors and identical resident scenery for visibility A/B.
	arena.camera.position=tank.global_position+Vector3(10,6,-12);arena.camera.look_at(tank.global_position+Vector3.UP)
	tank.hide();var hidden=await sample();tank.show();var visible=await sample();tank.hide();var hidden_again=await sample();tank.show()
	arena.editor.layer.hide();arena.hud.hide()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs/tank-rebuild-scene.png")
	print("TANK_SCENE_AB ",JSON.stringify({"hidden":hidden,"visible":visible,"hidden_again":hidden_again}))
	print("PASS tank integrated: nearby spawn, on-foot entry/exit, separate settings, driver hidden, ground support, actor authoring and preview")
	quit()
