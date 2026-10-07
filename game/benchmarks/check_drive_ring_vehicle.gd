extends SceneTree
const Ring = preload("res://world/terrain_drive_ring.gd")
var scene: Node3D
var passed := true

func _initialize() -> void:
	create_timer(240).timeout.connect(func(): push_error("CURVED_VEHICLE_TIMEOUT");quit(1))
	run.call_deferred()

func require(condition: bool, message: String) -> void:
	if not condition:
		passed=false
		push_error(message)

func run() -> void:
	root.size=Vector2i(1280,800)
	scene=load("res://world/terrain_drive.tscn").instantiate();root.add_child(scene)
	while not scene.ready_to_play or not scene.loading.ready_to_enter: await process_frame
	scene.loading.close()
	var kit: Node=scene.vehicle_kit
	var stream: Node=scene.streamer
	var target := Vector2(20000,0)
	var target_world := Ring.point(target.x,scene.source.surface_height(target),target.y)
	kit.driving=false
	scene.camera.position=target_world+Ring.up_at(target_world)*60
	stream.plan()
	while not stream.ready_at(target_world): await process_frame
	require(await kit.place(target,-PI*.5),"Could not place the Warthog on curved collision")
	await create_timer(1).timeout
	var up := Ring.up_at(kit.car.position)
	require(kit.car.gravity_up.dot(up)>.999,"Warthog gravity is not radial")
	require(kit.car.global_basis.y.dot(up)>.98,"Warthog is not aligned to the curved surface")
	require(kit.car.grounded_count==4,"Warthog is not supported by all four wheels on the curved tile")
	var began := Ring.coordinates(kit.car.position).x
	kit.driving=true;kit.test_controls=true;kit.test_throttle=1;kit.test_brake=false
	await create_timer(8).timeout
	kit.test_throttle=0;kit.test_brake=true
	var ended := Ring.coordinates(kit.car.position).x
	require(absf(ended-began)>25,"Warthog did not drive on the curved terrain")
	require(kit.freeze_ticks==0 and kit.brake_ticks==0,"Curved route triggered terrain supply protection")
	print("DRIVE_RING_VEHICLE_PASS arc_start=",began," arc_end=",ended," grounded=",kit.car.grounded_count," up_dot=",kit.car.global_basis.y.dot(up))
	quit(0 if passed else 2)
