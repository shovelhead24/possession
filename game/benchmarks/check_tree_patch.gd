extends SceneTree
const Ring = preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-output="): output=arg.trim_prefix("--tree-output=")
	assert(not output.is_empty(),"Explicit output directory required")
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(420).timeout.connect(func(): push_error("Tree patch timed out");quit(1))
	run.call_deferred()

func run() -> void:
	arena=load("res://world/tree_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play: await process_frame
	arena.vehicle_kit.driving=false;arena.vehicle_kit.car.freeze=true
	arena.loading.ready_to_enter=true;arena.loading.close();arena.set_tree_view(0)
	await create_timer(2).timeout
	var trees: Node3D=arena.trees
	assert(trees.candidates.size()>=512)
	var valid := 0
	for i in trees.count_limit:
		var item: Dictionary=trees.candidates[i]
		if not item.valid: continue
		valid+=1
		assert(item.transform.basis.y.normalized().dot(Ring.up_at(item.transform.origin))>.999)
		assert(item.transform.basis.determinant()>0)
	assert(valid>80,"Insufficient grounded trees")
	print("TREE_TEST grounded ",valid)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("initial.png"))
	assert(trees.choose_lod(23,0)==0 and trees.choose_lod(28,0)==1)
	assert(trees.choose_lod(108,3)==3 and trees.choose_lod(100,3)==2)
	assert(trees.choose_lod(23,3)==1,"Teleport must not retain a distant LOD")
	for name in trees.variants:
		var lods: Array=trees.variants[name]
		assert(lods.size()==4 and lods[3]!=lods[2])
		assert(lods[3].surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()==60)
	if OS.get_cmdline_user_args().has("--tree-smoke"):
		for view in 3:
			arena.set_tree_view(view)
			for lod in [-1,0,1,2,3]:
				trees.forced_lod=lod;trees.update_batches();await process_frame
			trees.forced_lod=-1;trees.update_batches()
			await create_timer(2).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("view-"+str(view)+".png"))
		print("TREE_SMOKE_PASS views=3 LOD switches=15")
		quit();return
	# Actual terrain publication: an isolated grenade cut must invalidate grounding.
	var selected: Dictionary={}
	for item in trees.candidates:
		if item.valid and item.height>5: selected=item;break
	var old_position: Vector3=selected.transform.origin
	var old_body_id: int=selected.body_id
	assert(arena.request_crater(old_position,3.5))
	print("TREE_TEST crater requested")
	while arena.destruction.busy(): await process_frame
	await create_timer(1).timeout
	assert(selected.body_id!=old_body_id,"Published edit did not invalidate tree grounding")
	assert(not selected.valid or selected.transform.origin.distance_to(old_position)>.1,"Tree ignored excavated ground")
	print("TREE_TEST crater passed")
	arena.destruction.undo()
	while arena.destruction.busy(): await process_frame
	await create_timer(1).timeout
	assert(selected.valid and selected.transform.origin.distance_to(old_position)<.02,"Undo did not restore grounding")
	print("TREE_TEST undo passed")
	# Evict/reload a tile without modifying terrain files.
	var key := Vector2i((selected.point/200.0).floor())
	var resident: Dictionary=arena.tile_entries[key]
	arena.streamer.set_process(false);arena.streamer.set_physics_process(false);arena.tile_entries.erase(key)
	await create_timer(1).timeout
	assert(not selected.valid and not is_instance_valid(selected.body))
	arena.tile_entries[key]=resident
	await create_timer(1).timeout
	assert(selected.valid)
	arena.streamer.set_process(true);arena.streamer.set_physics_process(true)
	trees.set_enabled(false)
	await process_frame
	for item in trees.candidates: assert(not is_instance_valid(item.body))
	trees.set_enabled(true)
	print("TREE_TEST eviction/reload and toggle passed")
	var report := {"functional_pass":true,"grounded_at_128":valid,"renderer":RenderingServer.get_current_rendering_method(),"assets":trees.Assets.audit(trees.variants),"measurements":[]}
	if DisplayServer.get_name()!="headless":
		Engine.max_fps=0
		for count in [128,256,512]:
			trees.set_density(count);trees.forced_lod=-1
			await create_timer(2).timeout
			for active in [false,true,false,true]:
				trees.set_enabled(active)
				await create_timer(1).timeout
				report.measurements.append(await measure(count,active))
			trees.set_enabled(true)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("trees-"+str(count)+".png"))
		# Same camera / population, every authored LOD including original atlas cards.
		trees.set_density(128)
		for lod in [-1,0,1,2,3]:
			trees.forced_lod=lod;trees.update_batches()
			await create_timer(1).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("lod-"+str(lod)+".png"))
	var file := FileAccess.open(output.path_join("tree-patch-results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("TREE_PATCH_PASS ",JSON.stringify(report))
	quit()

func measure(count: int, active: bool) -> Dictionary:
	var times: Array[float]=[];var start := Time.get_ticks_usec();var previous := start
	while Time.get_ticks_usec()-start<3000000:
		await process_frame
		var now := Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
	times.sort()
	return {"density":count,"trees":active,"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"frames":times.size(),"lod_counts":arena.trees.counts.duplicate(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
