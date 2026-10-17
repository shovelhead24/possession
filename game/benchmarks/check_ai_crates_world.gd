extends "res://benchmarks/check_actor_world.gd"
func run():
	Engine.max_fps=120
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	check(arena.actors.store.path.contains("ai-crate-saves"),"Isolated actor save required")
	await capture("ai-crates-brief.png")
	arena.loading.close();arena.diagnostic=true;arena.vehicle_kit.driving=false;arena.on_foot.active=false
	var editor=arena.editor;var world=arena.actors
	editor.toggle();editor.select_tool("actors")
	var origin=Ring.coordinates(arena.vehicle_kit.car.position);var placed=[]
	await create_timer(1).timeout
	for i in 35:
		var angle=i*2.4;var distance=15+sqrt(i)*3
		var point=arena.aliens.safe_spawn(Ring.point(origin.x+cos(angle)*distance,origin.y,origin.z+sin(angle)*distance))
		if point==Vector3.INF: continue
		if not placed.is_empty() and point.distance_to(Store.point(world.store.find(placed[0]).p))<4: continue
		editor.begin_place("crate");editor.commit_at(point);placed.append(editor.actor_id)
		if placed.size()==2: break
	check(placed.size()==2,"Place two heavy crates")
	editor.begin_operation("add_point");check(editor.operation!="add_point","Crates cannot acquire AI routes")
	check(world.store.save(),"Crates save with actor layout");check(world.store.load_saved(),"Crates reload")
	editor.focus_actor();await create_timer(.2).timeout;await capture("heavy-crate-editor.png")
	editor.toggle();await create_timer(4).timeout
	for id in placed: check(world.live.has(id) and world.live[id].mass==160,"Authored crate instantiated")
	check(not arena.ai_debug.samples.is_empty(),"AI diagnostics sample active scene")
	var toggle=InputEventKey.new();toggle.keycode=KEY_F4;toggle.pressed=true
	arena._input(toggle);check(not arena.ai_debug.enabled,"F4 disables labels")
	arena._input(toggle);check(arena.ai_debug.enabled,"F4 enables labels")
	var recorder=arena.jitter_trace;recorder.toggle();await create_timer(1.2).timeout;recorder.toggle()
	while recorder.writer: await process_frame
	var events={};var recorded=FileAccess.get_file_as_string(recorder.path)
	for line in recorded.split("\n",false):
		var row=JSON.parse_string(line)
		if row is Dictionary: events[row.get("event","")]=true
	check(events.has("ai_preroll") and events.has("ai_snapshot") and events.has("capture_end"),"Actual F8 JSONL includes AI pre-roll and samples")
	await capture("ai-world-labels.png")
	print("AI_CRATES_WORLD_PASS: two editor crates, save/reload, runtime physics, F4 labels, rendered briefing and actual F8 recording at ",recorder.path)
	arena.free();quit()
