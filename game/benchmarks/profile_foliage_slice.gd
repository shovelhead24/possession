extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var output="C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs"
var materials=[]
var shaders=[]
var results={}
func _initialize():
	create_timer(420).timeout.connect(func(): push_error("Foliage profile timeout");quit(1))
	run.call_deferred()
func sample(name):
	await create_timer(1.5).timeout
	var values=[];var last=Time.get_ticks_usec();var total=0.0
	for i in 240:
		await process_frame
		var now=Time.get_ticks_usec();var ms=(now-last)/1000.0;last=now;values.append(ms);total+=ms
	values.sort()
	var result={"ms":total/240,"fps":240000/total,"p95_ms":values[228],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"lods":arena.painted_trees.counts.duplicate(),"budget_usec":arena.painted_trees.foliage_budget.update_usec,"batch_update_ms":arena.painted_trees.update_ms}
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
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("foliage-slice-loading.png"))
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
	# Compare the same live placements, camera and shadows with each policy.
	arena.painted_trees.foliage_budget.enabled=false;arena.painted_trees.update_batches()
	await sample("distance_only_close")
	arena.painted_trees.foliage_budget.enabled=true;arena.painted_trees.update_batches()
	await sample("density_budget_close")
	var close_camera=arena.camera.transform
	# A clearer forest-edge view checks silhouette and mid-distance changes.
	var edge=arena.aliens.ground(Ring.point(145,0,280)).position
	arena.camera.position=edge+Ring.tangent_basis(edge,0)*Vector3(13,6,20)
	arena.camera.look_at(edge+Ring.up_at(edge)*2,Ring.up_at(edge))
	await create_timer(3).timeout
	arena.painted_trees.foliage_budget.enabled=false;arena.painted_trees.update_batches();await sample("distance_only_edge")
	arena.painted_trees.foliage_budget.enabled=true;arena.painted_trees.update_batches();await sample("density_budget_edge")
	arena.camera.transform=close_camera
	arena.painted_trees.foliage_budget.enabled=false;arena.painted_trees.update_batches()
	await sample("baseline")
	# Separate real leaf geometry from bark and shadow proxies.
	var original_meshes={};var leafless={}
	for key in arena.painted_trees.batches:
		var batch=arena.painted_trees.batches[key];var mesh=batch.multimesh.mesh
		original_meshes[key]=mesh
		if not leafless.has(mesh):
			var bark=ArrayMesh.new()
			for surface in mesh.get_surface_count():
				if not mesh.surface_get_material(surface) is ShaderMaterial:
					bark.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(surface));bark.surface_set_material(bark.get_surface_count()-1,mesh.surface_get_material(surface))
			leafless[mesh]=bark
		if leafless[mesh].get_surface_count()==0: batch.hide()
		else: batch.multimesh.mesh=leafless[mesh]
	arena.painted_trees.set_physics_process(false)
	await sample("bark_and_proxies_only")
	for key in original_meshes:
		arena.painted_trees.batches[key].multimesh.mesh=original_meshes[key];arena.painted_trees.batches[key].show()
	arena.daylight.proxies.hide();await sample("visible_trees_without_proxies")
	arena.daylight.proxies.show();await sample("baseline_repeat")
	arena.painted_trees.set_physics_process(true)
	arena.painted_trees.foliage_budget.enabled=true;arena.painted_trees.update_batches()
	await sample("slice_final_close")
	# Check a short camera move: policy cost, LOD swaps and geometry remain bounded.
	var values=[];var begin=arena.camera.position;var last=Time.get_ticks_usec()
	for i in 360:
		arena.camera.position=begin+Vector3(sin(float(i)/360.0*TAU)*4,0,0)
		await process_frame
		var now=Time.get_ticks_usec();values.append((now-last)/1000.0);last=now
	values.sort();var total=0.0
	for value in values: total+=value
	results["moving_close"]={"ms":total/values.size(),"p95_ms":values[342],"budget_update_usec":arena.painted_trees.foliage_budget.update_usec,"batch_update_ms":arena.painted_trees.update_ms}
	print("FOLIAGE_MOVING ",JSON.stringify(results["moving_close"]))
	var f=FileAccess.open(output.path_join("foliage-slice-results.json"),FileAccess.WRITE);f.store_string(JSON.stringify(results,"  "));f.close()
	var painter=arena.painted_trees
	var signature=painter.store.signature()
	painter.forced_lod=2;painter.update_batches();assert(painter.counts[0]==0 and painter.counts[1]==0 and painter.counts[3]==0)
	painter.forced_lod=-1;painter.update_batches()
	assert(signature==painter.store.signature())
	assert(painter.density_field.entries.size()==painter.store.records.size())
	assert(painter.bake_density())
	var Field=load("res://world/tree_density_field.gd");var cached=Field.new()
	cached.configure(painter.names,painter.foliage_budget.radii);cached.sync(painter.store.records,false)
	assert(cached.load_cache(painter.store.path+".density.json"))
	arena.editor.toggle()
	var review=arena.editor.foliage_review;review.open()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("foliage-editor-review.png"))
	await review.measure()
	assert(not review.last_result.is_empty())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("foliage-editor-measured.png"))
	print("FOLIAGE_EDITOR_REVIEW ",JSON.stringify(review.last_result))
	print("FOLIAGE_SLICE_PASS");quit()
