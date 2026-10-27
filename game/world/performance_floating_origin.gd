extends Node
## Shift at the start of a physics tick; leave ring coordinates and velocities intact.
const Ring=preload("res://world/terrain_drive_ring.gd")
const LIMIT=2048.0
var arena: Node3D
var enabled=true
var shifts=0
var last_shift_ms=0.0

func setup(owner_arena: Node3D):
	arena=owner_arena;process_physics_priority=-1000

func _physics_process(_delta: float):
	if not enabled or not arena.ready_to_play:return
	if arena.ring_landing.updating or arena.cloud_review.viewpoints.player_start.restoring:return
	if arena.vehicle_kit.relocating:return
	var focus: Vector3=arena.camera.global_position
	var viewing=arena.cloud_review.viewpoints.active or arena.editor.opened
	if arena.vehicle_kit.driving and not viewing:focus=arena.vehicle_kit.car.global_position
	elif arena.on_foot.active and not viewing:focus=arena.on_foot.global_position
	if focus.length()>LIMIT:rebase(focus)

func rebase(delta: Vector3):
	if delta.length_squared()<1.0:return
	var started=Time.get_ticks_usec()
	# Integer shifts keep the offset exact, including repeated travel around the ring.
	delta=delta.round()
	Ring.origin_x+=delta.x;Ring.origin_y+=delta.y;Ring.origin_z+=delta.z
	RenderingServer.global_shader_parameter_set("ring_origin_offset",Ring.offset())
	for child in arena.get_children():shift_nodes(child,delta)
	for child in arena.get_children():notify_shift(child,delta)
	shifts+=1
	last_shift_ms=(Time.get_ticks_usec()-started)/1000.0
	print("FLOATING_ORIGIN ",JSON.stringify({"shift":shifts,"offset":[Ring.origin_x,Ring.origin_y,Ring.origin_z],"duration_ms":last_shift_ms}))

func shift_nodes(node: Node, delta: Vector3):
	# Organizational Node3D containers stay at identity: their children and future
	# spawns share the local simulation frame. Model hierarchies move just once.
	if node is CanvasLayer or node is Control:return
	if node is Node3D and (node.has_meta("floating_origin_root") or node.transform!=Transform3D.IDENTITY or node is VisualInstance3D or node is PhysicsBody3D or node is Camera3D or node is AudioStreamPlayer3D):
		var velocity=Vector3.ZERO;var spin=Vector3.ZERO
		if node is RigidBody3D:velocity=node.linear_velocity;spin=node.angular_velocity
		# Keep untouched distant objects anchored in doubles across return trips.
		var anchor: Dictionary=node.get_meta("floating_origin_anchor",{})
		var current: Vector3=node.global_position
		if anchor.is_empty() or current!=anchor.local:
			anchor={"x":Ring.origin_x-delta.x+current.x,"y":Ring.origin_y-delta.y+current.y,"z":Ring.origin_z-delta.z+current.z}
		var local=Vector3(anchor.x-Ring.origin_x,anchor.y-Ring.origin_y,anchor.z-Ring.origin_z)
		node.global_position=local;anchor.local=local;node.set_meta("floating_origin_anchor",anchor)
		node.reset_physics_interpolation()
		if node is RigidBody3D:node.linear_velocity=velocity;node.angular_velocity=spin
		return
	for child in node.get_children():shift_nodes(child,delta)

func notify_shift(node: Node, delta: Vector3):
	if node.has_method("origin_shifted"):node.origin_shifted(delta)
	for child in node.get_children():notify_shift(child,delta)
