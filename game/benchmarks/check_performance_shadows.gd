extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/"
func _initialize():run.call_deferred()
func run():
	create_timer(180).timeout.connect(func():push_error("SHADOW_VALIDATION_TIMEOUT");quit(1))
	root.size=Vector2i(1366,768)
	var arena=load("res://world/performance_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter:await process_frame
	var day=arena.daylight
	var expected=2048 if "--high-resolution-shadows" in OS.get_cmdline_user_args() else 1024
	assert(day.applied_shadow_map_size==expected)
	assert(day.shadow_distance==121.0 and day.shadow_filter==1)
	assert(day.sun.directional_shadow_mode==DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"shadow-briefing.png")
	day.shadow_quality=2;day.apply();assert(day.applied_shadow_map_size==2048)
	day.shadow_quality=1;day.apply();assert(day.applied_shadow_map_size==1024)
	day.shadow_quality=0;day.apply();assert(day.applied_shadow_map_size==expected)
	day.balanced_shadow_map_size=2048;day.apply();assert(day.applied_shadow_map_size==2048)
	day.balanced_shadow_map_size=expected;day.apply()
	print("SHADOW_VALIDATION_PASS: defaults, range, filter, preset switching and resolution restore");quit()
