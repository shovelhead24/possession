extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/outputs/"
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
func _initialize():
	create_timer(300).timeout.connect(func(): push_error("CRATER_SCENE_TIMEOUT");quit(1))
	run.call_deferred()
func run():
	root.size=Vector2i(1366,768)
	arena=load("res://world/sky_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path and "sky-test" in arena.destruction.save_path)
	for key in arena.destruction.nearby_preparation_keys(): assert(not arena.destruction.edit_cache.needs_warm(arena.source,key),"Full throw range not ready at load")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"crater-ready-briefing.png")
	arena.loading.close()
	if arena.editor.opened: arena.editor.toggle()
	arena.vehicle_kit.test_controls=true;arena.vehicle_kit.test_throttle=0;arena.vehicle_kit.test_brake=true
	var pad=arena.controller;pad.set_physics_process(false)
	var state={"buttons":{},"move":Vector2.ZERO,"look":Vector2.ZERO,"rt":0.0,"lt":0.0}
	arena.sky_comparison.dialog.popup_centered()
	await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;state.buttons[JOY_BUTTON_LEFT_SHOULDER]=true
	var count=get_nodes_in_group("dive_grenades").size();pad.step(state,.016,true)
	assert(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and get_nodes_in_group("dive_grenades").size()==count,"Dialog captured pointer or allowed grenade")
	arena.sky_comparison.dialog.hide();state.buttons={};pad.step(state,.016,true)
	for i in 120: await process_frame
	var records=[]
	var warmed=arena.destruction.warmed_tiles
	for shot in 3:
		while arena.destruction.busy(): await process_frame
		var p=arena.vehicle_kit.car.global_position
		var up=Ring.up_at(p);var forward=Ring.spinward_at(p)
		arena.camera.global_position=p+up*3
		arena.camera.look_at(p+forward*(12+shot*5),up)
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var revision=arena.destruction.revision
		var before=get_nodes_in_group("dive_grenades")
		if shot==0:
			state.buttons[JOY_BUTTON_LEFT_SHOULDER]=true;pad.step(state,.016,true)
		else:
			var event=InputEventKey.new();event.keycode=KEY_B;event.pressed=true;arena._input(event)
		var grenade: Node3D
		for item in get_nodes_in_group("dive_grenades"):
			if item not in before: grenade=item
		assert(grenade and grenade.get_script().resource_path=="res://world/terrain_grenade.gd","L1/B did not throw crater grenade")
		state.buttons={};pad.step(state,.016,true)
		var frames=[];var previous=Time.get_ticks_usec()
		while arena.destruction.applied_revision==revision:
			await process_frame
			var now=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
		frames.sort()
		var d=arena.destruction
		var record={"shot":shot,"input":"L1" if shot==0 else "B","request_to_publish_ms":d.last_queue_ms+d.last_update_ms,"queue_ms":d.last_queue_ms,"geometry_ms":d.last_geometry_ms,"worker_ms":d.last_worker_ms,"collision_worker_ms":d.last_collision_worker_ms,"collision_install_ms":d.last_collision_ms,"mesh_ms":d.last_mesh_ms,"frame_p95_ms":frames[int(frames.size()*.95)],"frame_max_ms":frames[-1],"terrain_triangles":0}
		records.append(record);print("CRATER_SCENE ",JSON.stringify(record))
	assert(arena.destruction.warmed_tiles==warmed,"Stationary fight launched more preparation work")
	# Enter another already-loaded region, with distant streaming paused to
	# exercise preparation independently of generating new terrain tiles.
	arena.streamer.pause_generation=true;arena.vehicle_kit.driving=false
	arena.camera.global_position=Ring.point(800,arena.source.surface_height(Vector2(800,800))+20,800)
	while arena.destruction.busy(): await process_frame
	arena.destruction.refresh_preparation()
	var movement_keys=arena.destruction.preparation_keys.duplicate()
	assert(not movement_keys.is_empty())
	while arena.destruction.busy() or movement_keys.any(func(key): return arena.destruction.edit_cache.needs_warm(arena.source,key)): await process_frame
	assert(arena.destruction.warmed_tiles>warmed,"Entering loaded terrain did not prepare it")
	var file=FileAccess.open(OUT+"crater-scene-after.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "));file.close()
	print("PASS startup throw coverage, modal controller mouse, L1/B crater action, stationary preparation stops, three live scene craters, preparation after moving into loaded terrain")
	quit()
