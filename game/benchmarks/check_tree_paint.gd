extends SceneTree
const Painter = preload("res://world/tree_paint.gd")
const Assets = preload("res://world/tree_patch_assets.gd")
class TestSource extends RefCounted:
	var base_hash := "isolated-tree-paint-fixture"
	func surface_height(_point: Vector2) -> float: return 0.0
class TestDestruction extends RefCounted:
	var working := false
	func busy() -> bool: return working
class TestArena extends Node3D:
	var source := TestSource.new()
	var destruction := TestDestruction.new()
	var trees: Node3D
	var painted_trees: Node3D
	var camera: Camera3D
	var ready_to_play := true
	var vehicle_kit := {"car":Node3D.new()}
	var tile_entries := {}
var arena: TestArena
var output := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-output="): output=arg.trim_prefix("--tree-output=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	create_timer(60).timeout.connect(func(): push_error("Paint test timeout");quit(1))
	run.call_deferred()

func run() -> void:
	arena=TestArena.new();root.add_child(arena);arena.add_child(arena.vehicle_kit.car)
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.position=Vector3(30,30,60);arena.camera.look_at(Vector3(15,0,5))
	var terrain := StaticBody3D.new();arena.add_child(terrain)
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(800,2,800)
	shape.shape=box;shape.position.y=-1;terrain.add_child(shape)
	for z in range(-2,2):
		for x in range(-2,2): arena.tile_entries[Vector2i(x,z)]={"body":terrain}
	arena.trees=load("res://world/tree_patch.gd").new();arena.add_child(arena.trees)
	arena.trees.set_physics_process(false);arena.trees.arena=arena;arena.trees.variants=Assets.new().load_meshes();arena.trees.names=arena.trees.variants.keys();arena.trees.count_limit=0
	var painter := Painter.new();arena.painted_trees=painter;arena.add_child(painter);painter.setup(arena)
	# Always isolate writes, even if command-line override was omitted.
	painter.store.path=output.path_join("paint-fixture.json")
	painter.store.records=[];painter.sync_records()
	await physics_frame;await physics_frame
	var options := {"radius":12.0,"density":4.0,"height":9.0,"species":0,"erase":false}
	assert(painter.begin_paint(Vector3.ZERO,options))
	painter.enqueue(Vector3(40,0,0));painter.release()
	while painter.busy(): await physics_frame
	var count: int=painter.store.records.size();assert(count>20)
	assert(painter.store.undo_stack.size()==1,"Drag must be one undo step")
	assert(painter.store.unsaved())
	for a in range(count):
		for b in range(a): assert(painter.candidates[a].point.distance_to(painter.candidates[b].point)>=2.999)
	painter.undo_paint();assert(painter.store.records.is_empty())
	painter.redo_paint();assert(painter.store.records.size()==count)
	assert(painter.store.save());assert(not painter.store.unsaved())
	var saved_signature: String=painter.store.signature()
	assert(painter.begin_paint(Vector3.ZERO,options));painter.enqueue(Vector3(40,0,0));painter.release()
	while painter.busy(): await physics_frame
	assert(painter.store.records.size()==count,"Painting twice must not stack duplicates")
	options.erase=true
	assert(painter.begin_paint(Vector3.ZERO,options));painter.release()
	while painter.busy(): await physics_frame
	var erased: int=count-painter.store.records.size();assert(erased>0)
	painter.undo_paint();assert(painter.store.signature()==saved_signature)
	assert(not painter.store.unsaved(),"Undo to saved state should be clean")
	painter.redo_paint();assert(painter.store.records.size()==count-erased)
	painter.load_paint()
	if painter.store.signature()!=saved_signature:
		print("RELOAD_DIAGNOSTIC ",painter.store.notice," expected=",saved_signature.substr(0,300)," actual=",painter.store.signature().substr(0,300))
	assert(painter.store.signature()==saved_signature)
	var fresh := Painter.Store.new();fresh.base=arena.source.base_hash;fresh.path=painter.store.path
	assert(fresh.load_saved(painter.names,true));assert(fresh.signature()==saved_signature)
	# Invalid load is transactional: existing placement must survive.
	fresh.path=output.path_join("bad-tree-fixture.json")
	var file := FileAccess.open(fresh.path,FileAccess.WRITE);file.store_string('{"schema":1,"base":"wrong","trees":[]}');file.close()
	assert(not fresh.load_saved(painter.names));assert(fresh.signature()==saved_signature)
	arena.destruction.working=true
	assert(not painter.begin_paint(Vector3.ZERO,options));arena.destruction.working=false
	await create_timer(.5).timeout
	assert(painter.count_limit==count and painter.by_id.size()==count)
	assert(painter.candidates.any(func(item): return is_instance_valid(item.body)),"Near trunk collision missing")
	painter.set_enabled(false);await process_frame
	assert(painter.candidates.all(func(item): return not is_instance_valid(item.body)))
	painter.set_enabled(true)
	var result := {"passed":true,"painted":count,"erased":erased,"one_drag_one_undo":true,"spacing":true,"duplicate_repaint":true,"save_reload":true,"fresh_load":true,"invalid_load_retains_state":true,"collision_toggle":true}
	file=FileAccess.open(output.path_join("paint-results.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("TREE_PAINT_PASS ",JSON.stringify(result));quit()
