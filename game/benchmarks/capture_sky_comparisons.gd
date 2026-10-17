extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/outputs/revision-2/"
var arena: Node3D
func _initialize():
	create_timer(420).timeout.connect(func(): push_error("Sky capture timeout");quit(1))
	run.call_deferred()
func capture(label: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func run():
	root.size=Vector2i(1366,768)
	arena=load("res://world/sky_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path)
	await capture("sky-briefing")
	arena.loading.close()
	arena.editor.toggle()
	arena.editor.layer.hide();arena.hud.hide()
	arena.process_mode=Node.PROCESS_MODE_DISABLED
	var sky=arena.sky_comparison
	sky.process_mode=Node.PROCESS_MODE_ALWAYS
	var pos=arena.vehicle_kit.car.global_position+Vector3(0,6,0)
	arena.camera.position=pos
	arena.camera.look_at(pos+Vector3(0,0.48,1).normalized()*100)
	Engine.max_fps=60
	assert(not sky.painted and not sky.clouds_enabled and sky.legacy.billboard_enabled)
	sky.apply_preset(0)
	var light=arena.daylight.sun.light_energy
	var original=arena.daylight.environment.sky
	for mode in sky.PRESETS.size():
		sky.apply_preset(mode)
		for i in 180: await process_frame
		if mode in [2,6,8]:
			for i in 900:
				await process_frame
				if sky.legacy.pending.is_empty(): break
		await capture("sky-%02d" % mode)
		if mode==2:
			var smooth_count=0
			var known={}
			for chunk in sky.legacy._chunks.values():
				var arrays=chunk.mi.mesh.surface_get_arrays(0)
				var verts=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL]
				for n in normals: assert(absf(n.length()-1.0)<0.001)
				for j in range(0,normals.size(),3):
					if normals[j].distance_to(normals[j+1])>0.001: smooth_count+=1
				for j in verts.size():
					if known.has(verts[j]): assert(known[verts[j]].distance_to(normals[j])<0.001)
					known[verts[j]]=normals[j]
			assert(smooth_count>100)
			print("PASS smooth MC normals: ",smooth_count," interpolated triangles; shared vertices agree")
		print("CAPTURE ",mode," ",sky.PRESETS[mode]," ",sky.legacy.status() if sky.legacy else "")
		assert(arena.daylight.sun.light_energy==light)
	sky.apply_preset(3);sky.set_brightness(0.5)
	for i in 30: await process_frame
	await capture("sky-dark-legacy")
	sky.set_brightness(1.0)
	sky.apply_preset(0)
	assert(arena.daylight.environment.sky==original)
	assert(not sky.clouds.visible and not sky.legacy.visible)
	sky.dialog.popup_centered()
	for i in 5: await process_frame
	await capture("sky-controls")
	print("PASS sky modes render, combinations, exact sky restore and unchanged sun")
	quit()
