extends "res://world/terrain_baseline.gd"
const Ring = preload("res://world/terrain_drive_ring.gd")
var vehicle_kit: Node
var streamer: Node
var jitter_trace: Node
var backdrop: Node3D
var satellite_texture: Texture2D

func _ready() -> void:
	curve_to_ring=true
	# Enable only for this standalone demo; vehicle visuals and camera must share
	# the interpolated pose when rendering faster than the 60 Hz physics loop.
	get_tree().physics_interpolation=true
	brief_path="res://world/terrain_drive_brief.json"
	super._ready()

func prepare_content() -> void:
	if not OS.get_cmdline_user_args().has("--no-drive-satellite"):
		loading.log_event("Preparing full-resolution satellite imagery and mipmaps")
		worker=Thread.new()
		worker.start(preload("res://world/terrain_drive_satellite.gd").load_image)
		while worker.is_alive(): await get_tree().process_frame
		var satellite: Image=worker.wait_to_finish();worker=null
		if satellite:
			satellite_texture=ImageTexture.create_from_image(satellite)
			material=preload("res://world/terrain_drive_satellite.gd").create_material(satellite_texture,source.metadata)
			for entry in tile_entries.values(): entry.visual.material_override=material
	if not OS.get_cmdline_user_args().has("--no-drive-backdrop"):
		loading.log_event("Preparing distant DEM scenery and the existing ringworld")
		backdrop=preload("res://world/terrain_drive_backdrop.gd").new();add_child(backdrop)
		backdrop.setup(self)
		await get_tree().process_frame
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	loading.log_event("Preparing the existing Warthog model, suspension and saved tuning")
	await get_tree().process_frame
	vehicle_kit=preload("res://world/terrain_drive_vehicle.gd").new();add_child(vehicle_kit)
	await vehicle_kit.setup(self)
	var cold_source: RefCounted
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cold-cache-tag="):
			# Isolated diagnostic namespace: exercise cold builds without deleting user caches.
			cold_source=source.snapshot(source.features);cold_source.centre_height=source.centre_height
			cold_source.curve_to_ring=source.curve_to_ring
			cold_source.identity=(source.identity+arg).sha256_text()
			print("DRIVE_COLD_NAMESPACE ",cold_source.identity)
	streamer=preload("res://world/terrain_drive_stream.gd").new();streamer.cold_source=cold_source;add_child(streamer);streamer.setup(self)
	vehicle_kit.car.trace_suspension=true
	vehicle_kit.car.max_contacts_reported=8
	jitter_trace=preload("res://world/terrain_drive_trace.gd").new();jitter_trace.arena=self;add_child(jitter_trace)

func _input(event: InputEvent) -> void:
	if ready_to_play and jitter_trace and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8:
		jitter_trace.toggle();return
	if vehicle_kit and vehicle_kit.handle_input(event): return
	if vehicle_kit and vehicle_kit.driving:
		if event is InputEventKey and event.pressed:
			if event.keycode==KEY_F2: loading.reopen()
			if event.keycode==KEY_ENTER: loading.close()
			if event.keycode==KEY_ESCAPE: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		return
	super._input(event)

func _process(delta: float) -> void:
	if not ready_to_play: return
	# Reuse baseline frame statistics; fly movement is separate from the driving camera.
	var old_diagnostic := diagnostic
	if vehicle_kit.driving: diagnostic=true
	super._process(delta)
	diagnostic=old_diagnostic
	if not vehicle_kit.driving and not diagnostic and loading.dismissed:
		# The flight camera remains in the ring's tangent frame as it travels.
		var ring_position := Ring.coordinates(camera.position)
		var arc := clampf(ring_position.x,streamer.world_bounds.position.x+50,streamer.world_bounds.end.x-50)
		var lateral := clampf(ring_position.z,streamer.world_bounds.position.y+50,streamer.world_bounds.end.y-50)
		var height := maxf(ring_position.y,source.surface_height(Vector2(arc,lateral))+2)
		camera.position=Ring.point(arc,height,lateral)
	if vehicle_kit.driving: vehicle_kit.update_camera(delta)
	var sorted := frame_times.duplicate();sorted.sort()
	var p95: float=sorted[int(sorted.size()*.95)] if not sorted.is_empty() else 0.0
	var drive_position := Ring.coordinates(vehicle_kit.car.position)
	hud.text="TERRAIN / WARTHOG + RINGWORLD\n%d FPS | p95 %.2f ms | %.0f km/h | %d wheels grounded\nWASD drive · Space brake · C camera · E fly/drive · R recover\nF5 vehicle setup · F2 briefing · RMB look · Shift fast flight\nTerrain: %d resident | %d queued | %d generated / %d cache hits\nArc %.0f m | lateral %.0f m | %s" % [Engine.get_frames_per_second(),p95,vehicle_kit.car.linear_velocity.length()*3.6,vehicle_kit.car.grounded_count,tile_entries.size(),streamer.pending.size(),streamer.builds,streamer.hits,drive_position.x,drive_position.z,"Waiting for collision" if vehicle_kit.car.streaming_suspended else ("Terrain supply braking" if vehicle_kit.car.stream_braking else "Ready")]

	hud.text+="\n"+jitter_trace.status

func fly_bounds() -> Rect2:
	return streamer.world_bounds if streamer else Rect2(Vector2(-1600,-1600),Vector2(3200,3200))
