extends SceneTree
const Frame = preload("res://world/ring_frame.gd")

func _initialize() -> void:
	var radius := Frame.CIRCUMFERENCE / TAU
	for fraction in [0.0, 0.25, 0.5, 0.75, 0.999999]:
		var arc: float = fraction * Frame.CIRCUMFERENCE
		for height in [2.0, 120.0, 4000.0, 100000.0]:
			var point := Frame.position(arc, height, 120.0)
			var restored := Frame.coordinates(point)
			assert(abs(wrapf(restored.x - arc, -Frame.CIRCUMFERENCE / 2, Frame.CIRCUMFERENCE / 2)) < 0.2)
			assert(abs(restored.y - height) < 0.2)
			assert(abs(restored.z - 120.0) < 0.001)
		assert(abs(Frame.up(arc).length() - 1.0) < 0.00001)
		var nearby := Frame.relative_position(arc + 0.01, 2.0, 0.0, arc, 2.0, 0.0)
		assert(abs(nearby.x - 0.01) < 0.00001)
	assert(Frame.position(0.0, 0.0, 0.0).length() < 0.001)
	assert(Frame.up(PI * radius).dot(Vector3.UP) < -0.999)
	assert(abs(Frame.sun_direction(0.3, 0.2).length() - 1.0) < 0.00001)
	print("PASS: ring round trips, local up, centimetre offsets, seam and sun direction")
	quit()
