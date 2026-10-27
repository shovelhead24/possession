extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/"
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var results=[]
func _initialize():
	create_timer(400).timeout.connect(func():push_error("HUD_TIMEOUT");quit(1))
	run.call_deferred()
func lock_input(node: Node):
	node.set_process_input(false);node.set_process_unhandled_input(false);node.set_process_unhandled_key_input(false)
	for child in node.get_children():lock_input(child)
func stats(a: Array) -> Dictionary:
	a.sort();var total=0.0
	for v in a:total+=v
	return {"frames":a.size(),"mean_ms":total/a.size(),"p95_ms":a[int(a.size()*.95)]}
func phase(mode: String, hidden: bool, text_updates: bool, trace_mode: String):
	if arena.collision_debug.hud_hidden!=hidden:arena.collision_debug.toggle_hud()
	arena.hud_updates_enabled=text_updates
	arena.jitter_trace.set_process(trace_mode!="off");arena.jitter_trace.set_physics_process(trace_mode!="off")
	if trace_mode=="recording":arena.jitter_trace.toggle()
	await create_timer(1.0).timeout
	var samples=[];var draws=[];var began=Time.get_ticks_usec();var last=began
	while Time.get_ticks_usec()-began<5000000:
		await process_frame
		var now=Time.get_ticks_usec();samples.append((now-last)/1000.0);last=now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var row=stats(samples);row.merge({"mode":mode,"hidden":hidden,"text_updates":text_updates,"trace":trace_mode,"draw_calls":stats(draws).mean_ms,"camera":str(arena.camera.global_transform)})
	results.append(row);print("HUD_PHASE ",JSON.stringify(row))
	if trace_mode=="recording":
		arena.jitter_trace.toggle()
		while arena.jitter_trace.writer:await process_frame
func run():
	root.size=Vector2i(1366,768)
	arena=load("res://world/performance_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter:await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path and "sky-test" in arena.destruction.save_path)
	arena.hud_refresh_interval=0.0;arena.hud_skip_when_hidden=false
	if "--hud-validate" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"hud-briefing.png")
	arena.loading.close();lock_input(arena);arena.controller.set_physics_process(false);Engine.max_fps=0
	arena.on_foot.deactivate();var kit=arena.vehicle_kit;kit.driving=true;kit.test_controls=true;kit.test_throttle=0;kit.test_brake=true
	assert(await kit.place(Vector2(120,145),atan2(-124.0,107.0)))
	for i in 180:await process_frame
	# Hold exactly one world camera for both modes; movement remains simulated.
	kit.driving=false;arena.diagnostic=true
	var ground=arena.on_foot.find_ground(kit.car.global_position+kit.car.global_basis.x*4)
	assert(not ground.is_empty());arena.on_foot.activate_at(ground.feet);arena.on_foot.test_controls=true
	arena.on_foot.set_process(false)
	arena.camera.global_transform=Transform3D(Ring.tangent_basis(kit.car.global_position,atan2(-124.0,107.0)),kit.car.global_position+Ring.up_at(kit.car.global_position)*2.5)
	arena.camera.rotate_object_local(Vector3.RIGHT,-.15)
	if "--hud-validate" in OS.get_cmdline_user_args():
		await validate_hud();return
	for mode in ["on_foot","driving"]:
		arena.on_foot.active=mode=="on_foot"
		for pass_index in 2:
			var phases=[[false,true,"passive"],[true,true,"passive"],[true,false,"passive"],[false,false,"passive"],[true,false,"off"],[true,false,"recording"]]
			if pass_index==1:phases.reverse()
			for p in phases:await phase(mode,p[0],p[1],p[2])
	FileAccess.open(OUT+"hud-audit.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("HUD_AUDIT_PASS");quit()

func validate_hud():
	arena.hud_refresh_interval=.1;arena.hud_skip_when_hidden=true
	await phase("optimized_on_foot",false,true,"passive")
	assert(arena.hud.text.count("PERFORMANCE DEMO /")==1)
	assert(arena.hud.text.count("Painted trees:")==1)
	var weapon=arena.weapons
	assert(weapon.view_active)
	var old_text=weapon.ammo_label.text
	weapon.ammo[weapon.selected]-=1
	await process_frame
	await process_frame
	assert(weapon.ammo_label.text!=old_text,"Ammo changes must display immediately")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"hud-optimized-visible.png")
	arena.collision_debug.toggle_hud()
	await process_frame
	await process_frame
	var frozen=arena.hud.text;var ammo_frozen=weapon.ammo_label.text
	await phase("optimized_on_foot",true,true,"passive")
	assert(arena.hud.text==frozen and weapon.ammo_label.text==ammo_frozen,"Hidden text must not rebuild")
	arena.collision_debug.toggle_hud()
	await create_timer(.2).timeout
	assert(arena.hud.text.count("Painted trees:")==1)
	# Exercise enter/exit HUD changes and camera updates in the real driving mode.
	arena.on_foot.deactivate();arena.vehicle_kit.driving=true
	await create_timer(.3).timeout
	assert("ON FOOT" not in arena.hud.text)
	assert("WASD drive" in arena.hud.text)
	assert(not weapon.view_active)
	FileAccess.open(OUT+"hud-validation.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("HUD_VALIDATION_PASS: visible/hidden text, immediate ammo, enter/exit, briefing")
	quit()
