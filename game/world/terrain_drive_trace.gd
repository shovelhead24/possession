extends "res://world/vehicle_trace.gd"
## Uses the workshop recorder's bounded pre-roll and physics-rate wheel probes.
var file: FileAccess
var path := ""
var marker_id := 0
var status := "F8: begin jitter capture (includes preceding 5s)"
var writer: Thread
var mutex := Mutex.new()
var signal_work := Semaphore.new()
var events: Array=[]
var dropped := 0

func save_events(output: FileAccess) -> void:
	var flushed := Time.get_ticks_usec()
	while true:
		signal_work.wait()
		mutex.lock()
		var batch := events
		events=[]
		mutex.unlock()
		for row in batch:
			if row.get("event")=="writer_close":
				output.flush();return
			output.store_line(JSON.stringify(row))
		if Time.get_ticks_usec()-flushed>1000000:
			output.flush();flushed=Time.get_ticks_usec()

func _process(delta: float) -> void:
	super._process(delta)
	if writer and not writer.is_alive():
		writer.wait_to_finish();writer=null
		status="Capture saved · F8: start another" if dropped==0 else "Capture saved with dropped log batches: %d" % dropped
		print("DRIVE_TRACE_SAVED ",path," dropped_batches=",dropped)

func traced_vehicles() -> Array:
	return arena.vehicle_kit.vehicles if arena.ready_to_play else []

func terrain_context() -> Dictionary:
	var stream: Node=arena.streamer
	return {"jobs":stream.pending.size(),"worker_active":stream.worker!=null,"resident_chunks":arena.tile_entries.size(),"generated":stream.builds,"cache_hits":stream.hits,"phase":stream.last_phase,"phase_ms":stream.last_phase_ms,"phase_at_usec":stream.last_phase_at,"relocating":arena.vehicle_kit.relocating}

func frame_context() -> Dictionary:
	var car: Node3D=arena.vehicle_kit.car
	return {"physics_frame":Engine.get_physics_frames(),"interpolation_fraction":Engine.get_physics_interpolation_fraction(),"car_position":vector(car.global_position),"camera_position":vector(arena.camera.global_position),"camera_rotation":vector(arena.camera.global_rotation),"camera_mode":arena.vehicle_kit.menu.settings.camera_mode,"terrain":terrain_context()}

func write_event(event: String, data: Dictionary) -> void:
	if not file: return
	var row := {"event":event,"time_usec":Time.get_ticks_usec()}
	row.merge(data)
	mutex.lock()
	if events.size()<600 or event=="writer_close": events.append(row)
	else: dropped+=1
	mutex.unlock()
	signal_work.post()

func toggle() -> void:
	if active_id:
		mark(active_id,false)
		write_event("capture_end",{"marker_id":marker_id})
		write_event("writer_close",{})
		file=null
		status="Finishing capture…"
	else:
		if writer: return
		var directory := OS.get_user_data_dir().path_join("terrain-drive-traces")
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--drive-trace-dir="): directory=arg.trim_prefix("--drive-trace-dir=")
		DirAccess.make_dir_recursive_absolute(directory)
		path=directory.path_join("jitter-"+Time.get_datetime_string_from_system().replace(":","-")+"-"+str(Time.get_ticks_usec())+".jsonl")
		file=FileAccess.open(path,FileAccess.WRITE)
		if not file:
			status="Capture failed: cannot open trace file";push_error(status+" "+path);return
		dropped=0;signal_work=Semaphore.new();writer=Thread.new()
		if writer.start(save_events.bind(file))!=OK:
			writer=null;file=null;status="Capture failed: writer unavailable";return
		marker_id+=1
		write_event("capture_begin",{"marker_id":marker_id,"schema":1,"physics_ticks_per_second":Engine.physics_ticks_per_second,"max_fps":Engine.max_fps,"physics_interpolation":ProjectSettings.get_setting("physics/common/physics_interpolation",false),"tuning":arena.vehicle_kit.saved_values})
		mark(marker_id,true)
		status="RECORDING JITTER · F8: stop and save"
		print("DRIVE_TRACE_STARTED ",path)

func _exit_tree() -> void:
	if active_id: toggle()
	if writer: writer.wait_to_finish();writer=null
