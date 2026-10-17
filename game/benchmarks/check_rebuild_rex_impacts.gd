extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
class Shooter extends Node:
	var elite=false
	func friendly_rids() -> Array[RID]: return []
class Flag extends RefCounted:
	var opened=false
	var dismissed=true
	var hud_hidden=false
	func log_event(message): print(message)
class Streamer extends RefCounted:
	var available=true
	func ready_at(_p): return available
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
	var last_toss=Vector3.ZERO
	func toss_from_trex(impulse, _source): last_toss=impulse;velocity=impulse
	func activate_at(p): global_position=p;active=true
class Kit extends RefCounted:
	var car: RigidBody3D
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
var output="C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs"
func _initialize():
	create_timer(180).timeout.connect(func(): push_error("Alien test timeout");quit(1))
	run.call_deferred()
func screenshot(name):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name))
func run():
	var arena=Arena.new();root.add_child(arena)
	arena.add_child(arena.painted_trees)
	arena.on_foot=Foot.new();arena.add_child(arena.on_foot);arena.on_foot.position=Vector3(0,0,38);arena.on_foot.collision_layer=2
	var capsule=CollisionShape3D.new();capsule.shape=CapsuleShape3D.new();capsule.shape.height=1.8;capsule.shape.radius=.35;capsule.position.y=.9;arena.on_foot.add_child(capsule)
	arena.vehicle_kit.car=preload("res://world/wishbone_vehicle.gd").new();arena.add_child(arena.vehicle_kit.car);arena.vehicle_kit.car.position=Vector3(0,0,200);arena.vehicle_kit.car.freeze=true;arena.vehicle_kit.car.set_physics_process(false)
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
	manager.garrisons.resize(1);manager.garrisons[0].home=Vector3.ZERO;manager.stream_squads()
	assert(manager.enemies.size()==5,"Five members must spawn")
	var squad=manager.squads[0];squad.set_physics_process(false)
	for unit in manager.enemies:
		unit.set_physics_process(false)
		var height=1.95 if unit.elite else 1.3
		unit.set_capsule(height,false)
		var changes=unit.capsule_changes
		for tick in 30: unit.set_capsule(height,false)
		assert(unit.capsule_changes==changes,"Unchanged stance does not rebuild capsule")
		unit.set_capsule(height,true);assert(unit.shape.rotation.x>1.5)
		unit.set_capsule(height,false);assert(unit.shape.rotation==Vector3.ZERO and is_equal_approx(unit.shape.position.y,height*.5))
		assert(unit.lizard.find_children("*","MeshInstance3D",true,false).size()==2,"Body plus batched rifle")
		assert(unit.lizard.weapons.size()==1 and unit.lizard.weapons[0].mesh.get_surface_count()==3,"Three preserved rifle materials")
		var weapon_triangles=0
		for surface in unit.lizard.weapons[0].mesh.get_surface_count():
			var arrays=unit.lizard.weapons[0].mesh.surface_get_arrays(surface)
			weapon_triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
			assert(arrays[Mesh.ARRAY_BONES].size()>0 and arrays[Mesh.ARRAY_WEIGHTS].size()>0)
		assert(weapon_triangles==756,"All rifle triangles retained")
		unit.lizard.update_shadow(unit.position+Vector3(0,0,80));assert(not unit.lizard.shadow_enabled)
		unit.lizard.update_shadow(unit.position+Vector3(0,0,20));assert(unit.lizard.shadow_enabled)
		assert(unit.lizard.body_mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		assert(unit.lizard.clips.size()==14,"14 restored clips")
		assert(unit.lizard.skeleton.global_basis.get_scale().is_equal_approx(Vector3.ONE),"Unit skeleton scale")
	# Build the bounded local grid; editing terrain invalidates stale paths.
	for i in 300: manager.navigation.step()
	assert(manager.navigation.grids[0].next==1089)
	assert(manager.navigation.path(Vector3(-12,0,0),Vector3(12,0,0)).size()>3)
	arena.destruction.applied_revision+=1;manager.navigation.step()
	assert(manager.navigation.grids[0].next<=12)
	arena.editor.opened=true
	arena.camera.position=Vector3(0,4,200);manager.render_clock=0;manager._process(.3)
	assert(not squad.captain.lizard.shadow_enabled,"Editor camera updates caster distance while gameplay pauses")
	arena.camera.position=Vector3(0,4,14);manager.render_clock=0;manager._process(.3)
	assert(squad.captain.lizard.shadow_enabled)
	arena.editor.opened=false
	var captain=squad.captain;assert(captain.health==175 and squad.members[1].health==50)
	squad.report_contact(Vector3(0,0,30));assert(squad.mode==squad.Mode.COMBAT)
	squad.advance_memory(2.1,false);assert(squad.mode==squad.Mode.HOLD)
	squad.advance_memory(28,false);assert(squad.mode==squad.Mode.HUNT)
	squad.advance_memory(270,false);assert(squad.mode==squad.Mode.PATROL)
	for unit in squad.members: unit.face(arena.on_foot.position-unit.position,1)
	await physics_frame;await physics_frame
	assert(captain.sees_player(),"Front target visible")
	arena.on_foot.position.z=-35;captain.sight_timer=0
	await physics_frame;await physics_frame
	assert(not captain.sees_player(),"Rear target outside FOV")
	await screenshot("tactical-aliens-lineup.png")
	assert(captain.begin_dive(captain.position+Vector3.RIGHT*3),"Captain dive")
	captain.dive_time=0
	arena.on_foot.position=Vector3(0,0,38)
	# Enemy bolts must travel before damaging the player.
	await physics_frame;await physics_frame
	manager.bolts.set_physics_process(false)
	var start=arena.on_foot.position+Vector3(0,1,-12)
	assert(manager.fire_bolt(captain,start,Vector3.BACK,12,Color.RED))
	manager.bolts.set_physics_process(false);manager.bolts._physics_process(.1);assert(manager.health==100)
	manager.bolts._physics_process(.3);assert(manager.health==88,"Swept hostile projectile contact")
	var wall=StaticBody3D.new();wall.collision_layer=2;arena.add_child(wall);wall.position=Vector3(0,1,32)
	var ws=CollisionShape3D.new();ws.shape=BoxShape3D.new();ws.shape.size=Vector3(3,3,.5);wall.add_child(ws)
	await physics_frame;await physics_frame
	assert(manager.fire_bolt(captain,start,Vector3.BACK,12,Color.RED));manager.bolts.set_physics_process(false);manager.bolts._physics_process(.5)
	assert(manager.health==88 and manager.bolts.bolts.is_empty(),"Wall blocks plasma")
	wall.free()

	arena.editor.opened=true;manager.hurt(10);assert(manager.health==88);arena.editor.opened=false
	squad.report_contact(arena.on_foot.position)
	captain.take_hit(200,arena.on_foot.position,captain.position)
	assert(captain.dead and squad.members[1].routed and squad.members[1].gait=="Flee")
	await physics_frame;await physics_frame
	assert(captain.lizard.ragdoll.get_child_count()==19,"19 physical bones")
	for unit in squad.members:
		if not unit.dead: unit.take_hit(500,arena.on_foot.position,unit.position)
	var active=0
	for unit in squad.members:
		if is_instance_valid(unit.lizard.ragdoll): active+=1
	assert(active<=3,"Bounded active ragdolls")
	await create_timer(1).timeout
	await screenshot("tactical-aliens-ragdolls.png")
	for unit in squad.members: unit.lizard.settle_ragdoll()
	await physics_frame;await physics_frame
	for unit in squad.members: assert(not is_instance_valid(unit.lizard.ragdoll))
	await screenshot("tactical-aliens-settled.png")
	# Retiring a cleared encounter cannot resurrect any casualties.
	arena.camera.position=Vector3(0,5,500);manager.stream_squads()
	assert(manager.enemies.is_empty() and manager.squads.is_empty())
	await process_frame
	arena.camera.position=Vector3(0,4,14);manager.stream_squads()
	assert(manager.enemies.is_empty())
	# Reloading a captain casualty preserves routing among the remaining grunts.
	manager.reset();manager.garrisons.resize(1);manager.garrisons[0].home=Vector3.ZERO;manager.stream_squads()
	squad=manager.squads[0];squad.set_physics_process(false)
	for unit in squad.members: unit.set_physics_process(false)
	squad.captain.take_hit(200,Vector3(0,0,30),Vector3.ZERO)
	arena.camera.position=Vector3(0,5,500);manager.stream_squads()
	await process_frame
	arena.camera.position=Vector3(0,4,14);manager.stream_squads()
	assert(manager.enemies.size()==4)
	squad=manager.squads[0];squad.set_physics_process(false);squad.report_contact(Vector3(0,0,30));squad.issue_orders()
	for unit in squad.members: unit.set_physics_process(false);assert(unit.routed)
	# A resting frag waits two seconds, damages nearby exposed targets and respects cover.
	for i in squad.members.size(): squad.members[i].position=Vector3(-15-i*10,0,0)
	var exposed=squad.members[0];exposed.position=Vector3(-10,0,0)
	var shielded=squad.members[1];shielded.position=Vector3(-15,0,0)
	wall=StaticBody3D.new();wall.collision_layer=2;arena.add_child(wall);wall.position=Vector3(-12.5,1,0)
	ws=CollisionShape3D.new();ws.shape=BoxShape3D.new();ws.shape.size=Vector3(.5,3,8);wall.add_child(ws)
	var grenade=preload("res://world/aliens/frag.gd").new();grenade.manager=manager;grenade.position=Vector3(-10,.15,2);manager.add_child(grenade);grenade.freeze=true;grenade.stopped=true;grenade.set_physics_process(false)
	await physics_frame;await physics_frame
	grenade._physics_process(1.99);assert(not grenade.is_queued_for_deletion() and not exposed.dead)
	grenade._physics_process(.02);assert(grenade.is_queued_for_deletion() and exposed.dead and shielded.health==50)
	manager.hurt(200);assert(manager.defeated)
	manager._physics_process(3.1);assert(not manager.defeated and manager.health==100)

	wall.free()
	manager.reset();manager.garrisons.resize(1);manager.garrisons[0].home=Vector3.ZERO;manager.stream_squads()
	squad=manager.squads[0];squad.set_physics_process(false)
	for unit in squad.members: unit.set_physics_process(false)
	captain=squad.captain
	var car=arena.vehicle_kit.car
	# Stronger defaults kill grunts at modest speeds and lift surviving captains.
	captain.vehicle_impact(car,captain.position,Vector3(0,0,3),Vector3.FORWARD)
	assert(captain.health==115 and captain.velocity.y>=6.75,"New defaults: accessible low-speed damage and lift")
	captain.health=175;captain.impact_ready_at=0
	car.impact_min_speed=3;car.impact_damage=12;car.impact_forward=1.1;car.impact_lift=1
	# Original tuning remains selectable.
	captain.vehicle_impact(car,captain.position,Vector3(0,0,2),Vector3.FORWARD)
	assert(captain.health==175,"Gentle nudge harmless")
	captain.vehicle_impact(car,captain.position,Vector3(12,0,0),Vector3.FORWARD)
	assert(captain.health==175,"Sideways graze harmless")
	captain.vehicle_impact(car,captain.position,Vector3(0,0,8),Vector3.FORWARD)
	assert(captain.health==115 and captain.velocity.y>=4.5,"Moderate hit hurts and punts upward")
	captain.vehicle_impact(car,captain.position,Vector3(0,0,8),Vector3.FORWARD)
	assert(captain.health==115,"Resting/multi-point contact cannot double damage")
	captain.impact_ready_at=0
	captain.vehicle_impact(car,captain.position,Vector3(0,0,20),Vector3.FORWARD)
	assert(captain.dead and captain.velocity.y==8 and is_instance_valid(captain.lizard.ragdoll),"Fatal impact launches ragdoll")
	# Use the real vehicle force-integration callback against a live physics capsule.
	var victim=squad.members[1];victim.position=Vector3(0,0,0)
	for unit in squad.members:
		if unit!=victim: unit.position.x+=40
	car.position=Vector3(0,0,-5);car.gravity_scale=0;car.collision_layer=2;car.collision_mask=2
	assert(car.max_contacts_reported>=8,"Vehicle enables impact contacts without scene-specific setup")
	var chassis=CollisionShape3D.new();chassis.shape=BoxShape3D.new();chassis.shape.size=Vector3(2,.76,4.4);chassis.position.y=.85;car.add_child(chassis)
	car.freeze=false;car.linear_velocity=Vector3(0,0,12)
	for tick in 50:
		await physics_frame
		if victim.dead: break
	assert(victim.dead and victim.velocity.y>4.5,"Real chassis collision must deliver upward punt")
	car.freeze=true;car.position=Vector3(0,0,200)
	var pelvis=victim.lizard.ragdoll.get_node("Physics_Pelvis")
	var launch_height=pelvis.global_position.y
	assert(pelvis.linear_velocity.y>4.5,"Fatal vehicle punt preserves upward ragdoll velocity")
	for tick in 12: await physics_frame
	assert(pelvis.global_position.y>launch_height+.3,"Visible airborne ragdoll rise")
	await screenshot("warthog-punt.png")
	print("COLLISION_PUNT_PASS: low-speed, graze, moderate, cooldown, lethal ragdoll and real chassis contact")
	# Restore one source Rex, including original scale, walking excerpt and foot solver.
	manager.reset();manager.stream_enabled=false
	var p=Ring.point(100000,0,0);var up=Ring.up_at(p);var tangent=Ring.tangent_basis(p,0)
	floor_body.global_transform=Transform3D(tangent*Basis(Vector3.FORWARD,.35),p-up*.5)
	arena.camera.position=p+tangent*Vector3(28,18,30);arena.camera.look_at(p+up*6,up)
	arena.on_foot.position=p+tangent*Vector3(0,0,100)
	await physics_frame;await physics_frame
	var rex=preload("res://world/aliens/trex.gd").new();rex.arena=arena;rex.manager=manager;rex.patrol=[p,p+tangent*Vector3(0,0,30)]
	manager.add_child(rex);manager.trex=rex;rex.set_physics_process(false);rex.set_process(false);rex.runtime_active=true
	assert(rex.animator.has_animation(rex.WALK_CLIP) and rex.sounds.bank.size()==7)
	await physics_frame;await physics_frame
	var shooter=Shooter.new();arena.add_child(shooter)
	manager.bolts.launch(shooter,rex.to_global(Vector3(0,2.6,9)),-rex.global_basis.z,12,Color.GREEN)
	manager.bolts.set_physics_process(false);manager.bolts._physics_process(.5)
	assert(rex.health==3988,"Alien plasma damages Rex")
	shooter.free()
	var frag=preload("res://world/aliens/frag.gd").new();frag.manager=manager;frag.position=rex.to_global(Vector3(0,.3,4));manager.add_child(frag);frag.freeze=true
	await physics_frame;await physics_frame
	frag.detonate();assert(rex.health<3988,"Frag damage reaches Rex")
	var solver=rex.grounding;var worst=0.0
	for frame in range(0,100,5):
		rex.skeleton.reset_bone_poses();rex.animator.seek(frame/30.0,true);solver._process_modification()
		for side in 2:
			worst=maxf(worst,solver.last_feet[side].distance_to(solver.last_targets[side]))
	assert(worst<.15,"Original foot solver must fit a hill on rotated ring: %f" % worst)
	assert(solver.ground_up.dot(up)>.8)
	var before=rex.position
	for tick in 60: rex.move_walk(tangent.z,1.0/60)
	assert(rex.position.distance_to(before)>7,"Rex walks across hills")
	arena.camera.position=rex.position+tangent*Vector3(50,24,60);arena.camera.look_at(rex.position+up*5,up)
	await screenshot("rex-hill-restored.png")
	for attack in 4:
		manager.health=100;manager.defeated=false;arena.on_foot.last_toss=Vector3.ZERO
		rex.bite_time=0;rex.attack_recovery=0;rex.behavior_mode=3
		rex.begin_bite(arena.on_foot)
		assert(rex.attack_kind==attack)
		for frame in (245 if attack==3 else 75):
			rex.skeleton.reset_bone_poses();rex.animator.seek(1.6,true)
			rex.step_behavior(1.0/60);solver._process_modification()
			if rex.bite_grabbed: assert((arena.on_foot.global_position+rex.grip_offset).distance_to(rex.mouth_point())<.01)
		assert(not arena.on_foot.has_meta("trex_held"),"Attack restores player controls")
		if attack==0: assert(arena.on_foot.last_toss.dot(up)>13)
		elif attack in [1,2]: assert(arena.on_foot.last_toss.slide(up).length()>15)
		else: assert(rex.stomp_applied and rex.consumed and manager.defeated)
	# Execute the real gated physics entry point: do not bypass it with step_behavior.
	manager.defeated=false;manager.health=100;rex.begin_bite(arena.on_foot)
	arena.streamer.available=false;arena.camera.position=rex.position+Vector3(1000,0,0)
	for tick in 110: rex._physics_process(1.0/60)
	assert(not arena.on_foot.has_meta("trex_held") and rex.bite_time<=0 and rex.attack_recovery<=0,"Held attack finishes despite missing terrain and distant camera")
	rex._physics_process(1.0/60);assert(not rex.runtime_active,"Unloaded/distant patrol remains suspended after release")
	arena.streamer.available=true;arena.camera.position=rex.position+Vector3(20,10,30)
	manager.defeated=false;manager.health=100;rex.begin_bite(arena.on_foot)
	manager.reset();assert(not arena.on_foot.has_meta("trex_held"),"F7 frees held victim")
	print("REX_RESTORE_PASS: source clips/audio, rotated-ring hill foot error=",worst,"; walking, four attacks, grip and reset cleanup")
	print("TACTICAL_ALIENS_PASS: clips, scale, squad memory, FOV, projectile contact, pause gate, dive, captain morale, ragdoll cap, navigation invalidation, obstruction, streaming casualties, grenade fuse and cover, respawn")
	arena.free();quit()
