extends "res://benchmarks/check_rebuild_rex_impacts.gd"
class PerfArena extends Arena:
	func performance_features() -> bool: return true
	func request_crater(_point: Vector3,_radius: float) -> bool: return true
func run():
	var arena=PerfArena.new();root.add_child(arena);arena.add_child(arena.painted_trees)
	arena.camera=Camera3D.new();arena.add_child(arena.camera)
	arena.on_foot=Foot.new();arena.on_foot.active=false;arena.add_child(arena.on_foot)
	arena.vehicle_kit.car=RigidBody3D.new();arena.add_child(arena.vehicle_kit.car);arena.vehicle_kit.car.freeze=true
	arena.aliens=preload("res://world/aliens/manager.gd").new();arena.aliens.arena=arena;arena.aliens.initialized=true;arena.add_child(arena.aliens);arena.aliens.set_physics_process(false)
	var rex=preload("res://world/aliens/trex.gd").new();rex.arena=arena;rex.manager=arena.aliens;arena.add_child(rex);rex.set_physics_process(false);rex.position=Vector3.ZERO;rex.global_basis=Basis.IDENTITY;rex.runtime_active=true;rex.screen_size_animation=true
	arena.camera.position=Vector3(50,20,35);arena.camera.look_at(Vector3(0,12,0));arena.camera.current=true
	var regions=preload("res://world/performance_rex_regions.gd").new();rex.add_child(regions);regions.setup(rex)
	var weapon=preload("res://world/rebuild_weapons.gd").new();weapon.arena=arena;arena.add_child(weapon);weapon.set_process(false);weapon.set_physics_process(false)
	for i in 5: await process_frame
	rex.set_process(false)
	await physics_frame;await physics_frame
	var head: Vector3=regions.regions[2].area.global_position
	var origin=head+Vector3(20,0,0)
	var hit=weapon.trace_segment(origin,head)
	assert(not hit.is_empty() and hit.collider is Area3D,"Head must be hit")
	var health=rex.health;weapon.apply_hit(hit,25,origin);assert(rex.health==health-25)
	var ray=PhysicsRayQueryParameters3D.create(origin,head,7)
	assert(arena.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Damage region must not be solid scenery")
	var rocket=preload("res://world/explosive_rocket.gd").new();rocket.weapon=weapon;rocket.origin=origin;arena.add_child(rocket);rocket.global_position=hit.position
	health=rex.health;rocket.detonate(hit);assert(rex.health==health-220,"Direct head rocket must damage exactly once")
	var wall=StaticBody3D.new();wall.collision_layer=1;arena.add_child(wall);wall.global_position=(head+origin)*.5
	var collision=CollisionShape3D.new();collision.shape=BoxShape3D.new();collision.shape.size=Vector3(1,10,10);wall.add_child(collision)
	await physics_frame;await physics_frame
	assert(weapon.trace_segment(origin,head).collider==wall,"Wall must still shield the head")
	print("PASS animated Rex head hits, bullet damage, direct rocket damage once, nonsolid regions and wall shielding")
	arena.free();quit()
