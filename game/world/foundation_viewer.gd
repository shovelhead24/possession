extends "res://mocks/ring_vibes.gd"
## Retains the existing DEM, map, CDLOD, curved ocean, cloud and sky pipeline.
## F1-F4: ground/vehicle/flight/space. F5-F8: quarter-ring locations.

func _load_dem() -> void:
	if not OS.get_cmdline_user_args().has("--foundation-lite"):
		super._load_dem()

func _load_patches() -> void:
	if not OS.get_cmdline_user_args().has("--foundation-lite"):
		super._load_patches()

func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--foundation-check"):
		_check_frames.call_deferred()

func _check_frames() -> void:
	sun_paused = true
	for key in [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		_unhandled_input(event)
		await get_tree().process_frame
		await get_tree().process_frame
		var coord := RingFrame.coordinates(_cam.position, _radius())
		var sky_up: Vector3 = _sky_mat.get_shader_parameter("local_up")
		assert(sky_up.dot(_ring_up(_cam.position)) > 0.999)
		assert(_cam.global_basis.y.dot(_ring_up(_cam.position)) > 0.8)
		print("FOUNDATION reference ", key - KEY_F1 + 1, " arc/alt/lat ", coord)
	print("PASS: viewer reference sky/camera frames")
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key >= KEY_F1 and key <= KEY_F8:
			_set_mode(Mode.FLY)
			var coord := RingFrame.coordinates(_cam.position, _radius())
			var heights := [2.0, 8.0, 2000.0, 100000.0]
			if key <= KEY_F4:
				coord.y = maxf(_terrain_h(coord.x, coord.z), 0.0) + heights[key - KEY_F1]
			else:
				coord.x = float(key - KEY_F5) * CIRCUMFERENCES[c_idx] / 4.0
				coord.y = maxf(_terrain_h(coord.x, coord.z), 0.0) + 120.0
			_cam.position = RingFrame.position(coord.x, coord.y, coord.z, _radius())
			_apply_look()
			return
	super._unhandled_input(event)
