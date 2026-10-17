extends SceneTree
const Car=preload("res://world/wishbone_vehicle.gd")
const Parts=preload("res://world/forge_parts.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
func _initialize() -> void:
	create_timer(15).timeout.connect(func(): quit(1))
	run.call_deferred()
func run() -> void:
	var world := Node3D.new();root.add_child(world)
	var car := Car.new();world.add_child(car);car.set_physics_process(false);car.trace_suspension=true
	for x in [-.35,.35]:
		for z in [-.6,.6]:
			var hub := Node3D.new();car.add_child(hub);var spin := Node3D.new();hub.add_child(spin)
			car.corners.append({"anchor":Vector3(x,0,z),"side":signf(x),"radius":.4,"travel":0.0,"spin":spin,"hub":hub,"front":z<0,"links":[],"compression":0.0})
	var results := []
	for kind in ["floor_large","ramp"]:
		var part := Parts.get_part(kind);var body := StaticBody3D.new();body.collision_layer=2;world.add_child(body)
		for piece in part.pieces:
			var shape := CollisionShape3D.new();shape.shape=piece.shape;shape.transform=piece.pose;body.add_child(shape)
		var pose := Transform3D(Ring.tangent_basis(Ring.point(100000,10,0),0),Ring.point(100000,10,0));body.transform=pose
		# Align to the true slope, leaving tyre bottoms just above its surface.
		var slope := Basis(Vector3.RIGHT,atan(.5)) if kind=="ramp" else Basis.IDENTITY
		car.transform=pose*Transform3D(slope,Vector3(0,.2,0));car.gravity_up=pose.basis.y
		await physics_frame;await physics_frame
		car.suspension_mask=1|4;car._physics_process(.016);assert(car.grounded_count==0,"Legacy mask should reproduce ignored construction")
		car.suspension_mask=1|2|4;car._physics_process(.016)
		assert(car.grounded_count==4,"All tyres must detect "+kind)
		for corner in car.corners: assert(corner.trace_collider==body.get_instance_id() and corner.compression>0)
		results.append({"kind":kind,"legacy_contacts":0,"fixed_contacts":car.grounded_count})
		body.free()
	print("CONSTRUCTION_SUSPENSION_PASS ",JSON.stringify(results))
	world.free();quit()
