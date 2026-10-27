extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/"
var arena: Node3D
var results=[]
func _initialize():
	create_timer(180).timeout.connect(func():push_error("HAZE_TEST_TIMEOUT");quit(1))
	run.call_deferred()
func sample(label: String, frames: int):
	var day=arena.cloud_review.day_cycle;var mismatches=0;var max_error=0.0
	for i in frames:
		await RenderingServer.frame_post_draw
		var tint: Color=day.sky_tint
		var expected=Vector3(.62*tint.r,.74*tint.g,.86*tint.b) if day.enabled else Vector3(arena.backdrop.DAY_HORIZON.r,arena.backdrop.DAY_HORIZON.g,arena.backdrop.DAY_HORIZON.b)
		for key in day.backdrop_materials():
			var actual: Vector3=arena.backdrop.get(key).get_shader_parameter("sky_color")
			var error=actual.distance_to(expected);max_error=maxf(max_error,error)
			if error>.0001:mismatches+=1
	results.append({"case":label,"frames":frames,"mismatched_material_frames":mismatches,"max_colour_error":max_error})
	print("HAZE_CASE ",JSON.stringify(results[-1]))
func run():
	root.size=Vector2i(1366,768)
	arena=load("res://world/performance_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter:await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path and "sky-test" in arena.destruction.save_path)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"haze-fix-briefing.png")
	arena.loading.close();Engine.max_fps=0
	var day=arena.cloud_review.day_cycle
	day.set_hour(6.3);await sample("sunrise_held",120)
	day.set_hour(17.7);await sample("sunset_held",120)
	day.animate=true;day.hours_per_second=.25;await sample("sunset_animated",120)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"haze-fix-sunset.png")
	day.reset();await sample("restored",120)
	var failed=false
	for row in results:failed=failed or row.mismatched_material_frames>0
	var name="haze-before" if "--haze-before" in OS.get_cmdline_user_args() else "haze-after"
	FileAccess.open(OUT+name+".json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("HAZE_TEST_FAIL" if failed else "HAZE_TEST_PASS");quit(2 if failed else 0)
