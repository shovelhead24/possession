extends SceneTree
const Grenade=preload("res://world/terrain_grenade.gd")

class Fixture extends Node3D:
	var player := CharacterBody3D.new()
	var cuts := 0
	func request_crater(_p: Vector3, _radius: float) -> bool:
		cuts+=1
		return true

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var lab := preload("res://benchmarks/destruction_profile.gd")
	assert(lab.crater_within_volume(Vector3(0,-19,0),2))
	assert(not lab.crater_within_volume(Vector3(0,-21,0),2))
	assert(not lab.crater_within_volume(Vector3(0,61,0),2))
	var fixture := Fixture.new();root.add_child(fixture);fixture.add_child(fixture.player)
	var floor_body := StaticBody3D.new();fixture.add_child(floor_body)
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(100,1,100)
	shape.shape=box;shape.position.y=-.5;floor_body.add_child(shape)
	await physics_frame
	await physics_frame
	var grenade := Grenade.new();grenade.arena=fixture;fixture.add_child(grenade)
	grenade.position=Vector3(0,1,0);grenade.velocity=Vector3(16,3,0)
	var first_position := Vector3.ZERO;var first_time := -1.0
	var settle_time := -1.0;var settle_position := Vector3.ZERO
	for frame in 180:
		await physics_frame
		if not is_instance_valid(grenade): break
		if grenade.impacts>0 and first_time<0: first_time=2-grenade.remaining;first_position=grenade.position
		if grenade.resting and settle_time<0: settle_time=2-grenade.remaining;settle_position=grenade.position
		if settle_time>=0 and grenade.position.distance_to(settle_position)>.001:
			push_error("Settled grenade moved");quit(1);return
	if fixture.cuts!=1 or first_time<0 or settle_time<0 or settle_time-first_time>.5 or settle_position.distance_to(first_position)>1.5:
		push_error("Grenade settling/fuse regression");quit(1);return
	print("PASS: grenade settled ",settle_time-first_time,"s after first impact, travelled ",settle_position.distance_to(first_position),"m after impact, stayed still and detonated once")
	quit()
