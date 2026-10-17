extends SceneTree
const Weapons=preload("res://world/rebuild_weapons.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
class Flag extends RefCounted:
	var opened := false
	var dismissed := true
class Streamer extends RefCounted:
	var ready := true
	func ready_at(_p: Vector3) -> bool: return ready
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
class Target extends StaticBody3D:
	var damage := 0.0
	func take_hit(amount: float,_origin: Vector3,_point: Vector3) -> String:
		damage+=amount;return "Target hit"
func press(weapon: Node,code: int) -> void:
	var event := InputEventKey.new();event.pressed=true;event.keycode=code;weapon.handle_input(event)
func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("Weapons core timeout");quit(1))
	run.call_deferred()
func run() -> void:
	var arena := Arena.new();root.add_child(arena)
	arena.on_foot=Foot.new();arena.add_child(arena.on_foot)
	arena.camera=Camera3D.new();arena.add_child(arena.camera)
	var p := Ring.point(100000,10,0);var basis := Ring.tangent_basis(p,0)
	arena.camera.transform=Transform3D(basis,p);arena.on_foot.position=p
	var target := Target.new();target.collision_layer=2;arena.add_child(target);target.transform=Transform3D(basis,p-basis.z*12)
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(3,3,1);shape.shape=box;target.add_child(shape)
	var weapon := Weapons.new();arena.add_child(weapon);weapon.arena=arena;weapon.set_process(false);weapon.set_physics_process(false)
	weapon.build_overlay()
	weapon.models=[Node3D.new(),Node3D.new(),Node3D.new(),Node3D.new(),Node3D.new()]
	for model in weapon.models: weapon.add_child(model)
	weapon.plasma=preload("res://world/plasma_billboards.gd").new();arena.add_child(weapon.plasma);weapon.plasma.setup(weapon)
	weapon.sounds=[null,null,null,null,null];weapon.initialized=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await physics_frame;await physics_frame
	assert(weapon.fire());assert(target.damage==25 and weapon.ammo[0]==29 and weapon.shots==1)
	assert(not weapon.fire());weapon.cooldown=0;press(weapon,KEY_2);assert(weapon.selected==1)
	assert(weapon.fire() and target.damage==145 and weapon.ammo[1]==4)
	assert(weapon.start_reload());press(weapon,KEY_1);assert(weapon.selected==1)
	weapon._physics_process(1.6);assert(weapon.ammo[1]==5 and weapon.reload_time==0)
	weapon.ammo[1]=0;weapon.cooldown=0;assert(not weapon.fire())
	assert(weapon.start_reload());arena.editor.opened=true;weapon._physics_process(.1)
	assert(weapon.reload_time==0 and weapon.ammo[1]==0 and not weapon.fire())
	arena.editor.opened=false;weapon.ammo[1]=5
	for gate in ["briefing","vehicle","tuning","streaming"]:
		match gate:
			"briefing": arena.loading.dismissed=false
			"vehicle": arena.on_foot.active=false
			"tuning": arena.vehicle_kit.menu.opened=true
			"streaming": arena.streamer.ready=false
		assert(not weapon.fire(),gate+" must block fire")
		arena.loading.dismissed=true;arena.on_foot.active=true;arena.vehicle_kit.menu.opened=false;arena.streamer.ready=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	assert(not weapon.handle_input(click) and not weapon.trigger_held and not weapon.fire())
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;assert(weapon.handle_input(click) and weapon.trigger_held)
	click.pressed=false;weapon.handle_input(click);assert(not weapon.trigger_held)
	# A nearer layer-2 construction-like wall stops damage reaching the target.
	var blocker := StaticBody3D.new();blocker.collision_layer=2;arena.add_child(blocker);blocker.transform=Transform3D(basis,p-basis.z*6)
	var blocking_shape := CollisionShape3D.new();blocking_shape.shape=box;blocker.add_child(blocking_shape)
	await physics_frame;await physics_frame
	weapon.cooldown=0;assert(weapon.fire() and target.damage==145 and weapon.last_hit.collider==blocker)
	weapon._physics_process(.2);assert(weapon.effects.is_empty())
	blocker.free();await physics_frame;await physics_frame
	weapon.cooldown=0;press(weapon,KEY_3);assert(weapon.selected==2)
	assert(weapon.fire() and weapon.ammo[2]==99 and target.damage==145)
	weapon.plasma.set_physics_process(false)
	weapon.plasma._physics_process(.05);assert(target.damage==145)
	weapon.select_weapon(0)
	weapon.plasma._physics_process(.15);assert(target.damage==159)
	weapon.plasma._physics_process(.15);assert(target.damage==159)
	weapon.select_weapon(2)
	assert(weapon.start_reload());weapon._physics_process(1.6);assert(weapon.ammo[2]==100)
	press(weapon,KEY_Q);assert(weapon.selected==3);press(weapon,KEY_Q);assert(weapon.selected==4);press(weapon,KEY_Q);assert(weapon.selected==0);press(weapon,KEY_Q);assert(weapon.selected==1);press(weapon,KEY_Q);assert(weapon.selected==2)
	print("WEAPONS_CORE_PASS: ring-oriented hits, damage, wall obstruction, ammo/cooldowns, reload, selection, cursor recapture, all mode gates, effect expiry")
	arena.free();quit()
