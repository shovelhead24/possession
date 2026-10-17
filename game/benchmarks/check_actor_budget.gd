extends SceneTree
const Store=preload("res://world/actor_store.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
class Kit extends RefCounted:
	var car: Node3D
	var original_car: Node3D
	var vehicles=[]
	var driving=false
class Manager extends RefCounted:
	var trex: Node3D
class Arena extends Node3D:
	var camera: Camera3D
	var vehicle_kit=Kit.new()
	var aliens=Manager.new()
class BudgetWorld extends "res://world/actor_world.gd":
	func spawn_actor(record: Dictionary) -> bool:
		var node=Node3D.new();add_child(node);node.position=Store.point(record.p);live[record.id]=node;return true
func _initialize(): run.call_deferred()
func run():
	var arena=Arena.new();root.add_child(arena);arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.position=Ring.point(100,0,200)
	var world=BudgetWorld.new();arena.add_child(world);world.set_physics_process(false);world.arena=arena
	for kind in ["trex","warthog"]:
		for i in 10:
			var record=world.store.make(kind,arena.camera.position+Vector3(i,0,0));world.store.records.append(record);world.applied[record.id]=record.duplicate(true)
	for i in 25: world.stream_actors()
	var counts={"trex":0,"warthog":0}
	for id in world.live: counts[world.applied[id].kind]+=1
	assert(counts.trex==2 and counts.warthog==4 and world.pending==14,"Heavyweight activation budgets")
	arena.camera.position+=Vector3(600,0,0);world.stream_actors();await process_frame
	assert(world.live.is_empty(),"Distant unoccupied actors retire")
	arena.free();print("ACTOR_BUDGET_PASS: two Rex / four placed vehicles active; extra nearby actors queued; distant actors retire")
	quit()
