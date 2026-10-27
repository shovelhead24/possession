extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/"
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var results=[]
var confirm=false
func _initialize():
	create_timer(240).timeout.connect(func():push_error("SHADOW_AUDIT_TIMEOUT");quit(1))
	run.call_deferred()
func lock_input(node: Node):
	node.set_process_input(false);node.set_process_unhandled_input(false);node.set_process_unhandled_key_input(false)
	for child in node.get_children():lock_input(child)
func stats(a: Array) -> Dictionary:
	a.sort();var total=0.0
	for v in a:total+=v
	return {"mean":total/a.size(),"p95":a[int(a.size()*.95)],"max":a[-1]}
func phase(size: int, filter: int, location: String):
	arena.daylight.shadow_filter=filter;arena.daylight.apply()
	RenderingServer.directional_shadow_atlas_set_size(size,false)
	await create_timer(2).timeout
	var start=Time.get_ticks_usec();var last=start;var frames=[]
	while Time.get_ticks_usec()-start<(10000000 if confirm else 6000000):
		await process_frame
		var now=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
	var row={"atlas":size,"filter":filter,"frame_ms":stats(frames),"frames":frames.size(),"camera":str(arena.camera.global_transform)}
	results.append(row);print("SHADOW_CASE ",JSON.stringify(row))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"shadow-"+location+"-"+str(size)+"-"+str(filter)+".png")
func run():
	root.size=Vector2i(1366,768)
	arena=load("res://world/performance_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter:await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path and "sky-test" in arena.destruction.save_path)
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
	var near_spawn="--shadow-near-spawn" in OS.get_cmdline_user_args()
	if near_spawn:
		var point=Vector2(-25,230);var estimate=Ring.point(point.x,arena.source.surface_height(point),point.y)
		var landing=arena.on_foot.find_ground(estimate)
		assert(not landing.is_empty(),"Near-spawn standing position is obstructed")
		arena.on_foot.activate_at(landing.feet);arena.on_foot.yaw=0;arena.on_foot.pitch=-.15;arena.on_foot.update_camera()
		await create_timer(2).timeout
	confirm="--shadow-confirm" in OS.get_cmdline_user_args()
	var location="near" if near_spawn else "open"
	if confirm:
		location+="-confirm"
		await create_timer(10).timeout
	var cases=[[2048,1],[1024,1],[2048,0],[1024,0],[1024,0],[2048,0],[1024,1],[2048,1]]
	if confirm:cases=[[2048,1],[1024,1],[1024,1],[2048,1]]
	for settings in cases:
		await phase(settings[0],settings[1],location)
	arena.daylight.shadow_filter=1;arena.daylight.apply();RenderingServer.directional_shadow_atlas_set_size(2048,false)
	FileAccess.open(OUT+"shadow-audit-"+location+".json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("SHADOW_AUDIT_PASS");quit()
