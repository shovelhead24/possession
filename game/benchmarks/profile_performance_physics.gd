extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/"
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var watched=[]
var results=[]
func _initialize():
	create_timer(360).timeout.connect(func():push_error("PHYSICS_AUDIT_TIMEOUT");quit(1))
	run.call_deferred()
func lock_input(node: Node):
	node.set_process_input(false);node.set_process_unhandled_input(false);node.set_process_unhandled_key_input(false)
	for child in node.get_children():lock_input(child)
func watch(node: Node):
	for property in node.get_property_list():
		if String(property.name).begins_with("audit_"):watched.append([node,property.name])
	for child in node.get_children():watch(child)
func snapshot() -> Dictionary:
	var values={}
	for entry in watched:
		if is_instance_valid(entry[0]):values[str(entry[0].get_path())+"/"+entry[1]]=entry[0].get(entry[1]).duplicate()
	return values
func stats(a: Array) -> Dictionary:
	a.sort();var total=0.0
	for v in a:total+=v
	return {"mean":total/a.size(),"p95":a[int(a.size()*.95)],"max":a[-1]}
func phase(kind: String):
	var saved=[];var clouds=[];var shadow=arena.daylight.sun.shadow_enabled
	for car in arena.vehicle_kit.vehicles:
		saved.append([car,car.freeze,car.global_transform,car.linear_velocity,car.angular_velocity])
		if kind=="frozen_vehicles":car.freeze=true
	if kind=="foot_inactive":arena.on_foot.active=false
	for node in [arena.sky_comparison.legacy,arena.sky_comparison.clouds,arena.sky_comparison.high_painterly]:
		if is_instance_valid(node):
			clouds.append([node,node.visible])
			if kind=="clouds_hidden":node.hide()
	if kind=="shadows_off":arena.daylight.sun.shadow_enabled=false
	if kind=="half_resolution":root.size=Vector2i(683,384)
	await create_timer(1).timeout
	var before=snapshot();var tick0=Engine.get_physics_frames();var start=Time.get_ticks_usec();var last=start
	var frame=[];var physics=[];var objects=[];var pairs=[];var islands=[];var draws=[]
	while Time.get_ticks_usec()-start<6000000:
		await process_frame
		var now=Time.get_ticks_usec();frame.append((now-last)/1000.0);last=now
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		objects.append(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS));pairs.append(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS));islands.append(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT));draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var duration=(Time.get_ticks_usec()-start)/1000000.0;var ticks=Engine.get_physics_frames()-tick0;var after=snapshot();var counters={}
	for key in after:
		var value={}
		for metric in after[key]:value[metric]=after[key][metric]-before.get(key,{}).get(metric,0)
		if value.calls>0:
			value.ms_per_tick=value.usec/1000.0/maxi(1,ticks);value.ms_per_frame=value.usec/1000.0/frame.size();counters[key]=value
	var row={"case":kind,"seconds":duration,"frames":frame.size(),"physics_ticks":ticks,"frame_ms":stats(frame),"physics_monitor_ms":stats(physics),"active_objects":stats(objects),"collision_pairs":stats(pairs),"islands":stats(islands),"draws":stats(draws),"counters":counters,"camera":str(arena.camera.global_transform),"viewport":str(root.size)}
	results.append(row);print("PHYSICS_CASE ",kind," ",JSON.stringify(row.frame_ms)," active=",row.active_objects.mean," pairs=",row.collision_pairs.mean)
	if kind=="frozen_vehicles":
		for entry in saved:
			assert(entry[0].freeze,"Vehicle unexpectedly unfrozen during sample")
			entry[0].freeze=entry[1];entry[0].global_transform=entry[2];entry[0].linear_velocity=entry[3];entry[0].angular_velocity=entry[4]
	for entry in clouds:entry[0].visible=entry[1]
	arena.daylight.sun.shadow_enabled=shadow;arena.on_foot.active=true;root.size=Vector2i(1366,768)
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
	var near_spawn="--physics-near-spawn" in OS.get_cmdline_user_args()
	if near_spawn:
		var point=Vector2(-25,230);var estimate=Ring.point(point.x,arena.source.surface_height(point),point.y)
		var landing=arena.on_foot.find_ground(estimate)
		assert(not landing.is_empty(),"Near-spawn standing position is obstructed")
		arena.on_foot.activate_at(landing.feet);arena.on_foot.yaw=0;arena.on_foot.pitch=-.15;arena.on_foot.update_camera()
		await create_timer(2).timeout
	watch(arena)
	assert(not watched.is_empty(),"Install temporary counters with work/instrument_physics.py before this benchmark")
	var cases=["baseline","frozen_vehicles","frozen_vehicles","baseline","foot_inactive","baseline"] if near_spawn else ["baseline","frozen_vehicles","frozen_vehicles","baseline","foot_inactive","baseline","clouds_hidden","shadows_off","half_resolution","baseline"]
	for kind in cases:await phase(kind)
	FileAccess.open(OUT+("physics-near-spawn.json" if near_spawn else "physics-audit.json"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("PHYSICS_AUDIT_PASS");quit()
