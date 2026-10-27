extends RefCounted
static var template: PackedScene
static func prepare() -> void:
	if template:return
	var doc=GLTFDocument.new();var state=GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path("res://assets/performance_tanks/Tank-articulated.glb"),state)==OK)
	var model=doc.generate_scene(state)
	var importer=preload("res://world/arena_live_content.gd").new()
	model.rotate_y(PI);model.scale*=1.45
	var bounds=importer.model_bounds(model)
	model.position-=Vector3(bounds.get_center().x,bounds.position.y,0);model.position.z+=.6
	for child in model.find_children("*","",true,false):child.owner=model
	template=PackedScene.new();assert(template.pack(model)==OK);model.free();importer.contact_debug.free();importer.free()
static func create(kit: Node, pose: Transform3D) -> RigidBody3D:
	prepare()
	var tank=preload("res://world/performance_tank.gd").new();tank.name="LowPolyTank";tank.kit=kit
	kit.arena.add_child(tank);tank.set_stream_ready(false);tank.recovery_floor=-INF;tank.collision_layer=2;tank.collision_mask=7;tank.suspension_mask=7
	var model=template.instantiate();tank.add_child(model);tank.shell=model
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2.6,.9,5.2);collision.shape=box;collision.position=Vector3(0,.9,.6);tank.add_child(collision)
	tank.setup_tank(model,kit)
	var batch=preload("res://world/rigid_mesh_batch.gd")
	var identity="performance-tank-v1"+FileAccess.get_sha256("res://assets/performance_tanks/Tank-articulated.glb")
	batch.combine(model,[],identity+"hull");batch.combine(tank.turret,[tank.barrel],identity+"turret");batch.combine(tank.barrel,[],identity+"barrel")
	for mesh in tank.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=280
	tank.global_transform=pose;tank.gravity_up=preload("res://world/terrain_drive_ring.gd").up_at(pose.origin);tank.reset_physics_interpolation()
	tank.actor_impact.connect(func(body,point,relative,normal):
		if is_instance_valid(body) and body.has_method("vehicle_impact"):body.vehicle_impact(tank,point,relative,normal))
	kit.vehicles.append(tank)
	return tank
