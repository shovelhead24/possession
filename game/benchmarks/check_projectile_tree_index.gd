extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
const Cast=preload("res://world/weapon_obstruction.gd")
class Arena extends Node3D:
	var forge: Node
	var painted_trees: Node
class Brute extends Node:
	var enabled := true
	var candidates: Array=[]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var arena := Arena.new();root.add_child(arena)
	var indexed=preload("res://world/tree_paint.gd").new();arena.add_child(indexed);indexed.set_physics_process(false)
	var brute := Brute.new();arena.add_child(brute)
	var rng := RandomNumberGenerator.new();rng.seed=4321
	for i in 2400:
		var arc := rng.randf_range(-600,600)
		if i>=2300: arc+=Ring.Frame.CIRCUMFERENCE*.5
		arc=wrapf(arc,-Ring.Frame.CIRCUMFERENCE*.5,Ring.Frame.CIRCUMFERENCE*.5)
		var z := rng.randf_range(-600,600);var h := rng.randf_range(8,35)
		var point := Ring.point(arc,0,z)
		var record := {"id":i,"x":arc,"z":z,"height":h}
		indexed.index_record(record,i)
		var item := {"id":i,"valid":true,"height":h,"transform":Transform3D(Ring.tangent_basis(point,0).scaled(Vector3.ONE*h),point)}
		indexed.by_id[i]=item;brute.candidates.append(item)
	indexed.candidates.assign(brute.candidates)
	var queries := []
	for i in 120:
		var item: Dictionary=brute.candidates[i*20]
		var transform: Transform3D=item.transform
		var centre: Vector3=transform.origin+transform.basis.y.normalized()*item.height*.2
		var right: Vector3=transform.basis.x.normalized()
		queries.append([centre-right*2,centre+right*2])
	for pair in queries:
		arena.painted_trees=brute;var expected := Cast.cast(arena,pair[0],pair[1])
		arena.painted_trees=indexed;var actual := Cast.cast(arena,pair[0],pair[1])
		assert(not expected.is_empty() and not actual.is_empty())
		assert(expected.position.distance_to(actual.position)<.01)
	for tree in [brute,indexed]:
		arena.painted_trees=tree;var began := Time.get_ticks_usec()
		for pair in queries: Cast.cast(arena,pair[0],pair[1])
		print("TREE_CAST_US ","brute" if tree==brute else "indexed"," ",(Time.get_ticks_usec()-began)/float(queries.size()))
	print("TREE_INDEX_PASS: 120 matched trunk hits, 2400 trees including ring seam")
	arena.free();quit()

