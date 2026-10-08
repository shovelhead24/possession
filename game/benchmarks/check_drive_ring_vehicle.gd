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
	require(kit.car.global_basis.determinant()>.999,"Warthog placement still mirrors its model")
	var left := up.cross(-kit.car.global_basis.z).normalized()
	require((kit.driver_model.global_position-kit.car.global_position).dot(left)>.4,"Driver is on the wrong side")
	# Exercise the actual suspension hubs, not just an isolated rotation matrix.
	kit.driving=true;kit.test_controls=true;kit.test_throttle=0;kit.test_brake=true
	for turn in [-.6,.6]:
		kit.test_steer=turn
		await create_timer(.6).timeout
		var body_up: Vector3=kit.car.global_basis.y.normalized()
		for corner in kit.car.corners:
			var physical_forward: Vector3=-kit.car.global_basis.z
			if corner.front: physical_forward=physical_forward.rotated(body_up,kit.car.steering)
			var visual_forward: Vector3=-corner.hub.global_basis.z
			require(visual_forward.slide(body_up).normalized().dot(physical_forward.slide(body_up).normalized())>.995,"Visible wheel steering disagrees with tyre forces")
	kit.test_steer=0
	await create_timer(.4).timeout
	var began := Ring.coordinates(kit.car.position).x
	kit.driving=true;kit.test_controls=true;kit.test_throttle=1;kit.test_brake=false
	await create_timer(8).timeout
	kit.test_throttle=0;kit.test_brake=true
	var ended := Ring.coordinates(kit.car.position).x
	require(absf(ended-began)>25,"Warthog did not drive on the curved terrain")
	require(kit.freeze_ticks==0 and kit.brake_ticks==0,"Curved route triggered terrain supply protection")
	await create_timer(1).timeout
	var heading_before := Ring.tangent_yaw(kit.car.position,-kit.car.global_basis.z)
	var recover := InputEventKey.new();recover.keycode=KEY_R;recover.pressed=true
	scene._input(recover)
	while kit.relocating: await physics_frame
	var heading_after := Ring.tangent_yaw(kit.car.position,-kit.car.global_basis.z)
	require(absf(angle_difference(heading_before,heading_after))<.01,"R recovery reversed the heading")
	if OS.get_cmdline_user_args().has("--vehicle-visual-check"):
		kit.driving=false;kit.test_steer=.6
		# Steering already verified above; frame the cabin from the driver's side.
		var pose: Transform3D=kit.car.global_transform
		scene.camera.position=pose*Vector3(-6,4,-7)
		scene.camera.look_at(pose*Vector3(0,1,0),Ring.up_at(pose.origin))
		await process_frame;await RenderingServer.frame_post_draw
		var output := "C:/Users/Bran the builder/Documents/Codex/2026-10-07/co/outputs/warthog-orientation-fixed.png"
		require(root.get_texture().get_image().save_png(output)==OK,"Could not save visual check")
	print("DRIVE_RING_VEHICLE_PASS arc_start=",began," arc_end=",ended," grounded=",kit.car.grounded_count," up_dot=",kit.car.global_basis.y.dot(up))
	quit(0 if passed else 2)
