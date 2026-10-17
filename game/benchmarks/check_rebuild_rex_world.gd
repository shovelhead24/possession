extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var output="C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs"
func _initialize():
	create_timer(240).timeout.connect(func(): push_error("Rex world timeout");quit(1))
	run.call_deferred()
func capture(name):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name))
func sample(label):
	await create_timer(2).timeout
	var times=[];var previous=Time.get_ticks_usec();var total=0.0;var draws=0.0;var rex_cpu=0.0
	for i in 360:
		await process_frame
		var now=Time.get_ticks_usec();var elapsed=(now-previous)/1000.0;previous=now;times.append(elapsed);total+=elapsed
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		if is_instance_valid(arena.aliens.trex) and arena.aliens.trex.process_mode!=Node.PROCESS_MODE_DISABLED: rex_cpu+=arena.aliens.trex.physics_usec
	times.sort()
	var result={"mean_ms":total/360,"fps":360000/total,"p95_ms":times[342],"p99_ms":times[356],"draws":draws/360,"rex_physics_usec":rex_cpu/360}
	print("REX_WORLD_PROFILE ",label," ",JSON.stringify(result));return result
func run():
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert(arena.forge.store.path.contains("collision-saves"))
	await capture("rex-loading.png")
	arena.loading.close();arena.vehicle_kit.car.freeze=true
	var manager=arena.aliens
	assert(is_instance_valid(manager.trex),"Rex must prepare while loading")
	var rex=manager.trex
	arena.vehicle_kit.driving=false;arena.on_foot.active=false;arena.diagnostic=true
	var centre=rex.position;var up=Ring.up_at(centre);var basis=Ring.tangent_basis(centre,0)
	arena.camera.position=centre+basis*Vector3(34,17,40);arena.camera.look_at(centre+up*6,up)
	rex.behavior_mode=1
	await create_timer(3).timeout
	manager.stream_enabled=false
	for unit in manager.enemies: unit.set_physics_process(false)
	for squad in manager.squads: squad.set_physics_process(false)
	var initial=rex.position
	await create_timer(2).timeout
	assert(rex.position.distance_to(initial)>1,"Patrol must move on actual terrain")
	print("REX_WORLD_POSITION ",rex.position," movement=",rex.position.distance_to(initial))
	centre=rex.position;up=Ring.up_at(centre);basis=Ring.tangent_basis(centre,0)
	arena.camera.position=centre+basis*Vector3(60,22,65);arena.camera.look_at(centre+up*6,up)
	await capture("rex-world.png")
	var results={}
	rex.runtime_active=false;rex.process_mode=Node.PROCESS_MODE_DISABLED;rex.hide()
	results.rex_off=await sample("rex_off")
	rex.process_mode=Node.PROCESS_MODE_INHERIT;rex.show();rex.behavior_mode=3
	results.rex_hold=await sample("rex_hold")
	rex.behavior_mode=1
	results.rex_walk=await sample("rex_walk")
	rex.runtime_active=false;rex.process_mode=Node.PROCESS_MODE_DISABLED;rex.hide()
	results.rex_off_repeat=await sample("rex_off_repeat")
	rex.process_mode=Node.PROCESS_MODE_INHERIT;rex.show();rex.behavior_mode=0
	for unit in manager.enemies: unit.set_physics_process(true)
	for squad in manager.squads: squad.set_physics_process(true)
	results.live_encounter=await sample("live_encounter")
	var tab=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;arena._input(tab)
	await create_timer(.4).timeout
	assert(not rex.health_label.visible and arena.collision_debug.fps_label.visible,"Tab keeps FPS and hides Rex label")
	arena._input(tab)
	var hp=rex.health;rex.take_hit(100,centre,centre);assert(rex.health==hp-100)
	var old=rex;manager.reset();await process_frame
	assert(not is_instance_valid(old));manager.spawn_rex();assert(is_instance_valid(manager.trex) and manager.trex.health==4000)
	assert(get_nodes_in_group("tyrants").size()==1,"Reset/spawn cannot duplicate Rex")
	var file=FileAccess.open(output.path_join("rex-world-performance.json"),FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
	print("REX_WORLD_PASS: saved-world loading, patrol motion, rendering, HUD, damage and reset")
	arena.free();quit()
