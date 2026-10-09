extends SceneTree
const Painter = preload("res://world/tree_paint.gd")
const Assets = preload("res://world/tree_patch_assets.gd")
class Source extends RefCounted:
	var base_hash := "isolated-streaming-fixture"
	func surface_height(_p: Vector2) -> float: return 0.0
class Destruction extends RefCounted:
	func busy() -> bool: return false
class Foot extends Node3D:
	var active := false
class Arena extends Node3D:
	var source := Source.new()
	var destruction := Destruction.new()
	var trees: Node3D
	var painted_trees: Node3D
	var camera: Camera3D
	var on_foot: Foot
	var vehicle_kit := {"car":Node3D.new()}
	var tile_entries := {}
	var ready_to_play := true
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-output="): output=arg.trim_prefix("--tree-output=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	create_timer(90).timeout.connect(func(): push_error("Streaming test timeout");quit(1))
	run.call_deferred()
func wait_ticks(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	var arena := Arena.new();root.add_child(arena)
	arena.add_child(arena.vehicle_kit.car);arena.camera=Camera3D.new();arena.add_child(arena.camera)
	arena.camera.position=Vector3(30,30,40);arena.on_foot=Foot.new();arena.add_child(arena.on_foot)
	var floor := StaticBody3D.new();arena.add_child(floor)
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(16000,2,4000);shape.shape=box;shape.position.y=-1;floor.add_child(shape)
	for x in [-1,0,1,24,25,26]:
		for z in [-1,0,1]: arena.tile_entries[Vector2i(x,z)]={"body":floor}
	arena.trees=load("res://world/tree_patch.gd").new();arena.add_child(arena.trees)
	arena.trees.set_physics_process(false);arena.trees.arena=arena;arena.trees.variants=Assets.new().load_meshes();arena.trees.names=arena.trees.variants.keys()
	var painter := Painter.new();arena.painted_trees=painter;arena.add_child(painter)
	painter.arena=arena;painter.names=arena.trees.names;painter.variants=arena.trees.variants;painter.checks_per_tick=32;painter.retire_empty_batches=true
	painter.store.base=arena.source.base_hash;painter.store.path=output.path_join("stream-trees.json")
	for i in 50640:
		var x: float=4+(i%20)*4;var z: float=4+(i/20)*4
		if i>=640: x=10000+(i-640)*10;z=1000
		elif i>=320: x=5004+((i-320)%20)*4;z=4+((i-320)/20)*4
		painter.store.records.append({"id":i+1,"x":x,"z":z,"height":9.0,"yaw":0.0,"species":painter.names[0]})
	painter.store.next_id=50641
	painter.sync_records()
	assert(painter.count_limit<=Painter.ACTIVATE_PER_TICK,"Activation must be paced")
	await wait_ticks(30)
	assert(painter.count_limit==320 and painter.by_id.size()==320)
	assert(painter.store.records.size()==50640)
	assert(painter.last_stream_checks<400,"Idle work must query nearby cells, not all saved records")
	assert(painter.candidates.any(func(item): return is_instance_valid(item.body)))
	var old_body: Node=painter.candidates.filter(func(item): return is_instance_valid(item.body))[0].body
	arena.camera.position=Vector3(5030,30,40);arena.vehicle_kit.car.position=Vector3(5030,0,40)
	painter.refresh_stream();painter.activate_pending()
	assert(painter.count_limit<=Painter.ACTIVATE_PER_TICK,"Teleport must retire old cells and pace new cells")
	await wait_ticks(30)
	assert(not is_instance_valid(old_body),"Retired cell collider leaked")
	assert(painter.count_limit==320 and painter.by_id.has(321) and not painter.by_id.has(1))
	assert(painter.candidates.all(func(item): return item.point.x>5000))
	# Undo/save remain independent of which trees are active.
	assert(painter.store.save())
	var fresh := Painter.Store.new();fresh.base=painter.store.base;fresh.path=painter.store.path
	assert(fresh.load_saved(painter.names,true) and fresh.records.size()==50640)
	assert(fresh.signature()==painter.store.signature())
	var options := {"radius":8.0,"density":4.0,"height":9.0,"species":0,"erase":false}
	assert(painter.begin_paint(Vector3(5030,0,100),options));painter.release()
	while painter.busy(): await physics_frame
	var added: int=painter.store.records.size()-50640;assert(added>0,"Painting above 4096 must work")
	painter.undo_paint();assert(painter.store.records.size()==50640)
	painter.redo_paint();assert(painter.store.records.size()==50640+added)
	# Camera elsewhere: foot and parked vehicle retain independent collision support.
	arena.camera.position=Vector3(12000,30,40);arena.vehicle_kit.car.position=Vector3(0,0,0)
	arena.on_foot.active=true;arena.on_foot.position=Vector3(5030,0,40)
	painter.refresh_stream();await wait_ticks(40)
	assert(painter.by_id.has(1) and painter.by_id.has(321))
	assert(painter.by_id[321].valid and is_instance_valid(painter.by_id[321].body),"Walking away from car must retain trunk collisions")
	painter.set_enabled(false);await process_frame
	assert(painter.candidates.is_empty() and painter.batches.is_empty())
	painter.set_enabled(true);await wait_ticks(30)
	assert(painter.by_id.has(321))
	# Return to origin; retain across the 650 m boundary, unload beyond margin.
	arena.on_foot.active=false;arena.camera.position=Vector3(720,30,40);arena.vehicle_kit.car.position=Vector3(720,0,40)
	painter.refresh_stream();await wait_ticks(20)
	assert(painter.by_id.has(1))
	arena.camera.position.x=800;arena.vehicle_kit.car.position.x=800;painter.refresh_stream()
	assert(painter.by_id.has(1),"Cell hysteresis missing")
	arena.camera.position.x=1000;arena.vehicle_kit.car.position.x=1000;painter.refresh_stream();await process_frame
	assert(not painter.by_id.has(1))
	assert(painter.store.records.size()==50640+added,"Streaming must never delete saved placements")
	# Both sides of the circular coordinate seam are neighbours.
	var half: float=Painter.Ring.Frame.CIRCUMFERENCE*.5
	for arc in [half-5,-half+5]:
		var record := {"id":painter.store.next_id,"x":arc,"z":0.0,"height":9.0,"yaw":0.0,"species":painter.names[0]}
		painter.index_record(record,painter.store.records.size());painter.store.records.append(record);painter.store.next_id+=1
	arena.camera.position=Painter.Ring.point(half-2,2,0);arena.vehicle_kit.car.position=arena.camera.position
	painter.refresh_stream();painter.activate_pending()
	assert(painter.by_id.has(painter.store.next_id-1) and painter.by_id.has(painter.store.next_id-2),"Ring seam must not split neighbouring cells")
	print("TREE_STREAMING_PASS: 50,640 placements, bounded cell queries, paced activation, teleport eviction, walking/car collision, >4096 save/load/paint, undo/redo, toggle and hysteresis")
	quit()
