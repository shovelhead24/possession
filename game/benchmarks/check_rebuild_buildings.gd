extends SceneTree
const Buildings=preload("res://world/rebuild_buildings.gd")
const Compounds=preload("res://world/arena_compounds.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var building := Node3D.new();Compounds.new().building(building,Vector3.ZERO)
	var original := building.get_child_count()
	var batches := Buildings.batch_boxes(building)
	assert(batches.size()==2)
	var bodies := 0;var instances := 0
	for child in building.get_children():
		if child is StaticBody3D:
			bodies+=1;assert(child.collision_layer==2)
	for batch in batches: instances+=batch.multimesh.instance_count
	assert(bodies==original and instances==original)
	root.add_child(building)
	var p := Ring.point(100000,0,0);var basis := Ring.tangent_basis(p,0)
	building.transform=Transform3D(basis,p)
	await physics_frame;await physics_frame
	var space := root.world_3d.direct_space_state
	# Ray through the 2 m doorway stays clear; adjacent wall blocks.
	var door := PhysicsRayQueryParameters3D.create(p+basis*Vector3(0,1,10),p+basis*Vector3(0,1,5),2)
	assert(space.intersect_ray(door).is_empty())
	var wall := PhysicsRayQueryParameters3D.create(p+basis*Vector3(3,1,10),p+basis*Vector3(3,1,5),2)
	assert(not space.intersect_ray(wall).is_empty())
	var floor_ray := PhysicsRayQueryParameters3D.create(p+basis*Vector3(0,1,0),p+basis*Vector3(0,-1,0),2)
	assert(not space.intersect_ray(floor_ray).is_empty())
	print("REBUILD_BUILDINGS_PASS parts=",original," batches=",batches.size()," preserved collision, ring doorway/wall/floor")
	building.free();quit()
