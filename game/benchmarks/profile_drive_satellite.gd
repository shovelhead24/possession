extends SceneTree
var arena: Node3D
var output := ""
var reports: Array=[]
var passed := true
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	create_timer(240).timeout.connect(func(): quit(3))
	run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,800)
	arena=load("res://world/terrain_drive.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	arena.loading.close()
	var kit: Node=arena.vehicle_kit
	kit.test_controls=true;kit.test_brake=true;kit.driving=false
	while arena.backdrop.previews_loaded<arena.backdrop.preview_total: await process_frame
	await create_timer(2).timeout
	passed=kit.saved_values.size()==17 and Engine.max_fps==120 and physics_interpolation
	if OS.get_cmdline_user_args().has("--satellite-smoke"):
		passed=passed and arena.satellite_texture!=null and arena.satellite_texture.get_width()==8192
		kit.driving=true
		await create_timer(2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/satellite-driving-view.png")
		kit.driving=false
		arena.camera.position=Vector3(600,650,900);arena.camera.look_at(Vector3(100,0,100))
		await create_timer(2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/satellite-overview.png")
		print("SATELLITE_SMOKE ",passed)
		quit(0 if passed else 2);return
	for key in arena.tile_entries:
		var pixel: Vector2i=key-arena.backdrop.ownership_origin
		passed=passed and pixel.x>=0 and pixel.y>=0 and pixel.x<512 and pixel.y<512
	for corner in [arena.streamer.world_bounds.position,arena.streamer.world_bounds.end]:
		var pixel: Vector2i=Vector2i(floori(corner.x/200),floori(corner.y/200))-arena.backdrop.ownership_origin
		passed=passed and pixel.x>=0 and pixel.y>=0 and pixel.x<512 and pixel.y<512
	var satellite_material: Material=arena.material
	var plain_material := StandardMaterial3D.new();plain_material.albedo_color=Color(.38,.46,.25);plain_material.roughness=1.0
	passed=passed and arena.satellite_texture!=null and arena.satellite_texture.get_width()==8192
	for enabled in [false,true]:
		arena.material=satellite_material if enabled else plain_material
		for entry in arena.tile_entries.values(): entry.visual.material_override=arena.material
		for yaw in [0,90,180,270]:
			arena.camera.position=Vector3(220,arena.source.surface_height(Vector2(220,240))+25,240)
			arena.camera.rotation_degrees=Vector3(-5,yaw,0)
			await create_timer(.5).timeout
			await sample(("satellite" if enabled else "baseline")+str(yaw),5)
			if enabled:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output+"/satellite-"+str(yaw)+".png")
	arena.camera.rotation_degrees=Vector3(35,90,0)
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/satellite-ring.png")
	kit.driving=true
	if not await kit.place(Vector2(1300,350),-PI/2): passed=false
	await create_timer(2).timeout
	kit.test_throttle=1;kit.test_brake=false
	await sample("satellite_drive",35)
	kit.test_throttle=0;kit.test_brake=true
	passed=passed and kit.saved_values.size()==17 and arena.backdrop.ownership_keys.size()==arena.tile_entries.size()
	var file := FileAccess.open(output+"/satellite-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"configuration":kit.saved_values,"reports":reports},"\t"))
	print("SATELLITE_RESULT ",passed)
	quit(0 if passed else 2)
func sample(label: String, seconds: float) -> void:
	var frames: Array[float]=[]
	var long_frames: Array=[]
	var start_hits: int=arena.streamer.hits
	var start_builds: int=arena.streamer.builds
	var start := Time.get_ticks_usec();var previous := start
	var kit: Node=arena.vehicle_kit
	var brakes: int=kit.brake_ticks;var freezes: int=kit.freeze_ticks
	while Time.get_ticks_usec()-start<seconds*1000000:
		await process_frame
		var now := Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
		if frames[-1]>16.667: long_frames.append({"ms":frames[-1],"phase":arena.streamer.last_phase,"phase_ms":arena.streamer.last_phase_ms,"age_ms":(now-arena.streamer.last_phase_at)/1000.0})
		if label=="satellite_drive":
			var forward: Vector3=(-kit.car.basis.z).slide(Vector3.UP).normalized()
			var desired := Vector3(80,0,350-kit.car.position.z).normalized()
			kit.test_steer=clampf(forward.signed_angle_to(desired,Vector3.UP)*2,-1,1)
	var sum := 0.0;var misses := 0
	for value in frames: sum+=value;misses+=int(value>16.667)
	frames.sort()
	var report := {"label":label,"frames":frames.size(),"fps":frames.size()*1000/sum,"p99_ms":frames[int(frames.size()*.99)],"max_ms":frames[-1],"over_budget":misses,"brake_ticks":kit.brake_ticks-brakes,"freeze_ticks":kit.freeze_ticks-freezes,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	report.long_frames=long_frames;report.cache_hits=arena.streamer.hits-start_hits;report.builds=arena.streamer.builds-start_builds
	reports.append(report);print("SATELLITE_FRAME ",JSON.stringify(report))
