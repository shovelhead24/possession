extends "res://world/arena_content.gd"
var kit: Node

func freeze_source_pose() -> bool:
	return false

func model_bounds(root: Node3D) -> AABB:
	# Measure the posed skin without freezing the live visual or losing weights.
	var meshes := []
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if mesh.skin and mesh.get_node_or_null(mesh.skeleton) is Skeleton3D:
			var posed: ArrayMesh=mesh.bake_mesh_from_current_skeleton_pose()
			if posed:
				meshes.append([mesh,mesh.mesh]);mesh.mesh=posed
	var bounds := super.model_bounds(root)
	for pair in meshes: pair[0].mesh=pair[1]
	return bounds

func setup(tile: Node3D) -> void:
	kit=preload("res://world/arena_gameplay.gd").new();tile.add_child(kit);kit.arena=tile;kit.content=self
	super.setup(tile)

func add_entry(title: String, model: Node3D, coord: Vector2, height: float) -> void:
	var hit := ground_at(coord)
	assert(not hit.is_empty())
	model.show();model.process_mode=Node.PROCESS_MODE_INHERIT
	var root: Node3D
	if title=="Warthog":
		root=preload("res://world/wishbone_vehicle.gd").new()
		root.name="Warthog";root.collision_layer=2;root.collision_mask=3
		patch.add_child(root);root.position=hit.position+Vector3.UP*.3;root.add_child(model)
		var collision := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(1.8,1.1,3.3)
		collision.shape=box;collision.position.y=1.1;root.add_child(collision)
		root.setup(model,Callable(self,"model_bounds"));kit.vehicle=root;kit.vehicle_home=root.transform
		kit.setup_turret(model)
	else:
		if title=="Alien": model.rotation.y=PI # Also idempotent for duplicated live models.
		root=preload("res://world/arena_actor.gd").new();root.name=title.replace("-","")
		patch.add_child(root);root.position=hit.position
		var points: Array[Vector3]=[]
		if title=="T-Rex":
			points=[Vector3(43,0,-2),Vector3(74,0,20),Vector3(65,0,66),Vector3(42,0,48)]
		else:
			points=[Vector3(coord.x,0,coord.y),Vector3(coord.x-14,0,coord.y-25),Vector3(coord.x+10,0,coord.y-35),Vector3(coord.x+12,0,coord.y)]
		root.setup(patch,model,title,height,points,kit);kit.actors.append(root)
	entries.append({"name":title,"root":root,"model":model,"coord":coord,"height":height,"label":root.get("label")})

func load_arena() -> void:
	await super.load_arena()
	await kit.build_weapons()
	kit.initialized=true
	kit.build_routes()
	print("ARENA_GAMEPLAY ready actors=",kit.actors.size()," weapons=",kit.weapons.size()," wheels=",kit.vehicle.corners.size())
