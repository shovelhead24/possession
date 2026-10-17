extends "res://benchmarks/check_rebuild_rex_impacts.gd"
func run():
	var arena=Arena.new();root.add_child(arena)
	arena.camera=Camera3D.new();arena.add_child(arena.camera)
	arena.on_foot=Foot.new();arena.on_foot.active=false;arena.add_child(arena.on_foot)
	arena.vehicle_kit.car=RigidBody3D.new();arena.add_child(arena.vehicle_kit.car);arena.vehicle_kit.car.freeze=true
	arena.aliens=preload("res://world/aliens/manager.gd").new();arena.aliens.arena=arena;arena.aliens.initialized=true;arena.add_child(arena.aliens);arena.aliens.set_physics_process(false)
	var rex=preload("res://world/aliens/trex.gd").new();rex.arena=arena;rex.manager=arena.aliens;arena.add_child(rex);rex.set_physics_process(false);rex.position=Vector3.ZERO;rex.global_basis=Basis.IDENTITY;rex.runtime_active=true
	arena.camera.position=Vector3(50,20,35);arena.camera.look_at(Vector3(0,12,0));arena.camera.current=true
	for i in 3: await process_frame
	for i in rex.skeleton.get_bone_count():
		print("REX_BONE ",rex.skeleton.get_bone_name(i)," ",rex.to_local(rex.skeleton.to_global(rex.skeleton.get_bone_global_pose(i).origin)))
	arena.free();quit()
