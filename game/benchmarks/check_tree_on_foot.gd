extends SceneTree
const Foot = preload("res://world/tree_on_foot.gd")
const Ring = preload("res://world/terrain_drive_ring.gd")
class Gate extends RefCounted:
	var ready := true
	func ready_at(_p: Vector3) -> bool: return ready
class PanelState extends RefCounted:
	var opened := false
class Loading extends RefCounted:
	var dismissed := true
class Car extends RigidBody3D:
	var controlled := false
	func set_controls(_t: float,_s: float,_b: bool) -> void: pass
class Kit extends RefCounted:
	var car: Car
	var driving := true
	var driver_model: Node3D
	var driver_look := Vector2.ZERO
	var menu := PanelState.new()
	func update_camera(_delta: float) -> void: pass
class Arena extends Node3D:
	var ready_to_play := true
	var streamer := Gate.new()
	var editor := PanelState.new()
	var loading := Loading.new()
	var vehicle_kit := Kit.new()
	var camera: Camera3D
func box(parent: Node, size: Vector3, point: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new();body.collision_layer=layer
	var shape := CollisionShape3D.new();var mesh := BoxShape3D.new();mesh.size=size;shape.shape=mesh;body.add_child(shape);parent.add_child(body);body.position=point;return body
func _initialize() -> void:
	create_timer(25).timeout.connect(func(): push_error("On-foot timeout");quit(1))
	run.call_deferred()
func run() -> void:
	var arena := Arena.new();root.add_child(arena)
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.position=Vector3(0,3,6)
	var floor_body := box(arena,Vector3(80,1,80),Vector3(0,-.5,0),1)
	var car := Car.new();car.freeze=true;car.collision_layer=2;arena.add_child(car);car.position=Vector3(0,.6,0);arena.vehicle_kit.car=car
	var car_shape := CollisionShape3D.new();var cs := BoxShape3D.new();cs.size=Vector3(2,1,4);car_shape.shape=cs;car.add_child(car_shape)
	var player := Foot.new();arena.add_child(player);player.setup(arena);player.test_controls=true
	await physics_frame;await physics_frame
	assert(player.exit_vehicle() and player.active and not arena.vehicle_kit.driving)
	for i in 20: await physics_frame
	assert(player.is_on_floor())
	var start: Vector3=player.position;player.test_move=Vector2(0,-1)
	for i in 30: await physics_frame
	var walk_distance := player.position.distance_to(start);assert(walk_distance>2.0 and walk_distance<3.0)
	player.test_move=Vector2.ZERO;player.jump_queued=true
	for i in 12: await physics_frame
	assert(player.position.y>.6)
	for i in 50: await physics_frame
	assert(player.is_on_floor())
	start=player.position;arena.editor.opened=true;player.test_move=Vector2(1,0)
	for i in 10: await physics_frame
	assert(player.position.distance_to(start)<.001)
	arena.editor.opened=false;arena.streamer.ready=false
	for i in 10: await physics_frame
	assert(player.position.distance_to(start)<.001)
	arena.streamer.ready=true;player.test_move=Vector2.ZERO
	player.activate_at(Vector3(3.2,.06,0));await physics_frame;assert(player.enter_vehicle())
	assert(not player.active and arena.vehicle_kit.driving and player.collision_layer==0)
	var blocker := box(arena,Vector3(20,5,20),Vector3(0,2.5,0),2)
	await physics_frame;await physics_frame;assert(not player.exit_vehicle() and arena.vehicle_kit.driving)
	blocker.queue_free();await physics_frame;await physics_frame
	# Collision and gravity use the local ring-up direction away from the origin.
	var p := Ring.point(100000,0,0);var up := Ring.up_at(p)
	floor_body.global_transform=Transform3D(Ring.tangent_basis(p,0),p-up*.5)
	car.position=p+up*.6;player.activate_at(p+up*.06)
	for i in 20: await physics_frame
	assert(player.is_on_floor() and player.up_direction.dot(up)>.999)
	print("ON_FOOT_PASS: legacy walking/jump, safe exit/entry, obstruction, editor and streaming gates, ring gravity; walk_m=",walk_distance)
	arena.free();quit()
