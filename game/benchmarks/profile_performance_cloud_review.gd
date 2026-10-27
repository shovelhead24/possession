extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/"
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var results=[]
func _initialize():
	create_timer(300).timeout.connect(func():push_error("CLOUD_REVIEW_TIMEOUT");quit(1))
	run.call_deferred()
func lock_input(node: Node):
	node.set_process_input(false);node.set_process_unhandled_input(false);node.set_process_unhandled_key_input(false)
	for child in node.get_children():lock_input(child)
func capture(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func phase(mode: int):
	var review=arena.cloud_review;review.set_mode(mode);review.cloud_time=120;review.speed=1
	await create_timer(2).timeout
	var frames=[];var start=Time.get_ticks_usec();var last=start
	while Time.get_ticks_usec()-start<5000000:
		await process_frame
		var now=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
	frames.sort();var total=0.0
	for v in frames:total+=v
	var row={"mode":mode,"mean_ms":total/frames.size(),"p95_ms":frames[int(frames.size()*.95)],"frames":frames.size(),"chunks":review.cached.chunks.size(),"day_enabled":review.day_cycle.enabled,"hour":review.day_cycle.hour}
	results.append(row);print("CLOUD_REVIEW_CASE ",JSON.stringify(row))
	await capture("cloud-review-mode-"+str(mode)+("-hour-"+str(review.day_cycle.hour) if review.day_cycle.enabled else ""))
func run():
	root.size=Vector2i(1366,768)
	arena=load("res://world/performance_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter:await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path and "sky-test" in arena.destruction.save_path)
	await capture("cloud-review-briefing")
	arena.loading.close();lock_input(arena);arena.controller.set_physics_process(false);Engine.max_fps=0
	arena.on_foot.deactivate();var kit=arena.vehicle_kit;kit.driving=true;kit.test_controls=true;kit.test_throttle=0;kit.test_brake=true
	assert(await kit.place(Vector2(120,145),atan2(-124.0,107.0)))
	for i in 180:await process_frame
	kit.driving=false;arena.diagnostic=true
	var ground=arena.on_foot.find_ground(kit.car.global_position+kit.car.global_basis.x*4)
	assert(not ground.is_empty());arena.on_foot.activate_at(ground.feet);arena.on_foot.test_controls=true;arena.on_foot.set_process(false)
	arena.camera.global_transform=Transform3D(Ring.tangent_basis(kit.car.global_position,atan2(-124.0,107.0)),kit.car.global_position+Ring.up_at(kit.car.global_position)*2.5)
	arena.camera.rotate_object_local(Vector3.RIGHT,-.15)
	if not arena.collision_debug.hud_hidden:arena.collision_debug.toggle_hud()
	arena.camera.rotate_object_local(Vector3.RIGHT,.45)
	var review=arena.cloud_review
	while not review.cached.queue.is_empty():await process_frame
	await create_timer(4).timeout
	for mode in [0,1,2,3,3,2,1,0]:await phase(mode)
	FileAccess.open(OUT+"cloud-review-timings.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	review.set_mode(2);review.playing=false
	var before=review.cached.generated;var meshes={}
	for key in review.cached.chunks:meshes[key]=review.cached.chunks[key].node.multimesh.get_instance_id()
	for tick in [0.0,120.0,1365.2,1365.4,3600.0]:
		review.cloud_time=tick;review.update_time();await process_frame
		await capture("cloud-review-time-"+str(tick))
	assert(review.cached.generated==before,"Cloud animation must not regenerate geometry")
	for key in meshes:assert(review.cached.chunks[key].node.multimesh.get_instance_id()==meshes[key])
	var day=review.day_cycle;var original=day.snapshot_lighting()
	for hour in [6.3,12.0,17.7,0.0]:
		day.set_hour(hour)
		if hour==6.3 or hour==17.7:
			arena.camera.look_at(arena.camera.global_position+arena.daylight.sun.global_basis.z*1000,Ring.up_at(arena.camera.global_position))
		await phase(2)
		await capture("cloud-review-hour-"+str(hour))
	day.reset()
	assert(arena.daylight.sun.rotation.is_equal_approx(original.rotation))
	assert(arena.daylight.sun.light_color.is_equal_approx(original.sun_color))
	day.set_hour(23.99);day.animate=true;day.hours_per_second=2
	await create_timer(.2).timeout
	assert(day.hour<1.0,"Day clock must wrap midnight")
	day.reset();review.set_mode(0)
	assert(not review.experimental_shaders,"Original mode must restore original shaders")
	assert(review.cached.materials[0].shader==preload("res://world/sky_cached_billboard.gdshader"))
	review.open_review();await process_frame
	assert(review.dialog.size.y<root.size.y-30)
	print("REVIEW_WINDOW ",review.dialog.size," viewport ",root.size)
	await capture("cloud-review-controls")
	FileAccess.open(OUT+"cloud-review-timings.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("CLOUD_REVIEW_PASS: mode comparisons, wrap samples, no geometry regeneration, sunrise/sunset, midnight wrap, reset");quit()
