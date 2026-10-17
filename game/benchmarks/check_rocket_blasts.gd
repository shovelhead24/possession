extends "res://benchmarks/check_drive_grenades.gd"
const Rocket=preload("res://world/explosive_rocket.gd")
class Foot extends Node3D:
	var active=false
class Target extends StaticBody3D:
	var health=500.0
	func take_hit(amount, _origin, _point): health-=amount
	func _ready():
		collision_layer=2
		var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3.ONE;shape.shape=box;add_child(shape)
class BlastArena extends Fixture:
	var aliens: Node
	var loading={"dismissed":true}
	var editor={"opened":false}
	var vehicle_kit={"menu":{"opened":false},"driving":false}
	var on_foot=Foot.new()
class Weapon extends Node:
	var arena: Node3D
	var last_hit={}
	var notice=""
	var notice_time=0.0
	func trace_segment(start: Vector3, end: Vector3) -> Dictionary:
		return arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,7))
func run() -> void:
	# Compile the complete six-weapon path as well as exercising live projectiles.
	var weapons=load("res://world/rebuild_weapons.gd").new();weapons.free()
	var arena=BlastArena.new();root.add_child(arena);arena.add_child(arena.on_foot)
	arena.source=Source.new();arena.source.curve_to_ring=true;assert(arena.source.initialize())
	arena.streamer=Stream.new();arena.streamer.arena=arena
	arena.destruction=Destruction.new();arena.destruction.arena=arena;arena.add_child(arena.destruction)
	install(arena,Vector2i.ZERO,arena.source.build_tile(Vector2i.ZERO))
	arena.aliens=preload("res://world/aliens/manager.gd").new();arena.aliens.arena=arena;arena.aliens.initialized=true
	arena.add_child(arena.aliens);arena.aliens.set_physics_process(false);arena.aliens.set_process(false)
	var weapon=Weapon.new();weapon.arena=arena;arena.add_child(weapon)
	await physics_frame;await physics_frame
	var ground=probe(arena,100,100);assert(not ground.is_empty())
	var up=Ring.up_at(ground.position)
	var exposed=Target.new();arena.add_child(exposed);exposed.global_position=ground.position-Vector3.RIGHT*3+up
	var shielded=Target.new();arena.add_child(shielded);shielded.global_position=ground.position-Vector3.RIGHT*7+up
	arena.aliens.enemies=[exposed,shielded]
	var cover=StaticBody3D.new();var cover_shape=CollisionShape3D.new();var cover_box=BoxShape3D.new();cover_box.size=Vector3(.2,10,10);cover_shape.shape=cover_box;cover.add_child(cover_shape);arena.add_child(cover);cover.global_position=ground.position-Vector3.RIGHT*5+up
	var crate=preload("res://world/heavy_crate.gd").new();crate.arena=arena;arena.add_child(crate)
	crate.global_position=ground.position+up*4+Vector3.RIGHT*2;crate.linear_velocity=Vector3.RIGHT
	var start=crate.global_position
	var active_frames=0;var moving_frames=0;var blasts=0;var prior_blast=0.0
	for frame in 240:
		if frame in [0,3,6]:
			var rocket=Rocket.new();rocket.weapon=weapon;rocket.velocity=-up*Rocket.SPEED
			rocket.origin=ground.position+up*2;arena.add_child(rocket);rocket.global_position=rocket.origin
		await physics_frame
		assert(not crate.freeze and not crate.suspended,"Crate froze during chained terrain edits")
		if arena.destruction.editing():
			active_frames+=1
			if crate.linear_velocity.length()>.1: moving_frames+=1
		if crate.last_blast!=prior_blast and crate.last_blast>0: blasts+=1;prior_blast=crate.last_blast
		if arena.destruction.completed==3 and frame>60: break
	assert(arena.destruction.completed==3,"Chained rockets did not produce three craters")
	assert(active_frames>0 and moving_frames==active_frames,"Crate motion stopped during edits")
	assert(blasts>=2,"Chained blast impulses were dropped")
	assert(exposed.health<500 and shielded.health==500,"Blast damage or wall shielding failed")
	assert(crate.global_position.distance_to(start)>.1)
	assert(not probe(arena,100,100).is_empty(),"Collision floor disappeared")
	arena.streamer.force_starvation=true
	await physics_frame;await physics_frame
	assert(crate.freeze and crate.suspended,"Missing terrain must still suspend bodies")
	arena.streamer.force_starvation=false
	await physics_frame;await physics_frame
	assert(not crate.freeze and not crate.suspended)
	# A camera-to-muzzle obstruction must detonate before the launch position.
	var wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(10,.1,10);shape.shape=box;wall.add_child(shape);arena.add_child(wall)
	wall.global_position=ground.position+up*12
	await physics_frame;await physics_frame
	var blocked=Rocket.new();blocked.weapon=weapon;blocked.velocity=-up*Rocket.SPEED;blocked.origin=ground.position+up*14;arena.add_child(blocked);blocked.global_position=ground.position+up*10
	await physics_frame;await physics_frame
	assert(not is_instance_valid(blocked) or blocked.detonated,"Rocket crossed near-muzzle wall")
	assert(weapon.last_hit.collider==wall)
	print("PASS chained impact rockets: three craters, ",blasts," crate impulses, ",moving_frames," moving edit frames, no freezes; blast damage, wall shielding, streaming suspension and near-muzzle collision retained")
	var stream=arena.streamer;arena.free();stream.free();quit()
