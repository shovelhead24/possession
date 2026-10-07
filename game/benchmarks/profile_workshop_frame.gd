extends SceneTree
var scene: Node
var reports: Array=[]

func _initialize() -> void:
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	create_timer(600).timeout.connect(func(): push_error("Workshop frame profile timeout");quit(1))
	run.call_deferred()

func settle() -> void:
	while not scene.live_kit() or scene.ready_frames<3 or not scene.collision_pending.is_empty() or not scene.far_terrain.finished() or not scene.terrain_lod.finished(): await process_frame
	while scene.ring_background.home_pending or scene.ring_background._preview_thread or not scene.ring_background._preview_queue.is_empty() or scene.satellite_stream.worker or not scene.satellite_stream.uploads.is_empty(): await process_frame
	for i in 30: await process_frame

func sample(label: String) -> void:
	for i in 10: await process_frame
	var frames := [];var cpu := [];var physics := []
	var streaming_frames := 0
	var last := Time.get_ticks_usec()
	for i in 120:
		await process_frame
		if not scene.stream_jobs.is_empty() or not scene.collision_pending.is_empty() or not scene.far_terrain.finished() or not scene.terrain_lod.finished(): streaming_frames+=1
		var now := Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
	var total := 0.0;var missed := 0
	for value in frames: total+=value;missed+=int(value>16.667)
	frames.sort();cpu.sort();physics.sort()
	var result := {"label":label,"fps":120000.0/total,"median_ms":frames[60],"p95_ms":frames[114],"p99_ms":frames[118],"max_ms":frames[-1],"over_16_67_ms":missed,"cpu_median_ms":cpu[60],"physics_median_ms":physics[60],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"resident_chunks":scene.chunks.size(),"resolution":str(root.get_visible_rect().size)}
	result.streaming_frames=streaming_frames
	reports.append(result);print("WORKSHOP_FRAME_PROFILE ",JSON.stringify(result))
	if label in ["spawn_full","bridge_full"]:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://profile-"+label+".png")

func run() -> void:
	scene=load("res://world/sdf_stress_course.tscn").instantiate();root.add_child(scene)
	scene.set_process_input(false);scene.set_physics_process(false)
	await settle()
	for group in scene.arena_content.tree_batches:
		assert(group.batches.size()==4,"Workshop tree tier missing")
		assert(group.batches[3].multimesh.mesh==group.batches[2].multimesh.mesh,"Far trees must preserve atlas UVs")
		for level in 4:
			assert(group.batches[level].cast_shadow==(GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level==0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	scene.switch_editor_mode(false)
	await sample("spawn_full")
	for entry in scene.arena_content.entries:
		var triangles := 0
		for mesh in entry.model.find_children("*","MeshInstance3D",true,false):
			if not mesh.mesh or mesh.layers==0: continue
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
		print("SOURCE_TRIANGLES ",entry.name," ",triangles)
	if OS.get_cmdline_user_args().has("--scene-isolation"):
		scene.ring_background._clouds.hide();scene.sun.shadow_enabled=false
		await sample("lighting_reduced")
		for entry in scene.arena_content.entries: entry.root.hide()
		await sample("lighting_and_models_hidden")
		for entry in scene.arena_content.entries: entry.root.show()
		var saved := []
		var flat := StandardMaterial3D.new();flat.albedo_color=Color(.4,.5,.3)
		for mesh in scene.find_children("*","MeshInstance3D",true,false):
			if mesh==scene.terrain: continue # Shared template is also read by streaming code.
			if mesh.material_override is ShaderMaterial and mesh.material_override.shader==scene.terrain.material_override.shader:
				saved.append([mesh,mesh.material_override]);mesh.material_override=flat
		await sample("lighting_reduced_simple_terrain")
		for pair in saved: pair[0].material_override=pair[1]
		scene.ring_background.hide()
		await sample("lighting_reduced_backdrop_hidden")
		scene.ring_background.show();scene.ring_background._clouds.hide()
		root.disable_3d=true
		await sample("main_3d_disabled")
		root.disable_3d=false
		await sample("lighting_reduced_restored")
		print("SCENE_PROFILE_COMPLETE");quit();return
	if OS.get_cmdline_user_args().has("--tree-isolation"):
		scene.set_trees_visible(false)
		for group in scene.arena_content.tree_batches:
			for batch in group.batches: assert(not batch.visible)
		assert(not scene.painted_trees.visible and not scene.trees_toggle.button_pressed)
		await sample("trees_hidden")
		scene.set_trees_visible(true)
		for group in scene.arena_content.tree_batches:
			for batch in group.batches: assert(batch.visible)
		assert(scene.painted_trees.visible and scene.trees_toggle.button_pressed)
		await sample("trees_restored")
		print("TREE_PROFILE_COMPLETE");quit();return
	if OS.get_cmdline_user_args().has("--cloud-occlusion-isolation"):
		root.use_occlusion_culling=false
		await sample("occlusion_disabled")
		for layer in scene.ring_background._clouds._layers: layer.material_override.set_shader_parameter("cached_noise",false)
		await sample("procedural_cloud_noise")
		scene.ring_background._clouds.hide()
		await sample("clouds_hidden")
		scene.sun.shadow_enabled=false
		await sample("clouds_and_shadows_hidden")
		print("CLOUD_OCCLUSION_PROFILE_COMPLETE");quit();return
	if OS.get_cmdline_user_args().has("--resolution-isolation"):
		for scale in [.85,.75,.67,.5]:
			root.scaling_3d_scale=scale
			await sample("spawn_scale_"+str(scale))
		root.scaling_3d_scale=1.0
		await sample("spawn_native_restored")
		print("RESOLUTION_PROFILE_COMPLETE");quit();return
	if OS.get_cmdline_user_args().has("--gpu-isolation"):
		var clouds: Node3D=scene.ring_background._clouds
		clouds.hide()
		await sample("spawn_clouds_hidden")
		var original_shadow: bool=scene.sun.shadow_enabled
		scene.sun.shadow_enabled=false
		await sample("spawn_clouds_hidden_no_shadows")
		scene.sun.shadow_enabled=original_shadow;clouds.show()
		var kit: Node=scene.live_kit()
		var modes := []
		for entry in scene.arena_content.entries:
			modes.append([entry.root,entry.root.process_mode]);entry.root.process_mode=Node.PROCESS_MODE_DISABLED
			if entry.root is RigidBody3D: entry.root.freeze=true
		kit.process_mode=Node.PROCESS_MODE_DISABLED;scene.vehicle_trace.process_mode=Node.PROCESS_MODE_DISABLED
		await sample("spawn_simulation_paused")
		for pair in modes:
			pair[0].process_mode=pair[1]
			if pair[0] is RigidBody3D: pair[0].freeze=false
		kit.process_mode=Node.PROCESS_MODE_INHERIT;scene.vehicle_trace.process_mode=Node.PROCESS_MODE_INHERIT
		await sample("spawn_full_restored")
		print("WORKSHOP_GPU_PROFILE_COMPLETE");quit();return
	var started := Time.get_ticks_usec()
	var legacy_features := {}
	for z in range(-8,8):
		for x in range(-8,8):
			if x>=-3 and x<3 and z>=-3 and z<3: continue
			var key := Vector2i(x,z)
			legacy_features[key]=JSON.stringify(scene.Recipe.relevant(scene.features,Rect2(Vector2(key)*256,Vector2.ONE*256).grow(130)))
	print("WORKSHOP_LEGACY_RECIPE_SCAN_PROFILE ms=",(Time.get_ticks_usec()-started)/1000.0)
	started=Time.get_ticks_usec()
	scene.terrain_lod.plan()
	print("WORKSHOP_PLAN_PROFILE ms=",(Time.get_ticks_usec()-started)/1000.0)
	await settle()
	var shadow: bool=scene.sun.shadow_enabled
	scene.sun.shadow_enabled=false
	await sample("spawn_no_shadows")
	scene.sun.shadow_enabled=shadow
	var visuals := []
	for entry in scene.arena_content.entries: visuals.append([entry.root,entry.root.visible]);entry.root.hide()
	await sample("spawn_models_hidden")
	for pair in visuals: pair[0].visible=pair[1]
	var textured: bool=scene.terrain.material_override.get_shader_parameter("textured")
	scene.terrain.material_override.set_shader_parameter("textured",false)
	for tile in scene.terrain_lod.tiles.values(): tile.node.material_override.set_shader_parameter("textured",false)
	await sample("spawn_flat_terrain_material")
	scene.terrain.material_override.set_shader_parameter("textured",textured)
	for tile in scene.terrain_lod.tiles.values(): tile.node.material_override.set_shader_parameter("textured",textured)
	root.disable_3d=true
	await sample("spawn_main_3d_disabled")
	root.disable_3d=false
	await sample("spawn_full_restored")
	scene.camera.position=Vector3(-14,4,-206);scene.camera.look_at(Vector3(-14,4,-260));scene.ready_frames=0
	await settle()
	await sample("bridge_full")
	started=Time.get_ticks_usec();scene.terrain_lod.plan()
	print("WORKSHOP_BRIDGE_PLAN_PROFILE ms=",(Time.get_ticks_usec()-started)/1000.0)
	await settle()
	var path := "user://workshop-frame-profile.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile-output="): path=arg.trim_prefix("--profile-output=")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"gpu":RenderingServer.get_video_adapter_name(),"reports":reports},"\t"));file.close()
	print("WORKSHOP_FRAME_PROFILE_COMPLETE ",path);quit()
