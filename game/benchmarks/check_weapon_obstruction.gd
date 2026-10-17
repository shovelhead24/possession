extends SceneTree
const Obstruction=preload("res://world/weapon_obstruction.gd")
const Forge=preload("res://world/forge_world.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
class Trees extends Node:
	var enabled := true
	var candidates := []
class Arena extends Node3D:
	var forge: Node3D
	var painted_trees: Node
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var arena := Arena.new();root.add_child(arena)
	arena.forge=Forge.new();arena.add_child(arena.forge);arena.forge.set_physics_process(false)
	arena.painted_trees=Trees.new();arena.add_child(arena.painted_trees)
	var p := Ring.point(100000,10,0);var b := Ring.tangent_basis(p,0)*Basis.from_euler(Vector3(.2,.4,.1))
	var pose := Transform3D(b,p);var forge: Node3D=arena.forge
	for kind in ["wall","door","ramp"]:
		forge.store.records=[forge.store.make(kind,pose)];forge.store.revision+=1
		var start := pose*Vector3(0,0,200);var end := pose*Vector3(0,0,-200)
		var hit := Obstruction.cast(arena,start,end)
		if kind=="door":
			assert(hit.is_empty(),"Door opening must remain open")
			hit=Obstruction.cast(arena,pose*Vector3(1.5,0,200),pose*Vector3(1.5,0,-200))
		assert(not hit.is_empty(),"Distant "+kind+" must block without physics")
		assert(forge.bodies.is_empty())
		if kind=="wall": assert(Obstruction.cast(arena,start,pose*Vector3(0,0,10)).is_empty(),"Nearer physics endpoint wins")
		if kind=="ramp":
			hit=Obstruction.cast(arena,pose*Vector3(0,10,0),pose*Vector3(0,-10,0))
			assert(not hit.is_empty() and hit.position.distance_to(p)<.15,"Ramp surface must use slope")
	# Reusing the same record ID after an edit must invalidate cached geometry.
	var moved := Transform3D(b,p+b.x*20)
	preload("res://world/forge_store.gd").set_pose(forge.store.records[0],moved);forge.store.revision+=1
	assert(Obstruction.cast(arena,pose*Vector3(0,0,200),pose*Vector3(0,0,-200)).is_empty())
	assert(not Obstruction.cast(arena,moved*Vector3(0,0,200),moved*Vector3(0,0,-200)).is_empty())
	forge.store.records=[];forge.store.revision+=1
	arena.painted_trees.candidates=[{"valid":true,"transform":pose,"height":10.0}]
	assert(not Obstruction.cast(arena,pose*Vector3(0,2,200),pose*Vector3(0,2,-200)).is_empty())
	assert(Obstruction.cast(arena,pose*Vector3(1,2,200),pose*Vector3(1,2,-200)).is_empty())
	var cap := Obstruction.cylinder_segment(Vector3(0,10,0),Vector3(0,-10,0),.22,4.5)
	assert(absf(cap.t-.275)<.00001 and cap.normal==Vector3.UP)
	assert(Obstruction.cylinder_segment(Vector3(0,2,0),Vector3(0,2,10),.22,4.5).is_empty())
	print("WEAPON_OBSTRUCTION_PASS: distant walls, door openings, rotated ring geometry, ramp slopes, tree trunks/caps, nearer endpoints; no physics bodies")
	arena.free();quit()
