extends SceneTree
class Menu extends RefCounted:
	var opened=false
class Loader extends RefCounted:
	var dismissed=true
class Editor extends RefCounted:
	var opened=false
class Weapons extends RefCounted:
	var effects=[]
	func update_effects(): pass
class Arena extends Node3D:
	var on_foot: CharacterBody3D
	var camera: Camera3D
	var editor=Editor.new()
	var loading=Loader.new()
	var weapons=Weapons.new()
	var controller: Node
class Kit extends Node:
	var arena: Node3D
	var menu=Menu.new()
	var driving=true
	var car: RigidBody3D
	var vehicles=[]
	var driver_look=Vector2.ZERO
class Target extends StaticBody3D:
	var damage=0.0
	func take_hit(amount,_from,_point): damage+=amount
func _initialize():
	create_timer(180).timeout.connect(func(): quit(1))
	run.call_deferred()
func sample() -> Dictionary:
	for i in 20: await process_frame
	var times=[];var last=Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var now=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
	var sum=0.0
	for t in times: sum+=t
	times.sort()
	return {"mean_ms":sum/times.size(),"p95_ms":times[114],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
func run():
	root.size=Vector2i(1366,768);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var arena=Arena.new();root.add_child(arena)
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.current=true;arena.camera.position=Vector3(8,5,-10);arena.camera.look_at(Vector3(0,1,0))
	arena.on_foot=CharacterBody3D.new();arena.add_child(arena.on_foot);arena.on_foot.position=Vector3(30,0,0)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.18,.23,.28);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;arena.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-25,0);sun.shadow_enabled=true;arena.add_child(sun)
	var kit=Kit.new();kit.arena=arena;arena.add_child(kit)
	var factory=preload("res://world/rebuild_tank_factory.gd")
	var tank=factory.create(kit,Transform3D.IDENTITY);kit.car=tank
	assert(tank.corners.size()==8 and tank.tracks.sides.size()==2)
	assert(factory.audit.reduced_triangles<factory.audit.source_triangles*.5)
	kit.driver_look=Vector2(.4,.15);tank._process(1);assert(tank.turret.rotation.y>.1 and tank.barrel.rotation.x>.05)
	kit.driver_look=Vector2.ZERO;tank._process(2)
	var target=Target.new();target.collision_layer=2;arena.add_child(target)
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(3,3,1);collision.shape=box;target.add_child(collision)
	target.position=tank.muzzle.global_position-tank.muzzle.global_basis.z*10
	await physics_frame;await physics_frame
	assert(tank.fire_cannon());assert(target.damage==tank.cannon_damage);assert(not tank.fire_cannon())
	kit.menu.opened=true;tank.cooldown=0;assert(not tank.fire_cannon());kit.menu.opened=false
	target.free();tank.cooldown=100
	tank.hide();var hidden=await sample();tank.show();var visible=await sample()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs/tank-restored.png")
	var ground=StaticBody3D.new();ground.collision_layer=1;arena.add_child(ground)
	var ground_shape=CollisionShape3D.new();var ground_box=BoxShape3D.new();ground_box.size=Vector3(100,1,100);ground_shape.shape=ground_box;ground.add_child(ground_shape);ground.position.y=-.5
	tank.position=Vector3(0,.3,0);tank.set_stream_ready(true);tank.controlled=true;tank.set_controls(1,0,false)
	for i in 180: await physics_frame
	assert(tank.global_position.is_finite() and tank.grounded_count>0)
	assert(tank.global_position.z < -.5,"Tank must drive forward on its eight contacts")
	print("TANK_DRIVE position=",tank.global_position," speed=",tank.linear_velocity.length()," grounded=",tank.grounded_count)
	print("TANK_RENDER_AB ",JSON.stringify({"hidden":hidden,"visible":visible,"audit":factory.audit}))
	print("PASS tank rig, eight contacts, reduced geometry, turret traverse, cannon damage, cooldown and menu gate")
	quit()
