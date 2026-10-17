extends SceneTree
const Store=preload("res://world/actor_store.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
func _initialize(): run.call_deferred()
func run():
	var store=Store.new();store.base="actor-test";store.path="C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/work/actor-test-saves/data-test.json"
	for kind in Store.KINDS:
		var record=store.make(kind,Ring.point(100,5,200));assert(Store.valid_record(record))
		var before=store.snapshot();store.records.append(record);store.commit(before)
	assert(store.unsaved());store.undo();assert(store.records.size()==Store.KINDS.size()-1);store.redo();assert(store.records.size()==Store.KINDS.size())
	assert(store.save());assert(not store.unsaved());var original=store.snapshot()
	var loaded=Store.new();loaded.base=store.base;loaded.path=store.path;assert(loaded.load_saved());assert(loaded.records==original)
	for key in ["id","mode","yaw","speed","wait","p","route","enabled","kind"]:
		var bad=original[0].duplicate(true);bad.erase(key);assert(not Store.valid_record(bad),key)
	for value in [NAN,INF,-INF,"oops",null]:
		var bad=original[0].duplicate(true);bad.speed=value;assert(not Store.valid_record(bad))
	var doc={"schema":1,"base":store.base,"frame":"terrain-drive-ring-metres","actors":[original[0],original[0]]}
	var file=FileAccess.open(store.path,FileAccess.WRITE);file.store_string(JSON.stringify(doc));file.close()
	assert(not loaded.load_saved());assert(loaded.records==original,"Bad load must not alter layout")
	var record=original[0].duplicate(true);record.route=[[100,5,200],[120,5,200]];record.wait=1.0;record.loop=false
	var route=preload("res://world/actor_route.gd").new();route.configure(record)
	route.step(Store.point(record.route[0]),.5,1);assert(route.holding() and route.index==0)
	route.step(Store.point(record.route[0]),.6,1);assert(not route.holding() and route.index==1)
	route.step(Store.point(record.route[1]),1.1,1);assert(route.finished)
	record.loop=true;record.wait=0;route.configure(record);route.step(Store.point(record.route[0]),.1,1);route.step(Store.point(record.route[1]),.1,1);assert(route.index==0 and not route.finished)
	print("ACTOR_DATA_PASS: schema validation, atomic load rejection, save/reload, undo/redo, waits and route looping")
	quit()
