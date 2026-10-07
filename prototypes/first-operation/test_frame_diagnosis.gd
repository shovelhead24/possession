extends SceneTree

var arena: Node
var predator: Node

func _initialize() -> void: call_deferred("run")

func sample(label: String) -> void:
	for frame in 45: await process_frame
	var timings: Array[float]=[]
	var cpu=0.0;var physics=0.0;var draws=0.0;var primitives=0.0
	var previous=Time.get_ticks_usec()
	for frame in 120:
		await process_frame
		var now=Time.get_ticks_usec();timings.append((now-previous)*.001);previous=now
		cpu+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
		physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var mean=0.0
	for timing in timings: mean+=timing/timings.size()
	timings.sort()
	print("PERF ",label," fps=",snappedf(1000.0/mean,.1)," mean_ms=",snappedf(mean,.01)," p95_ms=",snappedf(timings[113],.01)," process_ms=",snappedf(cpu/120,.01)," physics_ms=",snappedf(physics/120,.01)," draws=",roundi(draws/120)," triangles=",roundi(primitives/120))

func run() -> void:
	arena=load("res://tactical.tscn").instantiate();root.add_child(arena)
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	predator=arena.get_node("PracticeRange").trex
	if "--live-profile" in OS.get_cmdline_user_args():
		# Time the original modifier without altering any shipped source file.
		var timed=GDScript.new()
		timed.source_code='extends "res://trex_grounding.gd"\nvar samples: Array[int]=[]\nfunc _process_modification() -> void:\n\tvar started=Time.get_ticks_usec()\n\tsuper._process_modification()\n\tsamples.append(Time.get_ticks_usec()-started)\n'
		assert(timed.reload()==OK)
		predator.grounding.set_script(timed);predator.grounding.setup(predator)
		await sample("live_spawn_all_on")
		predator.grounding.active=false
		await sample("live_spawn_grounding_off")
		predator.grounding.active=true
		await sample("live_spawn_grounding_restored")
		var timings: Array=predator.grounding.samples
		timings.sort();var total=0.0
		for timing in timings: total+=timing
		print("MODIFIER_CPU calls=",timings.size()," mean_ms=",total/maxi(1,timings.size())/1000.0," p95_ms=",timings[int(timings.size()*.95)]/1000.0," max_ms=",timings[-1]/1000.0)
		print("DONE live frame diagnosis")
		quit();return
	# Fix the view and actors, leaving animation, skinning, rendering, terrain
	# detail and vehicle simulation active. All toggles are test-instance only.
	arena.set_physics_process(false);arena.kit.set_physics_process(false)
	predator.set_physics_process(false)
	for enemy in predator.manager.enemies: enemy.set_physics_process(false)
	arena.camera.position=Vector3(-48,arena.height_at(-48,-42)+5,-42)
	arena.camera.look_at(predator.position+Vector3(0,4,1))
	await sample("baseline_near_tyrant")
	predator.grounding.active=false
	await sample("grounding_off")
	predator.grounding.active=true
	await sample("grounding_restored")
	var sun: DirectionalLight3D
	for node in arena.get_children():
		if node is DirectionalLight3D: sun=node
	sun.shadow_enabled=false
	await sample("shadows_off")
	sun.shadow_enabled=true
	var full_size=root.size
	root.size=Vector2i(640,400)
	await sample("half_resolution")
	root.size=full_size
	predator.model.hide();predator.animator.pause();predator.grounding.active=false
	await sample("tyrant_model_off")
	predator.model.show();predator.animator.play();predator.grounding.active=true
	await sample("baseline_repeat")
	arena.viewpoint(1)
	await sample("shortcut_spawn_view")
	print("DONE frame diagnosis; no gameplay settings saved")
	quit()
