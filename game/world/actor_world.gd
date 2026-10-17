extends Node3D
const Store=preload("res://world/actor_store.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var store=Store.new()
var applied := {}
var live := {}
var snapshots := {}
var routes := {}
var revision := -1
var clock := 0.0
var pending := 0
func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;process_physics_priority=-40
	store.base=arena.source.identity
	store.path=OS.get_user_data_dir().get_base_dir().path_join("Rebuild Demo/actors.json")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--actors-file="): store.path=arg.trim_prefix("--actors-file=")
	if not FileAccess.file_exists(store.path): seed_defaults()
	else: store.load_saved(true)
	arena.aliens.rex_enabled=false;arena.aliens.authoring=self;arena.aliens.reset()
func seed_defaults() -> void:
	var c=Ring.coordinates(arena.aliens.spawn)
	for offset in [Vector2(45,60),Vector2(100,90),Vector2(-120,180),Vector2(220,260)]:
		var p=Ring.point(c.x+offset.x,c.y,c.z+offset.y);var record=store.make("squad",p)
		for i in 4:
			var v=p+Ring.tangent_basis(p,0)*Vector3(cos(i*PI/2),0,sin(i*PI/2))*9
			record.route.append(Store.coordinate(v))
		record.wait=10.0;store.records.append(record)
	if not OS.get_cmdline_user_args().has("--no-rebuild-rex"):
		var record=store.make("trex",Ring.point(c.x+150,c.y,c.z+110))
		for offset in [Vector2(150,110),Vector2(195,130),Vector2(185,205),Vector2(125,180)]: record.route.append([c.x+offset.x,c.y,c.z+offset.y])
		store.records.append(record)
	store.current=store.signature();store.revision+=1;store.notice="Current encounters imported. Ctrl+S saves the editable layout."
func reset_encounters() -> void:
	for id in live.keys(): retire(id,false)
	snapshots.clear();applied.clear();revision=-1;synchronize()
func retire(id: int, remember := true) -> void:
	if not live.has(id): return
	var node=live[id]
	if is_instance_valid(node):
		if node.has_method("release_hold"): node.release_hold()
		if remember:
			snapshots[id]={"position":node.global_position,"basis":node.global_basis,"health":node.get("health")}
			var route=node.authored_route if node.has_method("release_hold") else routes.get(id)
			if route: snapshots[id].route=route.snapshot()
		if node is RigidBody3D:
			var kit=arena.vehicle_kit
			if kit.car==node: kit.select_vehicle(kit.original_car)
			kit.vehicles.erase(node)
		node.queue_free()
	elif remember: snapshots[id]={"dead":true}
	live.erase(id);routes.erase(id)
func remove_garrison(id: int) -> void:
	var manager=arena.aliens
	for entry in manager.garrisons.duplicate():
		if entry.get("actor_id",-1)!=id: continue
		if is_instance_valid(entry.squad):
			for unit in entry.squad.members: manager.enemies.erase(unit);unit.queue_free()
			manager.squads.erase(entry.squad);entry.squad.queue_free()
		manager.garrisons.erase(entry)
func synchronize() -> void:
	var wanted={}
	for record in store.records: wanted[record.id]=record
	for id in applied.keys():
		if not wanted.has(id) or applied[id]!=wanted[id]:
			retire(id,false);remove_garrison(id);snapshots.erase(id);applied.erase(id)
	for record in store.records:
		if applied.has(record.id): continue
		applied[record.id]=record.duplicate(true)
		if not record.enabled: continue
		if record.kind in ["squad","grunt","captain"]:
			arena.aliens.garrisons.append({"actor_id":record.id,"record":record.duplicate(true),"home":Store.point(record.p),"count":5 if record.kind=="squad" else 1,"elite":record.kind!="grunt","yaw":record.yaw,"squad":null,"snapshot":{},"quiet":300.0,"last_known":Vector3.ZERO,"retired_at":0.0})
	revision=store.revision;arena.aliens.navigation.invalidate()
func spawn_actor(record: Dictionary) -> bool:
	var state=snapshots.get(record.id,{})
	if state.get("dead",false): return false
	var point: Vector3=state.get("position",Store.point(record.p))
	var hit=arena.aliens.ground(point)
	if hit.is_empty(): return false
	var node: Node3D
	if record.kind=="crate":
		node=preload("res://world/heavy_crate.gd").new();node.arena=arena;node.set_meta("actor_id",record.id)
		node.position=state.get("position",hit.position+Ring.up_at(hit.position)*.96);add_child(node)
	elif record.kind=="trex":
		node=preload("res://world/aliens/trex.gd").new();node.arena=arena;node.manager=arena.aliens
		node.patrol=[hit.position];node.behavior_mode=record.mode;node.walk_speed=record.speed
		node.authored_route=preload("res://world/actor_route.gd").new();node.authored_route.configure(record);node.authored_route.restore(state.get("route",{}))
		node.set_meta("actor_id",record.id);arena.aliens.add_child(node)
		if state.get("health")!=null: node.health=state.health;node.update_health_label()
	else:
		var pose=Transform3D(Ring.tangent_basis(hit.position,deg_to_rad(record.yaw)),hit.position+Ring.up_at(hit.position)*.3)
		node=preload("res://world/rebuild_tank_factory.gd").create(arena.vehicle_kit,pose) if record.kind=="tank" else arena.vehicle_kit.create_authored_vehicle(pose)
		if record.kind!="tank": node.actor_impact.connect(func(body,where,relative,normal):
			if is_instance_valid(body) and body.has_method("vehicle_impact"): body.vehicle_impact(node,where,relative,normal))
		var route=preload("res://world/actor_route.gd").new();route.configure(record);route.restore(state.get("route",{}));routes[record.id]=route
		node.set_meta("actor_id",record.id)
	node.global_basis=state.get("basis",Ring.tangent_basis(hit.position,deg_to_rad(record.yaw)))
	node.reset_physics_interpolation();live[record.id]=node;return true
func _physics_process(delta: float) -> void:
	if not arena or not arena.ready_to_play: return
	clock-=delta
	if clock<=0:
		clock=.5
		if not arena.editor.opened:
			if revision!=store.revision: synchronize()
			stream_actors()
	for id in live:
		var car=live[id]
		if not is_instance_valid(car) or not car.has_method("set_controls") or car.has_meta("trex_held"): continue
		if car==arena.vehicle_kit.car and arena.vehicle_kit.driving: continue
		var ready=not arena.aliens.paused() and arena.aliens.resident(car.global_position)
		car.gravity_up=Ring.up_at(car.global_position);car.set_stream_ready(ready)
		car.controlled=false;car.set_controls(0,0,true);car.set_meta("patrol_status","PARKED")
		var record: Dictionary=applied[id]
		if not ready: car.set_meta("patrol_status","SUSPENDED");continue
		if record.mode==0: continue
		var route=routes[id];var destination=route.step(car.global_position,delta,5.0)
		if route.holding(): car.set_meta("patrol_status","WAYPOINT WAIT");continue
		var offset=(destination-car.global_position).slide(car.gravity_up)
		var heading=(-car.global_basis.z).signed_angle_to(offset.normalized(),car.gravity_up)
		var speed=car.linear_velocity.slide(car.gravity_up).length()
		var limit=minf(record.speed,maxf(2.0,record.speed*(1.0-minf(absf(heading)/PI,.8))))
		# Brake before the terrain collision edge; never drive a patrol into unloaded ground.
		var ahead=car.global_position-car.global_basis.z*maxf(12,speed*speed/10+6)
		var supported=arena.aliens.resident(ahead)
		car.set_meta("patrol_status","DRIVING" if supported else "TERRAIN AHEAD UNLOADED")
		car.controlled=true;car.set_controls(clampf((limit-speed)*.3,0,1) if supported else 0,clampf(heading*1.8,-1,1),not supported or speed>limit+1)
func stream_actors() -> void:
	var camera=arena.camera.global_position;var counts={"trex":0,"warthog":0,"tank":0,"crate":0}
	for id in live.keys():
		var node=live[id]
		if not is_instance_valid(node): retire(id);continue
		var held=node.has_meta("trex_held") or (node.has_method("release_hold") and (node.bite_time>0 or not node.hold_state.is_empty()))
		var occupied=node==arena.vehicle_kit.car and arena.vehicle_kit.driving
		if node.global_position.distance_to(camera)>400 and not held and not occupied: retire(id);continue
		counts[applied[id].kind]+=1
	var ordered=store.records.duplicate();ordered.sort_custom(func(a,b): return Store.point(a.p).distance_squared_to(camera)<Store.point(b.p).distance_squared_to(camera))
	pending=0
	for record in ordered:
		if record.kind not in counts or not record.enabled or live.has(record.id) or snapshots.get(record.id,{}).get("dead",false): continue
		var p: Vector3=snapshots.get(record.id,{}).get("position",Store.point(record.p))
		if p.distance_to(camera)>280: continue
		if counts[record.kind]>={"trex":2,"warthog":4,"tank":2,"crate":8}[record.kind]: pending+=1;continue
		# At most one heavyweight rig is instantiated in a streaming tick.
		if spawn_actor(record): break
	arena.aliens.trex=null
	for id in live:
		if is_instance_valid(live[id]) and applied[id].kind=="trex": arena.aliens.trex=live[id];break
func editable(id: int) -> bool:
	return not live.has(id) or not is_instance_valid(live[id]) or live[id]!=arena.vehicle_kit.car or not (arena.vehicle_kit.driving or (arena.editor.opened and arena.editor.was_driving))
func status() -> String:
	return "Actors: %d authored / %d Rex / vehicles / crates active%s" % [store.records.size(),live.size()," / nearby actors queued by budget" if pending>0 else ""]

func telemetry() -> Dictionary:
	var states=[]
	for id in live:
		var node=live[id]
		if not is_instance_valid(node): continue
		var state={"id":id,"kind":applied[id].kind,"position":Store.coordinate(node.global_position)}
		if node.has_method("telemetry"): state.details=node.telemetry()
		elif routes.has(id): state.route=routes[id].snapshot();state.speed=node.linear_velocity.length()
		states.append(state)
	return {"authored":store.records.size(),"pending":pending,"active":states}
