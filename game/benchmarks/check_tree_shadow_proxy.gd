extends SceneTree
const Proxy = preload("res://world/tree_shadow_proxy.gd")
class Patch extends Node3D:
	var shadow_revision := 0
	var enabled := true
	var candidates: Array=[]
	var count_limit := 0
class Arena extends Node3D:
	var trees: Patch
	var painted_trees: Patch
	var camera: Camera3D
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var arena := Arena.new();root.add_child(arena)
	arena.trees=Patch.new();arena.add_child(arena.trees)
	arena.painted_trees=Patch.new();arena.add_child(arena.painted_trees)
	arena.camera=Camera3D.new();arena.add_child(arena.camera)
	var proxy := Proxy.new();arena.add_child(proxy);proxy.meshes.append(Proxy.make_canopy(.3))
	assert(proxy.meshes[0].surface_get_array_len(0)==48*3)
	var item := {"valid":true,"point":Vector2(10,10),"variant":0,"transform":Transform3D(Basis.IDENTITY,Vector3(10,0,10))}
	arena.painted_trees.candidates.append(item);arena.painted_trees.count_limit=1
	proxy.refresh(arena,true);assert(proxy.tree_count==1 and proxy.batches.size()==1)
	var batch: MultiMeshInstance3D=proxy.batches.values()[0]
	assert(batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	var rid := batch.multimesh.get_rid();proxy.refresh(arena,true)
	assert(proxy.update_ms==0.0 and batch.multimesh.get_rid()==rid)
	# Published terrain changes update the ground transform without changing tree identity.
	item.transform.origin.y=7;arena.painted_trees.shadow_revision+=1;proxy.refresh(arena,true)
	assert(proxy.uploaded.values()[0][0].origin.y==7)
	item.valid=false;arena.painted_trees.shadow_revision+=1;proxy.refresh(arena,true)
	assert(proxy.tree_count==0 and proxy.batches.is_empty())
	item.valid=true;arena.painted_trees.shadow_revision+=1;proxy.refresh(arena,true)
	assert(proxy.tree_count==1)
	arena.painted_trees.enabled=false;proxy.refresh(arena,true)
	assert(proxy.tree_count==0)
	arena.painted_trees.enabled=true;proxy.refresh(arena,true);assert(proxy.tree_count==1)
	arena.painted_trees.candidates.clear();arena.painted_trees.count_limit=0;arena.painted_trees.shadow_revision+=1;proxy.refresh(arena,true)
	assert(proxy.tree_count==0 and proxy.batches.is_empty())
	proxy.refresh(arena,false);assert(not proxy.visible)
	print("SHADOW_PROXY_PASS: idle cache, terrain re-grounding, invalidation, visibility and erase cleanup")
	arena.free();quit()
