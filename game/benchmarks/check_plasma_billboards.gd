extends SceneTree
class Flag extends RefCounted:
	var opened := false
	var dismissed := true
	func log_event(text: String) -> void: print(text)
class Streamer extends RefCounted:
	func ready_at(_p: Vector3) -> bool: return true
class Foot extends CharacterBody3D:
	var active := true
class Kit extends RefCounted:
	var menu := Flag.new()
class Arena extends Node3D:
	var ready_to_play := true
	var on_foot: Foot
	var editor := Flag.new()
	var loading := Flag.new()
	var vehicle_kit := Kit.new()
	var streamer := Streamer.new()
	var camera: Camera3D
	var forge: Node
	var painted_trees: Node
func _initialize() -> void: run.call_deferred()
class Target extends StaticBody3D:
	var damage := 0.0
	func take_hit(amount: float,_origin: Vector3,_point: Vector3) -> void: damage+=amount
func run() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	var arena := Arena.new();root.add_child(arena)
	arena.on_foot=Foot.new();arena.add_child(arena.on_foot)
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.make_current()
	var weapons := preload("res://world/rebuild_weapons.gd").new();arena.add_child(weapons);await weapons.setup(arena)
	assert(weapons.models.size()==5 and weapons.sounds[2].get_length()<.27)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for index in [2,3,4]:
		weapons.select_weapon(index)
		await create_timer(.3).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs/weapon-"+str(index+1)+".png")
	var target := Target.new();target.collision_layer=4;arena.add_child(target);target.position=Vector3(0,0,-10)
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(2,2,.02);shape.shape=box;target.add_child(shape)
	await physics_frame;await physics_frame
	var plasma: Node=weapons.plasma
	plasma.launch(Vector3.ZERO,Vector3.FORWARD,200,14,Vector3.ZERO);plasma.set_physics_process(false)
	plasma._physics_process(.05);assert(target.damage==0)
	plasma._physics_process(.1);assert(target.damage==14 and plasma.bolts.is_empty())
	plasma._physics_process(.1);assert(target.damage==14)
	plasma.launch(Vector3.ZERO,Vector3.FORWARD,200,14,Vector3.ZERO);plasma.set_physics_process(false)
	target.position.x=5;await physics_frame;await physics_frame
	plasma._physics_process(.2);assert(target.damage==14)
	plasma._physics_process(3);assert(plasma.bolts.is_empty())
	# A target moving into the path is hit, even though it was absent at launch.
	plasma.launch(Vector3.ZERO,Vector3.FORWARD,200,18,Vector3.ZERO);plasma.set_physics_process(false)
	target.position.x=0;await physics_frame;await physics_frame
	plasma._physics_process(.2);assert(target.damage==32)
	for i in 32: assert(plasma.launch(Vector3.ZERO,Vector3.RIGHT,1,14,Vector3.ZERO))
	assert(not plasma.launch(Vector3.ZERO,Vector3.RIGHT,1,14,Vector3.ZERO))
	var saved_ammo: int=weapons.ammo[weapons.selected]
	weapons.cooldown=0
	assert(not weapons.fire() and weapons.ammo[weapons.selected]==saved_ammo)
	plasma.set_physics_process(false);plasma._physics_process(1);plasma._process(1)
	assert(plasma.bolts.is_empty() and plasma.bursts.is_empty() and not plasma.is_processing())
	weapons.select_weapon(2);await create_timer(.3).timeout
	var redraws: int=weapons.view_redraws
	weapons.trigger_held=true;await create_timer(.7).timeout;weapons.trigger_held=false
	plasma.flash=.06;plasma._process(0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs/projectile-flash.png")
	assert(weapons.view_redraws==redraws,"Firing must reuse cached model render")
	var loading=preload("res://world/workshop_loading.gd").new();loading.brief_path="res://world/rebuild_demo_brief.json";arena.add_child(loading)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs/projectile-loading-fixture.png")
	print("PLASMA_PROJECTILES_PASS: five models, short audio, delayed damage, thin wall sweep, moving targets, bounded pool, expiry, cached firing and visible briefing")
	quit()
