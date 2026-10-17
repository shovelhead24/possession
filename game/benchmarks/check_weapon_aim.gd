extends "res://benchmarks/check_rebuild_weapons.gd"
class Enemies extends Node:
	var enemies=[]
	var defeated=false
	func alert_shot(_point): pass
class AimArena extends Arena:
	var aliens=Enemies.new()
	var collision_debug={"hud_hidden":false}
class Enemy extends Target:
	var health=50.0
	var dead=false
	var elite=false
class ControllerFoot extends "res://world/tree_on_foot.gd":
	var simulated_move=Vector2.ZERO
	var simulated_look=Vector2.ZERO
	func stick(x_axis: int, _y_axis: int) -> Vector2:
		return simulated_move if x_axis==JOY_AXIS_LEFT_X else simulated_look
class FootArena extends Node3D:
	var ready_to_play=true
	var editor=Flag.new()
	var loading=Flag.new()
	var vehicle_kit={"driving":false,"menu":Flag.new(),"driver_model":null}
	var camera: Camera3D
	var weapons: Node
func run() -> void:
	root.size=Vector2i(1280,800)
	var arena=AimArena.new();root.add_child(arena);arena.add_child(arena.aliens)
	arena.on_foot=Foot.new();arena.add_child(arena.on_foot)
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.current=true
	var target=Enemy.new();target.collision_layer=2;arena.add_child(target);target.position=Vector3(.8,-.8,-20);arena.aliens.enemies=[target]
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(.6,1.6,.6);shape.position.y=.8;target.add_child(shape)
	var mesh=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.mesh.size=Vector3(.6,1.6,.6);mesh.position.y=.8
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.2,.5,.3);mesh.material_override=material;target.add_child(mesh)
	var weapon=Weapons.new();arena.add_child(weapon);weapon.arena=arena;weapon.set_process(false);weapon.set_physics_process(false);weapon.build_overlay()
	weapon.spread_rng.seed=123;weapon.initialized=true;weapon.sounds.assign([null,null,null,null,null])
	weapon.aim_assist.settings_path="C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/work/test-aim.cfg"
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await physics_frame;await physics_frame
	weapon.aim_assist.strength=0;var off=weapon.aim_assist.solve(weapon)
	assert(off.on_enemy and off.direction.is_equal_approx(Vector3.FORWARD),"Off is unmodified camera aim")
	weapon.aim_state={};weapon._process(0);await shot("reticle-blue.png")
	weapon.aim_assist.strength=.35;var partial=weapon.aim_assist.solve(weapon)
	assert(partial.assisted and partial.direction.x>0 and partial.direction.x<.05,"Partial assist interpolates without camera movement")
	weapon.aim_assist.strength=1;var full=weapon.aim_assist.solve(weapon)
	assert(full.on_enemy and full.target==target and full.assisted,"Full assist acquires visible nearby enemy")
	weapon.aim_state=full;weapon._process(0);await shot("reticle-red.png")
	assert(weapon.crosshair.modulate.r>.9 and (weapon.crosshair.position+weapon.crosshair.size*.5).distance_to(Vector2(root.size)*.5)<.1,"Reticle remains centred while eligibility is red")
	assert(weapon.fire() and weapon.last_shot_aim.red,"Hitscan applies spread after eligible correction")
	var damage_before=target.damage
	weapon.plasma=preload("res://world/plasma_billboards.gd").new();arena.add_child(weapon.plasma);weapon.plasma.setup(weapon)
	weapon.selected=2;weapon.cooldown=0;assert(weapon.fire() and target.damage==damage_before,"Plasma aim ray must not apply immediate damage")
	weapon.plasma.set_physics_process(false);weapon.plasma.set_process(false)
	for i in 30: weapon.plasma._physics_process(1.0/60)
	assert(weapon.plasma.bolts.is_empty(),"Real projectile terminates normally; no in-flight homing")
	weapon.selected=0
	weapon.aim_assist.angle_degrees=1;assert(not weapon.aim_assist.solve(weapon).assisted,"Outside cone excluded")
	weapon.aim_assist.angle_degrees=4;target.dead=true;assert(not weapon.aim_assist.solve(weapon).on_enemy and not weapon.aim_assist.solve(weapon).assisted,"Dead targets excluded");target.dead=false
	var wall=StaticBody3D.new();wall.collision_layer=2;arena.add_child(wall);wall.position=Vector3(.5,0,-10)
	var wall_shape=CollisionShape3D.new();wall_shape.shape=BoxShape3D.new();wall_shape.shape.size=Vector3(2,3,.5);wall.add_child(wall_shape)
	await physics_frame;await physics_frame
	var blocked=weapon.aim_assist.solve(weapon);assert(not blocked.assisted and not blocked.on_enemy and blocked.hit.collider==wall,"Wall occludes acquisition and red indicator")
	wall.queue_free();await physics_frame;await physics_frame
	press(weapon,KEY_BRACKETLEFT);assert(is_equal_approx(weapon.aim_assist.strength,.9))
	var event=InputEventKey.new();event.keycode=KEY_BRACKETRIGHT;event.pressed=true;event.shift_pressed=true;assert(weapon.handle_input(event));assert(weapon.aim_assist.angle_degrees==5)
	var restored=preload("res://world/weapon_aim.gd").new();restored.settings_path=weapon.aim_assist.settings_path;restored.load_settings();assert(is_equal_approx(restored.strength,.9) and restored.angle_degrees==5,"Settings persist")
	# Nearest body surface follows aim height rather than the body centre.
	arena.camera.position.y=.5;weapon.aim_assist.strength=1;weapon.aim_assist.angle_degrees=4
	var edge=weapon.aim_assist.solve(weapon)
	assert(absf(edge.point.y-.5)<.08 and edge.point.x<.55,"Nearest collision surface, not centre/head snap")
	# Direct hits outside a weapon's red range remain possible, but stay blue.
	target.position=Vector3(0,-.8,-100);arena.camera.position.y=0
	await physics_frame;await physics_frame
	weapon.selected=0;assert(not weapon.aim_assist.solve(weapon).on_enemy,"Carbine outside red range")
	weapon.selected=1;assert(weapon.aim_assist.solve(weapon).on_enemy,"Railgun has its own longer red range")
	weapon.selected=0;target.position=Vector3(0,-.8,-20)
	await physics_frame;await physics_frame
	weapon.aim_state=weapon.aim_assist.solve(weapon)
	var aa=weapon.aim_assist;aa.reset_tracking()
	var neutral=aa.controller_filter(weapon,Vector2.ZERO,Vector2.ZERO,1.0/60)
	assert(neutral.scale==1 and neutral.rotation==Vector2.ZERO,"Neutral sticks do not pull camera")
	var friction=aa.controller_filter(weapon,Vector2.ZERO,Vector2(.5,0),1.0/60)
	assert(friction.scale<1 and friction.rotation==Vector2.ZERO,"Look input gets friction without centering snap")
	target.position.x+=.1
	var adhesion=aa.controller_filter(weapon,Vector2(1,0),Vector2.ZERO,1.0/60)
	assert(adhesion.rotation.length()>0 and adhesion.rotation.length()<=deg_to_rad(12)/60+.00001,"Active strafe tracks motion with angular speed cap")
	target.position.x+=.1
	assert(aa.controller_filter(weapon,Vector2.ZERO,Vector2.ZERO,1.0/60).rotation==Vector2.ZERO,"Releasing sticks stops tracking immediately")
	aa.friction=0;aa.adhesion=0;target.position.x+=.1
	var disabled=aa.controller_filter(weapon,Vector2.ONE,Vector2.ONE,1.0/60);assert(disabled.scale==1 and disabled.rotation==Vector2.ZERO,"Independent controller controls disable both layers")
	assert(preload("res://world/tree_on_foot.gd").deadzone(Vector2(.1,0))==Vector2.ZERO,"Stick drift ignored")
	# Exercise the actual on-foot input path with deterministic stick values.
	var foot_arena=FootArena.new();root.add_child(foot_arena);foot_arena.weapons=weapon;foot_arena.camera=arena.camera
	var foot=ControllerFoot.new();foot_arena.add_child(foot);foot.arena=foot_arena;foot.active=true;foot.set_process(false);foot.set_physics_process(false)
	foot.aim_device=0;foot.simulated_look=Vector2(.5,0);aa.friction=.4;aa.adhesion=0
	weapon.aim_state=weapon.aim_assist.solve(weapon);var yaw_before=foot.yaw;foot._process(1.0/60)
	assert(absf(foot.yaw-yaw_before)<.5*deg_to_rad(150)/60,"Actual controller look path applies friction")
	var mouse=InputEventMouseMotion.new();mouse.relative=Vector2(4,2);yaw_before=foot.yaw
	assert(foot.handle_input(mouse) and foot.aim_device==-1 and is_equal_approx(foot.yaw-yaw_before,-.01),"Mouse bypasses controller friction")
	arena.camera.transform=Transform3D.IDENTITY;foot.active=false
	var began=Time.get_ticks_usec()
	for iteration in 100: weapon.aim_assist.solve(weapon)
	print("AIM_FIXTURE_MEAN_USEC ",(Time.get_ticks_usec()-began)/100.0)
	# Spread is sampled after correction, can depart from it, and bloom recovers.
	weapon.selected=4;weapon.bloom[4]=1.0
	var direction=Vector3.FORWARD;var deviated=false
	for i in 20:
		var shot_direction=weapon.spread_direction(direction)
		assert(direction.angle_to(shot_direction)<=deg_to_rad(1.31),"Spread remains bounded")
		if direction.angle_to(shot_direction)>.001: deviated=true
	assert(deviated,"Spread must not be corrected back onto target")
	weapon._physics_process(.5);assert(weapon.bloom[4]<1,"Bloom recovers between shots")
	weapon.aim_state=weapon.aim_assist.solve(weapon);weapon._process(0);await shot("ce-plasma-reticle.png")
	arena.collision_debug.hud_hidden=true;weapon._process(0)
	assert(weapon.crosshair.visible and not weapon.ammo_label.visible,"Hidden information keeps reticle")
	await shot("controller-clean-reticle.png")
	arena.editor.opened=true;assert(not weapon.handle_input(event),"Editor retains its controls");weapon._physics_process(.1);assert(weapon.aim_state.is_empty());weapon._process(0);assert(not weapon.crosshair.visible,"Editor hides aim overlay")
	print("WEAPON_CE_AIM_PASS: nearest body, per-weapon range, fixed reticle, controller friction/adhesion gates, bounded post-correction spread, bloom recovery; blue/red reticle, off/partial/full assist, hitscan agreement, cone, dead target, wall occlusion, persisted keyboard settings, editor gate")
	quit()
func shot(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs/"+name)
