extends "res://world/arena_content.gd"
var kit: Node

func source_specs() -> Array:
	var specs := super.source_specs()
	specs.append(["Altay","res://altay_main_battle_tank_fbx.glb",Vector2(-47,-34),9.0,false])
	return specs

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
	kit.vehicle_system=preload("res://world/arena_vehicles.gd").new()
	kit.add_child(kit.vehicle_system);kit.vehicle_system.arena=tile;kit.vehicle_system.gameplay=kit;kit.vehicle_system.content=self
	super.setup(tile)

func add_entry(title: String, model: Node3D, coord: Vector2, height: float) -> void:
	var hit := ground_at(coord)
	assert(not hit.is_empty())
	model.show();model.process_mode=Node.PROCESS_MODE_INHERIT
	var root: Node3D
	if title in ["Warthog","Altay"]:
		root=preload("res://world/wishbone_vehicle.gd").new() if title=="Warthog" else preload("res://world/tank_controller.gd").new()
		root.name=title;root.collision_layer=2;root.collision_mask=3
		patch.add_child(root);root.position=hit.position+Vector3.UP*.3;root.add_child(model)
		var a := model_bounds(model)
		var collision := CollisionShape3D.new()
		if title=="Warthog":
			var box := BoxShape3D.new();box.size=Vector3(a.size.x*.82,.76,4.8*.92)
			collision.shape=box;collision.position.y=.85;root.add_child(collision)
			preload("res://world/warthog_finish.gd").finish(model,Callable(self,"model_bounds"))
			root.track_extension=.18;root.wheel_mount_raise=.14;root.center_of_mass.y=.48
			root.setup(model,Callable(self,"model_bounds"));kit.vehicle=root;kit.vehicle_home=root.transform
			var turret := preload("res://world/warthog_turret.gd").new();root.add_child(turret)
			turret.setup(kit.vehicle_system,root,model);kit.vehicle_system.warthog_turret=turret
		else:
			var shape := ConvexPolygonShape3D.new();var half_width := a.size.x*.31
			var front := -9.0*.275;var rear := 9.0*.275
			shape.points=PackedVector3Array([Vector3(-half_width,.38,front),Vector3(half_width,.38,front),Vector3(-half_width,0,rear),Vector3(half_width,0,rear),Vector3(-half_width,.72,front),Vector3(half_width,.72,front),Vector3(-half_width,.72,rear),Vector3(half_width,.72,rear)])
			collision.shape=shape;collision.position.y=.45;root.add_child(collision)
			root.setup_tank(model,kit.vehicle_system)
		kit.vehicle_system.register_vehicle(root)
		root.add_child(preload("res://world/vehicle_audio.gd").new())
		root.add_child(preload("res://world/wheel_dirt.gd").new())
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
	if patch.has_method("loading_event"):
		patch.loading_event("Preparing first-person arms, weapons and vehicle controls")
		await RenderingServer.frame_post_draw
	await kit.build_weapons()
	kit.vehicle_system.initialize()
	kit.initialized=true
	kit.build_routes()
	print("ARENA_GAMEPLAY ready actors=",kit.actors.size()," weapons=",kit.weapons.size()," wheels=",kit.vehicle.corners.size())
