extends "res://benchmarks/check_rebuild_rex_impacts.gd"
func run():
	var arena=Arena.new();root.add_child(arena);arena.add_child(arena.painted_trees)
	arena.on_foot=Foot.new();arena.add_child(arena.on_foot);arena.on_foot.position=Vector3(0,0,100)
	var capsule=CollisionShape3D.new();capsule.shape=CapsuleShape3D.new();capsule.shape.height=1.8;capsule.position.y=.9;arena.on_foot.add_child(capsule)
	arena.vehicle_kit.car=RigidBody3D.new();arena.add_child(arena.vehicle_kit.car);arena.vehicle_kit.car.position=Vector3(0,0,200);arena.vehicle_kit.car.freeze=true
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.position=Vector3(20,10,30);arena.camera.look_at(Vector3(0,4,0));arena.camera.current=true
	var floor_body=StaticBody3D.new();floor_body.collision_layer=1;arena.add_child(floor_body);floor_body.position.y=-.5
	var floor_shape=CollisionShape3D.new();floor_shape.shape=BoxShape3D.new();floor_shape.shape.size=Vector3(1000,1,1000);floor_body.add_child(floor_shape)
	arena.forge=preload("res://world/forge_world.gd").new();arena.add_child(arena.forge);arena.forge.set_physics_process(false)
	arena.aliens=preload("res://world/aliens/manager.gd").new();arena.add_child(arena.aliens)
	await physics_frame;await physics_frame;await arena.aliens.setup(arena)
	var manager=arena.aliens;manager.stream_enabled=false;manager.set_physics_process(false)
	var rex=preload("res://world/aliens/trex.gd").new();rex.arena=arena;rex.manager=manager;rex.patrol=[Vector3.ZERO,Vector3(0,0,30)];manager.add_child(rex);manager.trex=rex;rex.behavior_mode=3
	await create_timer(.5).timeout
	print("REX_SIZE model_scale=",rex.model.scale," rig_scale=",rex.skeleton.global_basis.get_scale()," mouth=",rex.mouth_point()," feet=",rex.grounding.last_feet)
	for attack in 4:
		manager.health=100;manager.defeated=false;rex.begin_bite(arena.on_foot)
		var points=[]
		for frame in (47 if attack==3 else 19):
			await create_timer(.1).timeout
			points.append({"t":rex.attack_elapsed(),"bite":rex.bite_time,"recovery":rex.attack_recovery,"mouth":str(rex.mouth_point()),"held":arena.on_foot.has_meta("trex_held"),"active":rex.runtime_active,"physics":rex.is_physics_processing(),"pose":str(rex.attack_pose())})
		print("LIVE_BITE ",attack," ",JSON.stringify(points))
	arena.free();quit()
