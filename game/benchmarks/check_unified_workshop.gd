extends SceneTree
var scene: Node
var last_report := 0
func _initialize() -> void:
	create_timer(600).timeout.connect(func(): push_error("Unified workshop timeout");quit(1))
	run.call_deferred()

func require(value: bool, message: String) -> bool:
	if not value: push_error(message);quit(1)
	return value

func ready_world() -> void:
	while not scene.live_kit() or not scene.far_terrain.finished() or not scene.terrain_lod.finished() or scene.ready_frames<3 or not scene.collision_pending.is_empty():
		if Time.get_ticks_msec()-last_report>15000:
			last_report=Time.get_ticks_msec()
			print("UNIFIED_PROGRESS fine=",scene.chunks.size()," far=",scene.far_terrain.tiles.size()," exterior=",scene.terrain_lod.tiles.size()," queued=",scene.terrain_lod.pending.size()," staged=",scene.terrain_lod.staged.size())
		await process_frame
	for i in 3: await physics_frame

func run() -> void:
	scene=load("res://world/sdf_stress_course.tscn").instantiate();root.add_child(scene)
	scene.set_physics_process(false);scene.set_process_input(false)
	await ready_world()
	print("UNIFIED_WORKSHOP_READY tiles=",scene.terrain_lod.tiles.size())
	scene.panel.hide();scene.hud.hide();scene.marker.hide();scene.brush_cursor.hide()
	var source: RefCounted=scene.terrain_source
	for z in [-780.0,-1024.0,-1500.0]:
		var point := Vector2(-14,z)
		var height: float=source.surface_height(point)
		scene.camera.position=Vector3(point.x,height+35,point.y)
		scene.camera.look_at(Vector3(point.x,source.surface_height(point+Vector2(0,-150)),point.y-150))
		scene.ready_frames=0
		await ready_world()
		if not require(scene.camera.position.distance_to(Vector3(point.x,height+35,point.y))<.01,"Test camera moved during fixed-position probe"): return
		var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,height+20,point.y),Vector3(point.x,height-20,point.y),1))
		if hit.is_empty():
			print("UNIFIED_MISSING camera=",scene.camera.position," key=",scene.key_at(Vector3(point.x,height,point.y))," resident=",scene.chunks.has(scene.key_at(Vector3(point.x,height,point.y)))," pending=",scene.collision_pending.size())
			for offset in [Vector2(.13,.17),Vector2(-.13,-.17)]:
				print("UNIFIED_OFFSET ",scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x+offset.x,height+20,point.y+offset.y),Vector3(point.x+offset.x,height-20,point.y+offset.y),1)))
		if not require(not hit.is_empty(),"Missing exterior collision "+str(z)): return
		if not require(absf(hit.position.y-height)<.3,"Exterior collision disagrees with source "+str(z)): return
		print("UNIFIED_CONTACT z=",z," source=",height," actual=",hit.position.y)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://unified-near-"+str(int(-z))+".png")
	scene.camera.position=Vector3(650,source.surface_height(Vector2(650,-1450))+650,-1450)
	scene.camera.look_at(Vector3(-14,source.surface_height(Vector2(-14,-1450)),-1450))
	scene.ready_frames=0
	await ready_world()
	var page_deadline := Time.get_ticks_msec()+120000
	while Time.get_ticks_msec()<page_deadline and (scene.satellite_stream.pages.size()<9 or scene.satellite_stream.worker or not scene.satellite_stream.uploads.is_empty()): await process_frame
	if not require(scene.satellite_stream.pages.size()<=9 and scene.satellite_stream.pages.size()>0,"Satellite residency"): return
	var levels := {};var steps := {}
	for page in scene.satellite_stream.pages.values(): levels[page.level]=true
	for tile in scene.terrain_lod.tiles.values(): steps[tile.step]=true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://unified-distant.png")
	# At this height a native imagery pixel is subpixel: exercise the coarse tier.
	scene.camera.position.y=12000
	scene.camera.look_at(Vector3(-14,source.surface_height(Vector2(-14,-1450)),-1450))
	var imagery_deadline := Time.get_ticks_msec()+120000
	while Time.get_ticks_msec()<imagery_deadline:
		var coarse: bool=scene.satellite_stream.pages.size()==9
		for page in scene.satellite_stream.pages.values(): coarse=coarse and page.level==2
		if coarse: break
		await process_frame
	for page in scene.satellite_stream.pages.values():
		if not require(page.level==2,"Distant imagery did not select quarter-resolution tier"): return
	print("UNIFIED_WORKSHOP_PASS satellite_pages=",scene.satellite_stream.pages.size()," tiers=",levels," mesh_steps=",steps," cached_tiles=",scene.terrain_lod.cache_hits," built_tiles=",scene.terrain_lod.builds)
	quit()
