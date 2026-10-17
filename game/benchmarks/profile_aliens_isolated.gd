extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
class Flag extends RefCounted:
	var opened=false
	var dismissed=true
	var hud_hidden=false
	func log_event(message): print(message)
class Streamer extends RefCounted:
	func ready_at(_p): return true
class Destruction extends RefCounted:
	var applied_revision=0
	func busy(): return false
class Store extends RefCounted:
	var records=[]
class Trees extends Node:
	var store=Store.new()
	var enabled=false
class Weapons extends RefCounted:
	var trigger_held=false
class Foot extends CharacterBody3D:
	var active=true
	func activate_at(p): global_position=p;active=true
class Kit extends RefCounted:
	var car: CharacterBody3D
	var menu=Flag.new()
	var driving=false
class Arena extends Node3D:
	var ready_to_play=true
	var loading=Flag.new()
	var editor=Flag.new()
	var collision_debug=Flag.new()
	var streamer=Streamer.new()
	var destruction=Destruction.new()
	var weapons=Weapons.new()
	var vehicle_kit=Kit.new()
	var painted_trees=Trees.new()
	var camera: Camera3D
	var on_foot: Foot
	var forge: Node3D
	var aliens: Node3D
var output="C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs"
func _initialize():
	create_timer(100).timeout.connect(func(): push_error("Alien test timeout");quit(1))
	run.call_deferred()
func screenshot(name):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name))
func run():
	var arena=Arena.new();root.add_child(arena)
	arena.add_child(arena.painted_trees)
	arena.on_foot=Foot.new();arena.add_child(arena.on_foot);arena.on_foot.position=Vector3(0,0,38);arena.on_foot.collision_layer=2
	var capsule=CollisionShape3D.new();capsule.shape=CapsuleShape3D.new();capsule.shape.height=1.8;capsule.shape.radius=.35;capsule.position.y=.9;arena.on_foot.add_child(capsule)
	arena.vehicle_kit.car=CharacterBody3D.new();arena.add_child(arena.vehicle_kit.car);arena.vehicle_kit.car.position=Vector3(0,0,200)
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.position=Vector3(0,4,14);arena.camera.look_at(Vector3(0,1,0));arena.camera.current=true
	var floor_body=StaticBody3D.new();floor_body.collision_layer=1;arena.add_child(floor_body);floor_body.position.y=-.5
	var floor_shape=CollisionShape3D.new();floor_shape.shape=BoxShape3D.new();floor_shape.shape.size=Vector3(1000,1,1000);floor_body.add_child(floor_shape)
	var mesh=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.mesh.size=Vector3(1000,1,1000);floor_body.add_child(mesh)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);arena.add_child(light)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.6;arena.add_child(env)
	arena.forge=preload("res://world/forge_world.gd").new();arena.add_child(arena.forge);arena.forge.set_physics_process(false)
	arena.aliens=preload("res://world/aliens/manager.gd").new();arena.add_child(arena.aliens)
	await physics_frame;await physics_frame
	await arena.aliens.setup(arena)

	var manager=arena.aliens;manager.stream_enabled=false;manager.set_physics_process(false)
	manager.garrisons.resize(2);manager.garrisons[0].home=Vector3(-5,0,0);manager.garrisons[1].home=Vector3(5,0,-10);manager.stream_squads()
	assert(manager.enemies.size()==10)
	light.shadow_enabled=true;light.directional_shadow_max_distance=70;light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	for squad in manager.squads: squad.set_physics_process(false)
	for unit in manager.enemies:
		unit.order(unit.position,0,"Idle")
		unit.set_physics_process(false)
	arena.camera.position=Vector3(0,5,15);arena.camera.look_at(Vector3(0,1,-5))
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await create_timer(2).timeout
	for unit in manager.enemies: unit.lizard.body_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await sample(manager,"render_animated_no_shadows")
	for unit in manager.enemies: unit.lizard.set_process(false)
	await sample(manager,"render_frozen_no_shadows")
	for unit in manager.enemies:
		unit.lizard.set_process(true)
		for part in unit.lizard.find_children("*","MeshInstance3D",true,false):
			if "LizardSkin" in String(part.name): part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	await sample(manager,"render_animated_body_shadows")
	await screenshot("alien-shadows-optimized.png")
	for unit in manager.enemies: unit.set_physics_process(true)
	await sample(manager,"physics_and_shadows")
	for unit in manager.enemies: unit.set_physics_process(false)
	manager.hide()
	await sample(manager,"environment_only")
	quit()
func sample(manager,label):
	await create_timer(1).timeout
	var total=0.0;var frames=[];var prev=Time.get_ticks_usec();var draws=0.0;var objects=0.0
	for i in 480:
		await process_frame
		var now=Time.get_ticks_usec();var ms=(now-prev)/1000.0;prev=now;total+=ms;frames.append(ms)
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	frames.sort()
	print("ALIEN_ISOLATED ",label," ",JSON.stringify({"mean_ms":total/480,"fps":480000/total,"p95_ms":frames[456],"draws":draws/480,"primitives":objects/480}))
