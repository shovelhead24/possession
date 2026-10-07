extends SceneTree
var scene: Node3D
var reports: Array=[]
var passed := true
var output := ""
var presentation := false

func _initialize() -> void:
	presentation=OS.get_cmdline_user_args().has("--presentation-profile")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	create_timer(600).timeout.connect(func(): push_error("BASELINE_TIMEOUT");quit(1))
	run.call_deferred()

func require(condition: bool, message: String) -> void:
	if not condition:
		passed=false;push_error(message)

func run() -> void:
	root.size=Vector2i(1280,800)
	scene=load("res://world/terrain_baseline.tscn").instantiate();root.add_child(scene)
	while not scene.ready_to_play: await process_frame
	await physics_frame
	check_geometry()
	if OS.get_cmdline_user_args().has("--validate-only"):
		print("BASELINE_GEOMETRY_", "PASS" if passed else "FAIL");quit(0 if passed else 1);return
	if presentation:
		scene.set_view(3);root.mesh_lod_threshold=0
		for i in 60: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/terrain-tunnel-full-detail.png")
		root.mesh_lod_threshold=2.0
		Engine.max_fps=120;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var views := ["whole_area","bridge"] if presentation else ["overview","bridge","tunnel","whole_area","traverse","rotate","bridge_repeat"]
	for label in views:
		await sample(label)
	var file := FileAccess.open(output+("/terrain-presentation-results.json" if presentation else "/terrain-baseline-results.json"),FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"passed":passed,"reports":reports},"\t"))
	print("PRESENTATION_PROFILE_" if presentation else "BASELINE_PROFILE_", "PASS" if passed else "FAIL")
	quit(0 if passed else 2)

func check_geometry() -> void:
	require(scene.tiles.size()==256,"Expected all 256 tiles")
	require(scene.source.elevation.size()==3840*3840*2,"Native DEM not loaded")
	var edge_counts := {}
	for tile in scene.tiles:
		var arrays: Array=tile.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for p in vertices:
			require(is_finite(p.y),"Nonfinite terrain height")
			# Absolute metres: the old relative tolerance misclassified points 2 mm off the border.
			if absf(p.x-roundf(p.x/200)*200)<.0001 or absf(p.z-roundf(p.z/200)*200)<.0001:
				var key := Vector3i(roundi(p.x*1000),roundi(p.y*1000),roundi(p.z*1000))
				edge_counts[key]=int(edge_counts.get(key,0))+1
	var unmatched := 0
	for p in edge_counts:
		if absi(p.x)>=1600000 or absi(p.z)>=1600000: continue
		if edge_counts[p]<2: unmatched+=1
	require(unmatched==0,"Unmatched interior terrain edge vertices: %d" % unmatched)
	var space := scene.get_world_3d().direct_space_state
	var bridge_y: float=scene.source.features[0].y
	var deck := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(100,bridge_y+20,100),Vector3(100,bridge_y-20,100)))
	require(not deck.is_empty() and absf(deck.position.y-bridge_y)<.1,"Bridge deck collision missing")
	var underside := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(100,bridge_y-24,100),Vector3(100,bridge_y,100)))
	require(not underside.is_empty() and absf(underside.position.y-(bridge_y-16))<.1,"Bridge underside collision missing")
	var tunnel_y: float=scene.source.features[2].y
	var tunnel := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(35,tunnel_y,-100),Vector3(165,tunnel_y,-100)))
	require(tunnel.is_empty(),"Tunnel passage obstructed")
	print("BASELINE_GEOMETRY ",JSON.stringify({"passed":passed,"unmatched_edges":unmatched,"bridge_collision":not deck.is_empty(),"underside_collision":not underside.is_empty(),"tunnel_clear":tunnel.is_empty()}))

func sample(label: String) -> void:
	scene.set_view(2 if label.begins_with("bridge") else (3 if label=="tunnel" else 1))
	if label=="whole_area": scene.set_view(4)
	if label=="traverse":
		scene.camera.position=Vector3(-1500,scene.source.surface_height(Vector2(-1500,350))+15,350)
		scene.camera.look_at(scene.camera.position+Vector3(100,-5,0))
	for i in 120: await process_frame
	var frames: Array[float]=[]
	var began := Time.get_ticks_usec();var last := began
	while Time.get_ticks_usec()-began<20000000:
		await process_frame
		var now := Time.get_ticks_usec();var elapsed := (now-began)/1000000.0
		frames.append((now-last)/1000.0);last=now
		if label=="traverse":
			var x := -1500+elapsed*150
			scene.camera.position=Vector3(x,scene.source.surface_height(Vector2(x,350))+15,350)
		if label=="rotate": scene.camera.rotation.y=elapsed*.4
		if label=="bridge": scene.camera.position.z=145-elapsed*4.5
	var total := 0.0;var missed := 0
	for value in frames: total+=value;missed+=int(value>16.667)
	frames.sort()
	var report := {"view":label,"frames":frames.size(),"fps":frames.size()*1000.0/total,"median_ms":frames[int(frames.size()*.5)],"p95_ms":frames[int(frames.size()*.95)],"p99_ms":frames[int(frames.size()*.99)],"max_ms":frames[-1],"over_budget":missed,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"resolution":str(root.size)}
	reports.append(report);print("BASELINE_FRAME ",JSON.stringify(report))
	if presentation:
		# The 120 FPS presentation cap must still keep p99 inside the 60 FPS budget.
		require(report.fps>=119.0 and report.p99_ms<=16.667,"Presentation pacing failed in "+label)
	else: require(report.p99_ms<=16.667,"Frame budget exceeded in "+label)
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/terrain-"+("presentation-" if presentation else "")+label+".png")
