extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var output="C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs"
var materials=[]
var shaders=[]
var results={}
func _initialize():
	create_timer(300).timeout.connect(func(): push_error("Foliage profile timeout");quit(1))
	run.call_deferred()
func sample(name):
	await create_timer(1.5).timeout
	var values=[];var last=Time.get_ticks_usec();var total=0.0
	for i in 240:
		await process_frame
		var now=Time.get_ticks_usec();var ms=(now-last)/1000.0;last=now;values.append(ms);total+=ms
	values.sort()
	var result={"ms":total/240,"fps":240000/total,"p95_ms":values[228],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"lods":arena.painted_trees.counts.duplicate()}
	results[name]=result;print("FOLIAGE_PROFILE ",name," ",JSON.stringify(result))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("foliage-"+name+".png"))
func shader_mode(mode):
	for i in materials.size():
		if mode=="original": materials[i].shader=shaders[i];continue
		var code=shaders[i].code
		if mode=="no_leaf_pixels": code=code.replace("void fragment() {","void fragment() { discard;")
		if mode=="no_prepass": code=code.replace(", depth_prepass_alpha","")
		if mode=="scissor":
			code=code.replace(", depth_prepass_alpha","")
			code=code.replace("if (c.a < cut) {\n\t\tdiscard;\n\t}","ALPHA=c.a; ALPHA_SCISSOR_THRESHOLD=cut;")
		var shader=Shader.new();shader.code=code;materials[i].shader=shader
func run():
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert(arena.forge.store.path.contains("collision-saves"))
	arena.loading.close();arena.vehicle_kit.car.freeze=true;arena.vehicle_kit.driving=false;arena.diagnostic=true
	arena.aliens.process_mode=Node.PROCESS_MODE_DISABLED;arena.aliens.hide()
	var feet=arena.aliens.ground(Ring.point(145,0,258)).position
	arena.on_foot.activate_at(feet);arena.on_foot.set_process(false);arena.on_foot.set_physics_process(false)
	arena.camera.position=feet+Ring.up_at(feet)*1.54
	arena.camera.look_at(Ring.point(145,feet.y+1,280),Ring.up_at(feet))
	await create_timer(8).timeout
	arena.daylight.set_process(false) # Hold explicit proxy visibility for each measurement.
	for species in arena.trees.variants:
		for mesh in arena.trees.variants[species]:
			for surface in mesh.get_surface_count():
				var mat=mesh.surface_get_material(surface)
				if mat is ShaderMaterial and mat not in materials: materials.append(mat);shaders.append(mat.shader)
	await sample("baseline")
	arena.daylight.proxies.hide();await sample("no_tree_shadows")
	arena.daylight.proxies.show();shader_mode("no_leaf_pixels");await sample("no_leaf_pixels")
	shader_mode("original");arena.trees.hide();arena.painted_trees.hide();await sample("no_tree_visuals")
	arena.daylight.proxies.hide();await sample("no_trees_or_proxies")
	arena.trees.show();arena.painted_trees.show();arena.daylight.proxies.show()
	shader_mode("no_prepass");await sample("no_prepass")
	shader_mode("scissor");await sample("native_scissor")
	shader_mode("original")
	arena.painted_trees.forced_lod=1;arena.painted_trees.update_batches();await sample("all_lod1")
	arena.painted_trees.forced_lod=2;arena.painted_trees.update_batches();await sample("all_lod2")
	arena.painted_trees.forced_lod=-1;arena.painted_trees.update_batches();await sample("baseline_repeat")
	var f=FileAccess.open(output.path_join("foliage-isolation.json"),FileAccess.WRITE);f.store_string(JSON.stringify(results,"  "));f.close()
	print("FOLIAGE_ISOLATION_PASS");quit()
