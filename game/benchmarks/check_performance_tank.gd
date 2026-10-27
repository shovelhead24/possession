extends SceneTree
class Flags extends RefCounted:
	var opened=false
	var dismissed=true
class Effects extends RefCounted:
	var effects: Array=[]
	func update_effects():pass
class Target extends StaticBody3D:
	var damage=0.0
	func take_hit(amount,_start,_point):damage+=amount
class Arena extends Node3D:
	var on_foot: CharacterBody3D
	var camera: Camera3D
	var editor=Flags.new()
	var loading=Flags.new()
	var weapons=Effects.new()
class Kit extends Node:
	var arena: Node3D
	var vehicles: Array=[]
	var driving=false
	var car: RigidBody3D
	var menu=Flags.new()
func _initialize():
	create_timer(30).timeout.connect(func():quit(1))
	run.call_deferred()
func run():
	root.size=Vector2i(1280,720)
	var arena=Arena.new();root.add_child(arena);arena.on_foot=CharacterBody3D.new();arena.add_child(arena.on_foot)
	var kit=Kit.new();kit.arena=arena;arena.add_child(kit)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.12,.15,.18);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.7;arena.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);arena.add_child(sun)
	var camera=Camera3D.new();arena.add_child(camera);camera.position=Vector3(10,8,-15);camera.look_at(Vector3(0,1,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=19;camera.current=true
	arena.camera=camera
	for index in 2:
		var tank=preload("res://world/performance_tank_factory.gd").create(kit,Transform3D(Basis.IDENTITY,Vector3(index*8-4,0,0)))
		tank.freeze=true;tank.process_mode=Node.PROCESS_MODE_DISABLED
		assert(tank.corners.size()==8);assert(tank.tracks.wheels.size()==14)
		var hull=tank.shell.global_transform;var muzzle=tank.muzzle.global_position
		if index==1:
			tank.turret.rotation.y=deg_to_rad(60);tank.barrel.rotation.x=deg_to_rad(20)
			assert(tank.muzzle.global_position.distance_to(muzzle)>1)
			assert(tank.shell.global_transform.is_equal_approx(hull))
		var before=tank.tracks.wheels[0].pivot.basis;tank.tracks.animate(.1,2,2);assert(not before.is_equal_approx(tank.tracks.wheels[0].pivot.basis))
		var label=Label3D.new();label.text="Neutral" if index==0 else "Yaw 60 / elevation 20";label.position=Vector3(index*8-4,3.5,0);label.font_size=42;label.pixel_size=.01;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;arena.add_child(label)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/tank-articulation.png")
	var car=kit.vehicles[0];kit.car=car;kit.driving=true
	var target=Target.new();arena.add_child(target);target.position=car.muzzle.global_position-car.muzzle.global_basis.z*12
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(3,3,1);target.add_child(shape)
	await physics_frame;await physics_frame
	assert(car.fire_cannon());assert(target.damage==car.cannon_damage);assert(not car.fire_cannon())
	var ground=StaticBody3D.new();arena.add_child(ground);ground.position.y=-.5
	var floor_shape=CollisionShape3D.new();floor_shape.shape=BoxShape3D.new();floor_shape.shape.size=Vector3(100,1,100);ground.add_child(floor_shape)
	car.position.y=.3;car.process_mode=Node.PROCESS_MODE_INHERIT;car.set_process(false);car.set_stream_ready(true);car.freeze=false
	car.set_controls(0,0,true)
	for i in 120:await physics_frame
	assert(car.grounded_count>=6,"Tank suspension must support the hull")
	var start=car.position;car.controlled=true;car.set_controls(.8,0,false)
	for i in 180:await physics_frame
	assert(car.position.distance_to(start)>1,"Tank must drive under its own controls")
	print("PASS tank eight contacts, fourteen animated wheels, independent turret/pitch and muzzle movement")
	print("PASS cannon damage/reload and grounded tank driving")
	quit()

