extends RefCounted
static var template: PackedScene
static var audit := {}
static func prepare() -> void:
	if template: return
	var importer=preload("res://world/arena_live_content.gd").new()
	var path=ProjectSettings.globalize_path("res://altay_main_battle_tank_fbx.glb")
	var document=GLTFDocument.new();var state=GLTFState.new()
	assert(document.append_from_file(path,state)==OK,"Tank source unavailable")
	preload("res://world/runtime_mesh_lod.gd").prepare(state,path)
	var original=0;var reduced=0
	for entry in state.get_meshes():
		var mesh: ImporterMesh=entry.mesh
		var result=ImporterMesh.new()
		for surface in mesh.get_surface_count():
			var arrays=mesh.get_surface_arrays(surface);var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			original+=indices.size()/3
			var chosen=indices
			for level in mesh.get_surface_lod_count(surface):
				var candidate: PackedInt32Array=mesh.get_surface_lod_indices(surface,level)
				if candidate.size()<chosen.size() and candidate.size()>=maxi(24,int(indices.size()*.06)): chosen=candidate
			arrays[Mesh.ARRAY_INDEX]=chosen;reduced+=chosen.size()/3
			result.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},mesh.get_surface_material(surface))
		entry.mesh=result
	var model=document.generate_scene(state)
	var bounds=importer.model_bounds(model)
	if bounds.size.x>bounds.size.z: model.rotate_y(-PI/2)
	model.rotate_y(PI);bounds=importer.model_bounds(model);model.scale*=9.0/maxf(bounds.size.x,bounds.size.z)
	bounds=importer.model_bounds(model);model.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	for child in model.find_children("*","",true,false): child.owner=model
	template=PackedScene.new();template.pack(model);model.free()
	importer.contact_debug.free();importer.free()
	audit={"source_triangles":original,"reduced_triangles":reduced}
	print("REBUILD_TANK_MODEL ",JSON.stringify(audit))
static func create(kit: Node, pose: Transform3D) -> RigidBody3D:
	prepare()
	var tank=preload("res://world/rebuild_tank.gd").new();tank.name="Altay";tank.kit=kit
	kit.arena.add_child(tank);tank.set_stream_ready(false);tank.recovery_floor=-INF;tank.collision_layer=2;tank.collision_mask=7;tank.suspension_mask=7
	var model=template.instantiate();tank.add_child(model);tank.shell=model
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2.6,.9,5.2);collision.shape=box;collision.position=Vector3(0,.9,.6);tank.add_child(collision)
	tank.setup_tank(model,kit)
	var batch=preload("res://world/rigid_mesh_batch.gd")
	var identity="rebuild-reduced-v2"+FileAccess.get_sha256("res://altay_main_battle_tank_fbx.glb")
	batch.combine(model,[],identity+"hull");batch.combine(tank.turret,[tank.barrel],identity+"turret");batch.combine(tank.barrel,[],identity+"barrel")
	for mesh in tank.find_children("*","MeshInstance3D",true,false):
		mesh.visibility_range_end=280
		if mesh.layers==0 or "wheel" in str(mesh.name).to_lower(): mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for draw in tank.tracks.get_children():
		if draw is MultiMeshInstance3D:
			draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;draw.visibility_range_end=280
	tank.global_transform=pose;tank.gravity_up=preload("res://world/terrain_drive_ring.gd").up_at(pose.origin);tank.reset_physics_interpolation()
	tank.actor_impact.connect(func(body,point,relative,normal):
		if is_instance_valid(body) and body.has_method("vehicle_impact"): body.vehicle_impact(tank,point,relative,normal))
	kit.vehicles.append(tank)
	return tank
