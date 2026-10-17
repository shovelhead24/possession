extends SceneTree
const Grenade=preload("res://world/terrain_grenade.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
class Car extends Node3D:
	var linear_velocity=Vector3.ZERO
	var top_speed=45.0
class Supply extends RefCounted:
	func ready_at(_point): return true
class Arena extends Node3D:
	var camera=Camera3D.new()
	var vehicle_kit={"driving":false,"car":Car.new()}
	var destruction: Node
	var streamer=Supply.new()
	var ready_to_play=false
	var tile_entries={}
	func throw_grenade(): pass
func _initialize(): run.call_deferred()
func run():
	var arena=Arena.new();root.add_child(arena);arena.add_child(arena.camera);arena.add_child(arena.vehicle_kit.car)
	arena.camera.position=Ring.point(100,10,220);arena.vehicle_kit.car.position=arena.camera.position
	for z in range(-10,11):
		for x in range(-10,11): arena.tile_entries[Vector2i(x,z)]={}
	var d=preload("res://world/terrain_drive_destruction.gd").new();d.arena=arena;arena.destruction=d;arena.add_child(d)
	var cases=0
	for speed in [0.0,45.0,80.0]:
		arena.vehicle_kit.driving=speed>0;arena.vehicle_kit.car.linear_velocity=Ring.spinward_at(arena.camera.position)*speed
		var keys=d.nearby_preparation_keys()
		for pitch in [-90.0,-45.0,0.0,45.0,90.0]:
			for yaw in range(0,360,45):
				var up=Ring.up_at(arena.camera.position)
				var forward=(Ring.spinward_at(arena.camera.position)*cos(deg_to_rad(pitch))+up*sin(deg_to_rad(pitch))).rotated(up,deg_to_rad(yaw))
				var pos=arena.camera.position+forward*.5+up*2.2
				var velocity=forward*Grenade.THROW_SPEED+up*Grenade.LIFT_SPEED+arena.vehicle_kit.car.linear_velocity
				for frame in 120:
					velocity-=Ring.up_at(pos)*Grenade.GRAVITY/60;pos+=velocity/60
					var cut=preload("res://world/sdf_recipe.gd").feature("carve",Ring.coordinates(pos+Ring.up_at(pos)*.8));cut.radius=Grenade.CRATER_RADIUS
					for key in d.keys_for([cut]): assert(key in keys,"Throw or crater footprint outside prepared area")
				cases+=1
	d.warming=true
	assert(d.busy() and not d.editing() and not d.unsaved(),"Preparation masquerades as a terrain edit")
	var aliens=preload("res://world/aliens/manager.gd").new();aliens.arena=arena
	assert(aliens.resident(arena.camera.position),"Preparation pauses aliens")
	d.pending.append({"kind":"carve"});assert(d.editing() and not aliens.resident(arena.camera.position));d.pending.clear();d.warming=false
	aliens.free()
	print("PASS ",cases," complete trajectories and crater bounds (0/45/80 m/s), preparation does not mark terrain dirty or pause aliens")
	quit()
