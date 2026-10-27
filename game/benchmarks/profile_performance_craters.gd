extends SceneTree

const OUT := "C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/performance-crater-phases.json"
const Source = preload("res://world/terrain_baseline_source.gd")
const Ring = preload("res://world/terrain_drive_ring.gd")
const Destruction = preload("res://world/terrain_drive_destruction.gd")
const Stream = preload("res://world/terrain_drive_stream.gd")

class Fixture extends Node3D:
	var source: RefCounted
	var tile_entries := {}
	var tiles: Array = []
	var material := StandardMaterial3D.new()
	var streamer: Node
	var destruction: Node
	var ready_to_play := true
	func request_crater(point: Vector3, radius: float) -> bool:
		return destruction.request(point, radius)

var report := {"harness": "fixture", "case": "seam_first_and_overlapping_repeat", "shots": []}

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func():
		push_error("PERFORMANCE_CRATER_PROFILE_TIMEOUT")
		_write_report()
		quit(1)
	)
	run.call_deferred()

func install(arena: Node3D, key: Vector2i, data: Dictionary) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_INDEX] = data.indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	arena.add_child(visual)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	arena.add_child(body)
	arena.tile_entries[key] = {"visual": visual, "body": body}
	arena.tiles.append(visual)

func probe(arena: Node3D, arc: float, lateral: float) -> Dictionary:
	var height: float = arena.source.surface_height(Vector2(arc, lateral))
	var point := Ring.point(arc, height, lateral)
	var up := Ring.up_at(point)
	var query := PhysicsRayQueryParameters3D.create(point + up * 30.0, point - up * 30.0, 1)
	return arena.get_world_3d().direct_space_state.intersect_ray(query)

func worker_state(destruction: Node) -> String:
	if destruction.worker == null:
		return "none"
	return "warming" if destruction.warming else ("alive" if destruction.worker.is_alive() else "finished_unjoined")

func phase_state(destruction: Node) -> String:
	if destruction.activate:
		return "activate"
	if not destruction.results.is_empty():
		return "results_mesh_upload"
	if destruction.worker != null:
		return "worker_warm" if destruction.warming else "worker_edit"
	if not destruction.prepared.is_empty():
		return "prepared_waiting_activation"
	return "idle"

func capture_shot(arena: Fixture, label: String, point: Vector3) -> Dictionary:
	var destruction: Node = arena.destruction
	var prior_revision: int = destruction.applied_revision
	var start_usec := Time.get_ticks_usec()
	assert(arena.request_crater(point, 2.0), "Crater request rejected: " + label)
	var samples: Array = []
	var previous := Time.get_ticks_usec()
	var started_ms := Time.get_ticks_msec()
	var publication_usec := start_usec
	while destruction.applied_revision == prior_revision:
		var state_before := phase_state(destruction)
		var results_before: int = destruction.results.size()
		var activate_before: bool = destruction.activate
		var worker_before := worker_state(destruction)
		await process_frame
		var now := Time.get_ticks_usec()
		var state_after := phase_state(destruction)
		var phase := state_before if state_before == state_after else state_before + "->" + state_after
		samples.append({
			"frame": samples.size(),
			"delta_ms": (now - previous) / 1000.0,
			"phase": phase,
			"state_before": state_before,
			"state_after": state_after,
			"results_before": results_before,
			"results_after": destruction.results.size(),
			"activate_before": activate_before,
			"activate_after": destruction.activate,
			"worker_before": worker_before,
			"worker_after": worker_state(destruction),
			"mesh_ms_total": destruction.last_mesh_ms,
			"collision_ms_total": destruction.last_collision_ms,
			"worker_ms": destruction.last_worker_ms,
			"update_ms": destruction.last_update_ms
		})
		previous = now
		if destruction.applied_revision != prior_revision:
			publication_usec = now
			break
		if Time.get_ticks_msec() - started_ms > 25000:
			push_error("Crater did not publish within 25 seconds: " + label)
			break
	await physics_frame
	await physics_frame
	var deltas: Array[float] = []
	var by_phase := {}
	var overall_max := 0.0
	for sample in samples:
		var delta_ms: float = sample.delta_ms
		deltas.append(delta_ms)
		overall_max = maxf(overall_max, delta_ms)
		var phase_key: String = sample.phase
		if not by_phase.has(phase_key):
			by_phase[phase_key] = {"frames": 0, "max_ms": 0.0, "sum_ms": 0.0}
		by_phase[phase_key].frames += 1
		by_phase[phase_key].max_ms = maxf(by_phase[phase_key].max_ms, delta_ms)
		by_phase[phase_key].sum_ms += delta_ms
	deltas.sort()
	return {
		"label": label,
		"request_to_publish_ms": (publication_usec - start_usec) / 1000.0,
		"frames": samples.size(),
		"frame_max_ms": overall_max,
		"frame_p95_ms": deltas[int(deltas.size() * 0.95)] if not deltas.is_empty() else 0.0,
		"last_worker_ms": destruction.last_worker_ms,
		"last_mesh_ms": destruction.last_mesh_ms,
		"last_collision_ms": destruction.last_collision_ms,
		"last_update_ms": destruction.last_update_ms,
		"phase_summary": by_phase,
		"per_frame": samples
	}

func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	if file == null:
		push_error("Could not write crater profile: " + OUT)
		return
	file.store_string(JSON.stringify(report, "\t", true, true))
	file.close()

func run() -> void:
	var source := Source.new()
	source.curve_to_ring = true
	assert(source.initialize(), "Terrain source initialization failed")
	var arena := Fixture.new()
	arena.source = source
	root.add_child(arena)
	var stream := Stream.new()
	stream.arena = arena
	stream.set_process(false)
	stream.set_physics_process(false)
	arena.streamer = stream
	arena.add_child(stream)
	stream.set_process(false);stream.set_physics_process(false)
	var destruction := Destruction.new()
	destruction.arena = arena
	arena.destruction = destruction
	arena.add_child(destruction)
	# The crater is centered on the shared edge of these two production-sized tiles.
	var seam_arc := 200.0
	var lateral := 100.0
	var left := Vector2i(0, 0)
	var right := Vector2i(1, 0)
	for key in [left, right]:
		install(arena, key, source.build_tile(key))
	await physics_frame
	await physics_frame
	var before: Dictionary = probe(arena, seam_arc, lateral)
	assert(not before.is_empty(), "Initial seam collision missing")
	var up := Ring.up_at(before.position)
	report.source_identity = source.identity
	report.tile_keys = [str(left), str(right)]
	report.start_position = [before.position.x, before.position.y, before.position.z]
	var first := await capture_shot(arena, "first_cold_crater", before.position + up * 1.0)
	assert(destruction.applied_revision >= 1, "First crater did not publish")
	var after_first: Dictionary = probe(arena, seam_arc, lateral)
	assert(not after_first.is_empty(), "First crater removed seam collision floor")
	var first_depth: float = (before.position - after_first.position).dot(up)
	assert(first_depth > 0.1, "First crater did not lower the collision surface")
	for offset in [-0.05, 0.05]:
		assert(not probe(arena, seam_arc + offset, lateral).is_empty(), "First crater opened tile seam")
	first.first_depth_m = first_depth
	var second := await capture_shot(arena, "repeated_overlapping_crater", after_first.position + up * 0.93)
	assert(destruction.applied_revision >= 2, "Repeated crater did not publish")
	var after_second: Dictionary = probe(arena, seam_arc, lateral)
	assert(not after_second.is_empty(), "Repeated crater removed seam collision floor")
	var second_increment: float = (after_first.position - after_second.position).dot(up)
	assert(second_increment > 0.0, "Overlapping crater failed to deepen the collision surface")
	for offset in [-0.05, 0.05]:
		assert(not probe(arena, seam_arc + offset, lateral).is_empty(), "Repeated crater opened tile seam")
	second.incremental_depth_m = second_increment
	# Streamer.build is the same source path used when a tile is reconstructed after eviction.
	for key in [left, right]:
		var live: Dictionary = arena.tile_entries[key]
		var rebuilt: Dictionary = stream.build(key)
		var live_arrays: Array = live.visual.mesh.surface_get_arrays(0)
		assert(rebuilt.indices == live_arrays[Mesh.ARRAY_INDEX], "Stream rebuild changed crater indices")
		assert(rebuilt.vertices == live_arrays[Mesh.ARRAY_VERTEX], "Stream rebuild changed crater vertices")
		var max_normal_error := 0.0
		for i in rebuilt.normals.size(): max_normal_error=maxf(max_normal_error,rebuilt.normals[i].distance_to(live_arrays[Mesh.ARRAY_NORMAL][i]))
		assert(max_normal_error<.002, "Normal error exceeds renderer packing tolerance")
		report["normal_error_"+str(key)]=max_normal_error
		report["stream_reload_" + str(key)] = "mesh arrays match"
	report.shots = [first, second]
	report.collision_checks = {
		"first_crater_depth_m": first_depth,
		"repeated_crater_increment_m": second_increment,
		"seam_offsets_m": [-0.05, 0.05],
		"stream_rebuild_arrays_match": true
	}
	_write_report()
	print("PERFORMANCE_CRATER_PROFILE_PASS ", JSON.stringify({
		"output": OUT,
		"first_max_frame_ms": first.frame_max_ms,
		"repeat_max_frame_ms": second.frame_max_ms,
		"first_latency_ms": first.request_to_publish_ms,
		"repeat_latency_ms": second.request_to_publish_ms
	}))
	arena.queue_free()
	await process_frame
	quit()


