extends Node3D
signal surface_changed
## A fixed-resolution curved tile: mesh, physics and anchors share its triangles.
const Frame = preload("res://world/ring_frame.gd")
const N := 65
const STEP := 4.0
const SIZE := (N - 1) * STEP
const GRASS_REPEAT_METRES := 2.0
const GRASS_TEXTURE := "res://world/grass_texture.webp"
var viewer: Node3D
var center := Vector2.ZERO
var heights := PackedFloat64Array()
var baseline := PackedFloat64Array()
var vertices := PackedVector3Array()
var surface := MeshInstance3D.new()
var shape := CollisionShape3D.new()
var enabled := false
var brush_radius := 16.0
var mode := 0
var aim := Vector2.INF
var flatten_height := 0.0
var flatten_set := false
var dirty := false
var markers: Array[Node3D] = []
var anchors: Array[Vector2] = []
var label := Label.new()
var cursor := MeshInstance3D.new()
var timer := 0.0
var save_path := "user://ring-authoring/home.json"

func setup(owner_viewer: Node3D) -> void:
	viewer = owner_viewer
	if OS.get_cmdline_user_args().has("--foundation-lite"):
		save_path = "user://ring-authoring/home-lite.json"
	heights.resize(N * N)
	for z in N:
		for x in N:
			var p := center + Vector2(x * STEP - SIZE / 2, z * STEP - SIZE / 2)
			heights[z * N + x] = viewer.base_height(p.x, p.y)
	baseline = heights.duplicate()
	add_child(surface)
	var body := StaticBody3D.new()
	body.collision_layer = (1 << 19) | 1
	add_child(body)
	body.add_child(shape)
	var mat := StandardMaterial3D.new()
	var grass := Image.load_from_file(GRASS_TEXTURE)
	if grass != null and not grass.is_empty():
		grass.generate_mipmaps()
		mat.albedo_texture = ImageTexture.create_from_image(grass)
		mat.albedo_color = Color.WHITE
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mat.texture_repeat = true
	else:
		push_warning("Grass texture unavailable; using the diagnostic green fallback")
		mat.albedo_color = Color(0.29, 0.37, 0.22)
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.material_override = mat
	add_child(cursor)
	var cursor_mat := StandardMaterial3D.new()
	cursor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_mat.albedo_color = Color.YELLOW
	cursor.material_override = cursor_mat
	var layer := CanvasLayer.new()
	add_child(layer)
	label.position = Vector2(12, 600)
	label.add_theme_color_override("font_color", Color.YELLOW)
	layer.add_child(label)
	rebuild()
	# Human-scale references; the source-asset gallery supplies the actual relay.
	for a in [Vector2(24, 0), Vector2(-24, 20)]:
		var anchor := Node3D.new()
		add_child(anchor)
		anchors.append(a)
		markers.append(anchor)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1, 2, 1)
		mesh.mesh = box
		mesh.position.y = box.size.y / 2
		anchor.add_child(mesh)
	reground()
	if not OS.get_cmdline_user_args().has("--author-check") and FileAccess.file_exists(save_path):
		if not load_edits():
			push_warning("Saved terrain could not be loaded; file retained: " + save_path)

func contains(p: Vector2) -> bool:
	return absf(p.x - center.x) < SIZE / 2 and absf(p.y - center.y) < SIZE / 2

func triangle_point(p: Vector2) -> Vector3:
	var uv := (p - center + Vector2.ONE * SIZE / 2) / STEP
	var x := clampi(floori(uv.x), 0, N - 2)
	var z := clampi(floori(uv.y), 0, N - 2)
	var u := clampf(uv.x - x, 0, 1)
	var v := clampf(uv.y - z, 0, 1)
	var i := z * N + x
	if u + v <= 1:
		return vertices[i] * (1-u-v) + vertices[i+1] * u + vertices[i+N] * v
	return vertices[i+N+1] * (u+v-1) + vertices[i+N] * (1-u) + vertices[i+1] * (1-v)

func rebuild() -> void:
	vertices.resize(N * N)
	for z in N:
		for x in N:
			var p := center + Vector2(x * STEP - SIZE/2, z * STEP - SIZE/2)
			vertices[z*N+x] = Frame.position(p.x, heights[z*N+x], p.y, viewer._radius())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in N-1:
		for x in N-1:
			var i := z*N+x
			for index in [i, i+1, i+N, i+1, i+N+1, i+N]:
				# Ring-surface metres, not a normalized 0..1 tile UV. Remains
				# stable during sculpting and across neighboring tile origins.
				var p := center + Vector2((index % N)*STEP-SIZE/2, (index / N)*STEP-SIZE/2)
				st.set_uv(p / GRASS_REPEAT_METRES)
				st.add_vertex(vertices[index])
	st.generate_normals()
	surface.mesh = st.commit()
	shape.shape = surface.mesh.create_trimesh_shape()
	reground()

func reground() -> void:
	for i in markers.size():
		markers[i].position = triangle_point(center + anchors[i])
		var up := Frame.up(center.x + anchors[i].x, viewer._radius())
		markers[i].basis = Basis(up.cross(Vector3.BACK).normalized(), up, Vector3.BACK)
	surface_changed.emit()

func sculpt(p: Vector2, amount: float) -> void:
	var old := heights.duplicate()
	# Border is pinned to the original tile; brush fades to zero within 16m of it.
	for z in range(1, N-1):
		for x in range(1, N-1):
			var local := Vector2(x*STEP-SIZE/2, z*STEP-SIZE/2)
			var d := (center+local).distance_to(p)
			if d >= brush_radius:
				continue
			var edge := minf(SIZE/2-absf(local.x), SIZE/2-absf(local.y))
			var weight := (1.0-smoothstep(0, brush_radius, d))*smoothstep(0,16,edge)
			var i := z*N+x
			if mode == 0:
				heights[i] += amount * weight
			elif mode == 1:
				heights[i] = lerpf(old[i], (old[i-1]+old[i+1]+old[i-N]+old[i+N])/4, clampf(absf(amount)*weight,0,1))
			else:
				heights[i] = lerpf(old[i], flatten_height, clampf(absf(amount)*weight,0,1))
	dirty = true
	rebuild()

func save_edits() -> bool:
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	var temp := save_path + ".pending"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version":1, "n":N, "step":STEP,
		"radius":viewer._radius(), "center":[center.x,center.y],
		"baseline":Array(baseline), "heights":Array(heights)}, "", true, true))
	file.close()
	if FileAccess.file_exists(save_path):
		if DirAccess.copy_absolute(save_path,save_path+".backup") != OK:
			return false
	if DirAccess.rename_absolute(temp,save_path) != OK:
		return false
	dirty = false
	return true

func load_edits() -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return false
	if data.get("version") != 1 or data.get("n") != N or data.get("step") != STEP:
		return false
	if absf(float(data.get("radius",0))-viewer._radius()) > 0.01:
		return false
	for field in ["heights", "baseline"]:
		if not data.get(field) is Array or data[field].size() != N*N:
			return false
		for value in data[field]:
			if not (value is float or value is int) or not is_finite(float(value)):
				return false
	if data.get("center") != [center.x,center.y]:
		return false
	heights = PackedFloat64Array(data.heights)
	baseline = PackedFloat64Array(data.baseline)
	rebuild()
	dirty = false
	return true

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F9:
		enabled = not enabled
		viewer._set_mode(viewer.Mode.FLY)
	if not enabled:
		return
	if event.keycode == KEY_F10:
		mode = (mode+1)%3
	if event.keycode == KEY_BRACKETLEFT:
		brush_radius = maxf(4,brush_radius-4)
	if event.keycode == KEY_BRACKETRIGHT:
		brush_radius = minf(64,brush_radius+4)
	if event.ctrl_pressed and event.keycode == KEY_S:
		if not save_edits(): push_error("Terrain save failed; original retained")
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	label.position.y = get_viewport().get_visible_rect().size.y - 64
	label.text = "F9 brush: %s | F10 %s | [ ] radius %.0fm | F11 assets | F12 contacts\nAim at tile, PageUp/Down sculpt | Ctrl+S save | %s" % [
		"ON" if enabled else "OFF", ["raise/lower","smooth","flatten"][mode],brush_radius,
		"UNSAVED" if dirty else "saved/unchanged"]
	cursor.visible = enabled
	if not enabled:
		return
	var cam: Camera3D = viewer._cam
	var query := PhysicsRayQueryParameters3D.create(cam.position,cam.position-cam.global_basis.z*3000,1<<19)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		cursor.hide()
		return
	var coords := Frame.coordinates(hit.position, viewer._radius())
	aim = Vector2(coords.x,coords.z)
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 48:
		for j in [i,i+1]:
			var p := aim + Vector2(cos(j*TAU/48),sin(j*TAU/48))*brush_radius
			if contains(p):
				lines.surface_add_vertex(triangle_point(p)+Frame.up(p.x,viewer._radius())*0.15)
			else:
				lines.surface_add_vertex(hit.position)
	lines.surface_end()
	cursor.mesh = lines
	var direction := int(Input.is_key_pressed(KEY_PAGEUP))-int(Input.is_key_pressed(KEY_PAGEDOWN))
	if direction == 0:
		flatten_set = false
		return
	if not flatten_set:
		flatten_height = coords.y
		flatten_set = true
	timer -= delta
	if timer <= 0:
		sculpt(aim, direction*0.5)
		timer = 0.12
