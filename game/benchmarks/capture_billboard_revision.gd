extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/outputs/billboard-fixed/"
var arena: Node3D
func _initialize():
	create_timer(240).timeout.connect(func(): push_error("Billboard scene timeout");quit(1))
	run.call_deferred()
func capture(label: String):
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func run():
	root.size=Vector2i(1366,768)
	arena=load("res://world/sky_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path)
	assert(arena.sky_comparison.preset_picker.selected==1)
	assert(arena.sky_comparison.legacy.billboard_enabled)
	await capture("briefing")
	arena.loading.close();arena.editor.toggle();arena.editor.layer.hide();arena.hud.hide()
	arena.process_mode=Node.PROCESS_MODE_DISABLED
	arena.sky_comparison.process_mode=Node.PROCESS_MODE_ALWAYS
	var pos=arena.vehicle_kit.car.global_position+Vector3(0,6,0)
	arena.camera.position=pos
	for i in 180: await process_frame
	arena.camera.look_at(pos+Vector3(0,0.48,1).normalized()*100)
	await capture("approved-view")
	for sign in [-1,1]:
		arena.camera.look_at(pos+Vector3(sign,0.15,0)*100)
		await capture("ring-negative" if sign<0 else "ring-positive")
	arena.camera.look_at(pos+Vector3.UP*100,Vector3.FORWARD)
	await capture("overhead")
	for step in 8:
		var angle=step*TAU/8
		arena.camera.look_at(pos+Vector3(sin(angle)*0.15,1,cos(angle)*0.15)*100,Vector3.FORWARD)
		await capture("overhead-turn-%02d" % step)
	assert(arena.sky_comparison.legacy.horizon.signed_counts.x>50 and arena.sky_comparison.legacy.horizon.signed_counts.y>50)
	arena.sky_comparison.apply_preset(0)
	assert(not arena.sky_comparison.legacy.visible)
	arena.sky_comparison.apply_preset(1)
	assert(arena.sky_comparison.legacy.visible and arena.sky_comparison.legacy.horizon.visible)
	print("PASS full scene billboard default, both directions, overhead capture and off/on restore")
	quit()
