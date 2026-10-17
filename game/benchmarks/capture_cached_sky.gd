extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/outputs/"
var arena: Node3D
func _initialize():
	create_timer(300).timeout.connect(func(): push_error("Cached sky capture timeout");quit(1))
	run.call_deferred()
func capture(label: String):
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"cached-sky-"+label+".png")
func run():
	root.size=Vector2i(1366,768)
	arena=load("res://world/sky_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path)
	var sky=arena.sky_comparison
	assert(sky.preset_picker.selected==9 and sky.painted and sky.legacy.billboard_enabled)
	await capture("briefing")
	arena.loading.close();arena.editor.toggle();arena.editor.layer.hide();arena.hud.hide()
	arena.process_mode=Node.PROCESS_MODE_DISABLED;sky.process_mode=Node.PROCESS_MODE_ALWAYS
	var p=arena.vehicle_kit.car.global_position+Vector3(0,6,0)
	arena.camera.position=p
	for i in 100: await process_frame
	assert(sky.legacy.cached.queue.is_empty())
	var ids=[]
	for entry in sky.legacy.cached.chunks.values(): ids.append(entry.node.get_instance_id())
	arena.camera.look_at(p+Vector3(0,0.48,1)*100);await capture("combined")
	sky.set_painted(false);assert(not sky.high_painterly.visible);await capture("billboards")
	sky.set_painted(true)
	for sign in [-1,1]:
		arena.camera.look_at(p+Vector3(sign,0.15,0)*100);await capture("ring-negative" if sign<0 else "ring-positive")
	arena.camera.look_at(p+Vector3.UP*100,Vector3.FORWARD);await capture("overhead")
	sky.high_painterly.set_altitude(10000);assert(sky.high_painterly.material_override.get_shader_parameter("altitude")==10000)
	sky.high_painterly.set_altitude(6000)
	sky.set_brightness(0.5);assert(sky.high_painterly.material_override.get_shader_parameter("cloud_brightness")==0.5)
	sky.set_brightness(1.0)
	sky.apply_preset(0);assert(not sky.high_painterly.visible and not sky.legacy.visible)
	sky.apply_preset(9)
	for entry in sky.legacy.cached.chunks.values(): assert(entry.node.get_instance_id() in ids,"Toggle rebuilt cached batches")
	sky.dialog.popup_centered();await capture("controls")
	print("PASS combined default, layer visibility/altitude/brightness, shader rendering and retained batches across toggles")
	quit()
