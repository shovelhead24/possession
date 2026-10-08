extends SceneTree
const Ring = preload("res://world/terrain_drive_ring.gd")

func _initialize() -> void:
	var failures := 0
	for arc in [0.0,20000.0,-20000.0]:
		var p := Ring.point(arc,30,100)
		var up := Ring.up_at(p)
		for yaw in [0.0,.65,-.8,PI]:
			var frame := Ring.tangent_basis(p,yaw)
			var expected_forward := Vector3.BACK.rotated(up,yaw)
			if frame.determinant()<.999:
				push_error("Vehicle frame reflects the model at arc=%s yaw=%s" % [arc,yaw]);failures+=1
			if (-frame.z).dot(expected_forward)<.999 or frame.y.dot(up)<.999:
				push_error("Vehicle heading or radial up changed");failures+=1
			var recovered := Ring.tangent_basis(p,Ring.tangent_yaw(p,-frame.z))
			if recovered.z.dot(frame.z)<.999:
				push_error("Recovery reverses the current heading");failures+=1
			# The driver is at local -X. It must land on the physical left of forward.
			if (frame*Vector3.LEFT).dot(up.cross(expected_forward))<.999:
				push_error("Driver seat is on the physical right");failures+=1
			for steering in [-.4,.4]:
				var visual_forward := -(frame*Basis(Vector3.UP,steering)).z
				var tyre_forward := expected_forward.rotated(up,steering)
				if visual_forward.dot(tyre_forward)<.999:
					push_error("Visible wheels steer against physical tyre direction");failures+=1
	if failures==0: print("DRIVE_VEHICLE_FRAME_PASS: proper rotation, unchanged heading/up, left driver, both steering directions")
	quit(0 if failures==0 else 1)
