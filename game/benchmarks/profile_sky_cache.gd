extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/outputs/"
var arena: Node3D
var origin: Vector3
func _initialize():
	create_timer(360).timeout.connect(func(): push_error("Sky profile timeout");quit(1))
	run.call_deferred()
func sample(moving: bool) -> Dictionary:
	for i in 90: await process_frame
	var samples=[];var last=Time.get_ticks_usec()
	for i in 240:
		if moving:
			arena.camera.position=origin+Vector3(i*16.0,0,0)
		await process_frame
		var now=Time.get_ticks_usec();samples.append((now-last)/1000.0);last=now
	var sum=0.0
	for t in samples: sum+=t
	samples.sort()
	return {"mean_ms":sum/samples.size(),"p95_ms":samples[228],"max_ms":samples[-1],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func run():
	root.size=Vector2i(1366,768);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	var old=OS.get_cmdline_user_args().has("--before")
	arena=load("res://benchmarks/sky_before/sky_demo.tscn" if old else "res://world/sky_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path)
	arena.loading.close();arena.editor.toggle();arena.editor.layer.hide();arena.hud.hide()
	arena.process_mode=Node.PROCESS_MODE_DISABLED
	var sky=arena.sky_comparison;sky.process_mode=Node.PROCESS_MODE_ALWAYS
	origin=arena.vehicle_kit.car.global_position+Vector3(0,6,0)
	arena.camera.position=origin;arena.camera.look_at(origin+Vector3(0,0.48,1).normalized()*100)
	Engine.max_fps=0
	var results={}
	sky.apply_preset(0);results.baseline=await sample(false)
	sky.apply_preset(1);results.billboards=await sample(false)
	sky.set_painted(true);results.combined=await sample(false)
	var tag="before" if OS.get_cmdline_user_args().has("--before") else "after"
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"cloud-cache-"+tag+".png")
	results.moving=await sample(true)
	arena.camera.position=origin;sky.apply_preset(0);results.baseline_again=await sample(false)
	FileAccess.open(OUT+"cloud-profile-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("SKY_PROFILE ",tag," ",JSON.stringify(results))
	quit()
