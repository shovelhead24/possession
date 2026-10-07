extends "res://world/terrain_baseline.gd"
var vehicle_kit: Node
var streamer: Node
var jitter_trace: Node

func _ready() -> void:
	brief_path="res://world/terrain_drive_brief.json"
	super._ready()

func prepare_content() -> void:
	loading.log_event("Preparing the existing Warthog model, suspension and saved tuning")
	await get_tree().process_frame
	vehicle_kit=preload("res://world/terrain_drive_vehicle.gd").new();add_child(vehicle_kit)
	await vehicle_kit.setup(self)
	var cold_source: RefCounted
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cold-cache-tag="):
			# Isolated diagnostic namespace: exercise cold builds without deleting user caches.
			cold_source=source.snapshot(source.features);cold_source.centre_height=source.centre_height
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
		# Leave a margin inside the native DEM's valid sampling rectangle.
		camera.position.x=clampf(camera.position.x,streamer.world_bounds.position.x+50,streamer.world_bounds.end.x-50)
		camera.position.z=clampf(camera.position.z,streamer.world_bounds.position.y+50,streamer.world_bounds.end.y-50)
	if vehicle_kit.driving: vehicle_kit.update_camera(delta)
	var sorted := frame_times.duplicate();sorted.sort()
	var p95: float=sorted[int(sorted.size()*.95)] if not sorted.is_empty() else 0.0
	hud.text="TERRAIN / WARTHOG + EXPANSION\n%d FPS | p95 %.2f ms | %.0f km/h | %d wheels grounded\nWASD drive · Space brake · C camera · E fly/drive · R recover\nF5 vehicle setup · F2 briefing · RMB look · Shift fast flight\nTerrain: %d resident | %d queued | %d generated / %d cache hits\nPosition %.0f, %.0f m | %s" % [Engine.get_frames_per_second(),p95,vehicle_kit.car.linear_velocity.length()*3.6,vehicle_kit.car.grounded_count,tile_entries.size(),streamer.pending.size(),streamer.builds,streamer.hits,vehicle_kit.car.position.x,vehicle_kit.car.position.z,"Waiting for collision" if vehicle_kit.car.streaming_suspended else ("Terrain supply braking" if vehicle_kit.car.stream_braking else "Ready")]

	hud.text+="\n"+jitter_trace.status

func fly_bounds() -> Rect2:
	return streamer.world_bounds if streamer else Rect2(Vector2(-1600,-1600),Vector2(3200,3200))
