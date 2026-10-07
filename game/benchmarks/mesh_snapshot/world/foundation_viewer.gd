extends "res://mocks/ring_vibes.gd"
## Retains the existing DEM, map, CDLOD, curved ocean, cloud and sky pipeline.
## F1-F4: ground/vehicle/flight/space. F5-F8: quarter-ring locations.

var _preview_queue: Array[int] = []
var _preview_thread: Thread
var _preview_index := -1
var _foundation_ready := false
var _started_ms := 0
var authored_patch: Node3D
var content_gallery: Node

func base_height(arc: float, lateral: float) -> float:
	return super._terrain_h(arc, lateral)

func _terrain_h(arc: float, lateral: float) -> float:
	if is_instance_valid(authored_patch) and authored_patch.contains(Vector2(arc,lateral)):
		return RingFrame.coordinates(authored_patch.triangle_point(Vector2(arc,lateral)), _radius()).y
	return super._terrain_h(arc,lateral)

func _load_buildings() -> void:
	# Automatic OSM placement is retired from this viewer. Preserve source data.
	pass

func _load_roadlines() -> void:
	# No automatic road-derived placements or hedge ribbons.
	pass

func _build_hedges() -> void:
	pass

func _patch_preview(_base: String) -> Image:
	# Keep real heightfields; imagery is allowed to resolve after the first frame.
	return null

func _decode_preview(base: String) -> Image:
	# Worker only: file/image operations. GPU upload stays on the main thread.
	var source := base + "_sat.dat"
	if not FileAccess.file_exists(source):
		return null
	var version := "%s:%s:%s" % [source, FileAccess.get_modified_time(source), PATCH_COL_RES]
	var cache := "user://foundation-previews/" + version.sha256_text() + ".png"
	var img := Image.new()
	if FileAccess.file_exists(cache) and img.load(cache) == OK:
		img.convert(Image.FORMAT_RGB8)
		return img
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(source)) != OK:
		return null
	img.resize(PATCH_COL_RES, PATCH_COL_RES, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute("user://foundation-previews")
	img.save_png(cache)
	return img

func _process(delta: float) -> void:
	if not _foundation_ready:
		return
	super._process(delta)
	if _preview_thread != null:
		if _preview_thread.is_alive():
			return
		var img: Image = _preview_thread.wait_to_finish()
		_preview_thread = null
		if img != null:
			_patch_col_tex.update_layer(img, _preview_index)
			print("PREVIEW ready: ", _patch_names[_preview_index])
			if OS.get_cmdline_user_args().has("--preview-check"):
				print("PASS: background preview decoded and uploaded")
				get_tree().quit()
				return
	if _preview_queue.is_empty():
		return
	var arc := RingFrame.coordinates(_cam.position, _radius()).x
	var best := 0
	var distance := INF
	for i in _preview_queue.size():
		var candidate := absf(wrapf(_patch_rects[_preview_queue[i]].x - arc,
			-CIRCUMFERENCES[c_idx] / 2.0, CIRCUMFERENCES[c_idx] / 2.0))
		if candidate < distance:
			distance = candidate
			best = i
	_preview_index = _preview_queue[best]
	_preview_queue.remove_at(best)
	_preview_thread = Thread.new()
	var error := _preview_thread.start(_decode_preview.bind(
		"res://mocks/dem/" + _patch_names[_preview_index]))
	if error != OK:
		push_warning("Could not start preview worker: %s" % error)
		_preview_thread = null

func _exit_tree() -> void:
	if _preview_thread != null:
		_preview_thread.wait_to_finish()
	if _hires_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_hires_task)

func _load_dem() -> void:
	if not OS.get_cmdline_user_args().has("--foundation-lite"):
		super._load_dem()

func _load_patches() -> void:
	if not OS.get_cmdline_user_args().has("--foundation-lite"):
		super._load_patches()

func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	await super._ready()
	_foundation_ready = true
	if not OS.get_cmdline_user_args().has("--foundation-check"):
		var patch := preload("res://benchmarks/mesh_snapshot/world/authored_patch.gd").new()
		add_child(patch)
		patch.setup(self)
		authored_patch = patch
		for mat in _mats:
			mat.set_shader_parameter("authored_patch_enabled", true)
			mat.set_shader_parameter("authored_patch_rect", Vector4(0,0,128,128))
		_cam.position = RingFrame.position(-70,base_height(-70,0)+60,0,_radius())
		_look = Vector2(0,-0.55)
		_apply_look()
		if OS.get_cmdline_user_args().has("--author-check"):
			_check_authoring.call_deferred()
		else:
			content_gallery = preload("res://benchmarks/mesh_snapshot/world/content_gallery.gd").new()
			add_child(content_gallery)
			content_gallery.setup(patch)
			if OS.get_cmdline_user_args().has("--content-check"):
				_check_content.call_deferred()
	for i in _patch_names.size():
		_preview_queue.append(i)
	print("FOUNDATION ready in ", Time.get_ticks_msec() - _started_ms,
		" ms; queued previews: ", _preview_queue.size())
	if OS.get_cmdline_user_args().has("--foundation-check"):
		_check_frames.call_deferred()
	if OS.get_cmdline_user_args().has("--author-capture"):
		_capture_authoring.call_deferred()

func _capture_authoring() -> void:
	while is_instance_valid(content_gallery) and not content_gallery.finished:
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--content-all"):
		content_gallery.contact_debug.visible = true
		_hud_full = false
		_update_hud()
		for i in content_gallery.entries.size():
			content_gallery.focus_next()
			for frame in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var shot := "user://ring-content-%d.png" % i
			assert(get_viewport().get_texture().get_image().save_png(shot) == OK)
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--content-closeup"):
		content_gallery.selected = 2
		content_gallery.focus_next()
		_hud_full = false
		_update_hud()
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "user://ring-authoring-preview.png"
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("AUTHOR capture: ", ProjectSettings.globalize_path(path), " result=", error)
	get_tree().quit()

func _check_content() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run --content-check with a renderer to validate posed geometry")
		get_tree().quit(1)
		return
	while not content_gallery.finished:
		await get_tree().process_frame
	assert(content_gallery.entries.size() == 5)
	for entry in content_gallery.entries:
		_check_entry_support(entry)
		var bounds: AABB = content_gallery.model_bounds(entry.model)
		assert(absf(bounds.position.y) < 0.002)
	var entry: Dictionary = content_gallery.entries[0]
	var before: Vector3 = entry.root.position
	authored_patch.sculpt(entry.coord, 3.0)
	assert(entry.root.position.distance_to(before) > 2.9)
	for item in content_gallery.entries:
		_check_entry_support(item)
	print("PASS: five source assets loaded, posed geometry grounded, anchors follow terrain edits")
	if OS.get_cmdline_user_args().has("--author-capture"):
		return
	get_tree().quit()

func _check_entry_support(entry: Dictionary) -> void:
	if entry.footprint == Vector2.ZERO:
		assert(entry.root.position.distance_to(authored_patch.triangle_point(entry.coord)) < 0.001)
	else:
		assert(entry.support.valid)
		assert(entry.support.min_gap > -0.02)
		assert(entry.support.samples.size() == 9)
		assert(entry.root.transform.is_equal_approx(entry.support.transform))

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
		if is_instance_valid(authored_patch) and key in [KEY_1,KEY_2,KEY_3,KEY_Q,KEY_W,KEY_E,KEY_H,KEY_R]:
			return # the authored tile is tied to its saved ring dimensions
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

func _check_authoring() -> void:
	var patch = authored_patch
	var material: StandardMaterial3D = patch.surface.material_override
	assert(material.albedo_texture != null)
	var arrays: Array = patch.surface.mesh.surface_get_arrays(0)
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert(uv.size() == arrays[Mesh.ARRAY_VERTEX].size())
	assert(uv[0].is_equal_approx(Vector2(-64,-64)))
	assert(uv[1].is_equal_approx(Vector2(-62,-64)))
	assert(uv[2].is_equal_approx(Vector2(-64,-62)))
	patch.save_path = "user://ring-authoring/test-patch.json"
	var before: Vector3 = patch.triangle_point(Vector2.ZERO)
	patch.sculpt(Vector2.ZERO, 8.0)
	assert(patch.triangle_point(Vector2.ZERO).distance_to(before) > 7.9)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for p in [Vector2.ZERO,Vector2(13.3,5.7),Vector2(-24,20)]:
		var point: Vector3 = patch.triangle_point(p)
		var up := RingFrame.up(p.x,_radius())
		var query := PhysicsRayQueryParameters3D.create(point+up*50, point-up*50,1<<19)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty())
		assert(hit.position.distance_to(point)<0.02)
	for i in patch.markers.size():
		assert(patch.markers[i].position.distance_to(patch.triangle_point(patch.anchors[i]))<0.001)
	assert(patch.save_edits())
	assert(patch.bake_status == "ready")
	var bake = preload("res://benchmarks/mesh_snapshot/world/terrain_bake.gd")
	var key: String = patch.bake_key()
	var hits: int = patch.cache_hits
	assert(patch.baked_levels.size() == 7)
	assert(patch.baked_levels[0].width == 65 and patch.baked_levels[-1].width == 2)
	for level in patch.baked_levels:
		assert(level.heights.size() == level.width*level.width)
		var stride: int = (patch.N-1)/(level.width-1)
		for edge in level.width:
			assert(absf(level.heights[edge]-patch.heights[edge*stride]) < 0.001)
			assert(absf(level.heights[(level.width-1)*level.width+edge]-patch.heights[(patch.N-1)*patch.N+edge*stride]) < 0.001)
			assert(absf(level.heights[edge*level.width]-patch.heights[edge*stride*patch.N]) < 0.001)
			assert(absf(level.heights[edge*level.width+level.width-1]-patch.heights[edge*stride*patch.N+patch.N-1]) < 0.001)
		assert(level.height_error_m >= 0)
	var saved: PackedFloat64Array = patch.heights.duplicate()
	patch.sculpt(Vector2.ZERO,-12)
	assert(patch.baked_levels.is_empty())
	assert(bake.read_cache(patch.save_path+".bake.res",patch.bake_key(),patch.N) == null)
	assert(patch.load_edits())
	assert(patch.cache_hits == hits+1)
	assert(patch.bake_key() == key)
	assert(patch.save_edits()) # Re-save cached subresources, not just fresh meshes.
	assert(patch.load_edits())
	assert(patch.cache_hits == hits+2)
	assert(bake.read_cache(patch.save_path+".bake.res","stale-revision",patch.N) == null)
	# Invalid derived metadata must fall back, never replace source terrain.
	var invalid := Resource.new()
	invalid.set_meta("revision",key)
	var invalid_path := "user://ring-authoring/test-invalid.bake.res"
	assert(ResourceSaver.save(invalid,invalid_path) == OK)
	assert(bake.read_cache(invalid_path,key,patch.N) == null)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cached_point: Vector3 = patch.triangle_point(Vector2.ZERO)
	var cached_up := RingFrame.up(0,_radius())
	var cached_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cached_point+cached_up*50,cached_point-cached_up*50,1<<19))
	assert(not cached_hit.is_empty() and cached_hit.position.distance_to(cached_point) < 0.02)
	print("PASS: seven baked levels, warm cache hit, stale/invalid rejection, cached collision")
	var max_error := 0.0
	for i in saved.size():
		max_error = maxf(max_error,absf(patch.heights[i]-saved[i]))
	print("SAVE round-trip maximum height error (m): ", max_error)
	assert(max_error < 0.000001)
	patch.mode = 1
	var middle: int = (patch.N / 2) * patch.N + (patch.N / 2)
	var previous: float = patch.heights[middle]
	var average: float = (patch.heights[middle-1]+patch.heights[middle+1]+patch.heights[middle-patch.N]+patch.heights[middle+patch.N])/4
	patch.sculpt(Vector2.ZERO,0.5)
	assert(absf(patch.heights[middle] - lerpf(previous,average,0.5)) < 0.000001)
	patch.mode = 2
	previous = patch.heights[middle]
	patch.flatten_height = previous+10
	patch.sculpt(Vector2.ZERO,0.5)
	assert(absf(patch.heights[middle]-previous-5) < 0.000001)
	assert(patch.heights[0] == patch.baseline[0])
	var edited_uv: PackedVector2Array = patch.surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	assert(edited_uv == uv)
	print("PASS: sculpt, collision, anchors, save/reload, smooth/flatten, border, metre-scaled grass UVs")
	_check_footprints(patch)
	get_tree().quit()

func _check_footprints(patch: Node3D) -> void:
	var support = preload("res://benchmarks/mesh_snapshot/world/terrain_support.gd")
	var saved: PackedFloat64Array = patch.heights.duplicate()
	for z in patch.N:
		for x in patch.N:
			patch.heights[z*patch.N+x] = 10.0 + (x*patch.STEP-patch.SIZE/2)*0.1 + (z*patch.STEP-patch.SIZE/2)*0.05
	patch.rebuild()
	var vehicle: Dictionary = support.fit(patch,Vector2.ZERO,Vector2(2,3),true)
	assert(vehicle.valid and vehicle.max_gap < 0.02 and vehicle.min_gap > -0.02)
	assert(vehicle.transform.basis.y.dot(RingFrame.up(0,_radius())) < 0.999)
	var relay: Dictionary = support.fit(patch,Vector2.ZERO,Vector2(2,3),false)
	assert(relay.valid and relay.max_gap > 0.5 and relay.min_gap > -0.02)
	assert(relay.transform.basis.y.dot(RingFrame.up(0,_radius())) > 0.99999)
	patch.heights[(patch.N/2)*patch.N+patch.N/2] += 3.0
	patch.rebuild()
	var bump: Dictionary = support.fit(patch,Vector2.ZERO,Vector2(6,6),true)
	assert(bump.valid and bump.max_gap > 2 and bump.min_gap > -0.02)
	assert(not support.fit(patch,Vector2(127,0),Vector2(2,3),true).valid)
	patch.heights = saved
	patch.rebuild()
	print("PASS: footprint slope fit, upright relay, uneven-ground gaps, outside-tile rejection")
