extends Node
## Static source-asset proof. No tactical controllers or encounter behavior.
const Frame = preload("res://world/ring_frame.gd")
const Support = preload("res://world/terrain_support.gd")
var patch: Node3D
var entries: Array[Dictionary] = []
var finished := false
var selected := -1
var contact_debug := MeshInstance3D.new()
var show_contacts := false
var loading_sources_done := 0
var loading_sources_total := 0

func setup(tile: Node3D) -> void:
	patch = tile
	patch.surface_changed.connect(reground_footprints)
	patch.add_child(contact_debug)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	contact_debug.material_override = material
	contact_debug.visible = false
	load_gallery.call_deferred()

func source_specs() -> Array:
	return [
		["Warthog", "res://../assets/halo_warthog.zip", Vector2(-12,-20), 4.8, false],
		["Altay tank", "res://altay_main_battle_tank_fbx.glb", Vector2(3,-20), 9.0, false],
		["Alien", "res://../prototypes/first-operation/lizard_rig.glb", Vector2(-12,0), 2.2, true],
		["T-Rex", "res://../assets/rigged-t-rex-fabulous/source/rigged_t-rex_fabulous.glb", Vector2(32,32), 24.0, false],
	]

func include_relay() -> bool:
	return true

func freeze_source_pose() -> bool:
	return true

func load_gallery() -> void:
	if DisplayServer.get_name() == "headless":
		push_warning("Static content gallery requires a renderer for posed-mesh baking; skipped headless")
		finished = true
		return
	# One source per frame keeps a visible progress state. Runtime GLTF decoding
	# is still synchronous; this is not the eventual streamed/baked asset pipeline.
	var specs := source_specs()
	loading_sources_total=specs.size();loading_sources_done=0
	for spec in specs:
		if patch.has_method("loading_event"):
			patch.loading_event("Importing "+str(spec[0])+" — "+str(spec[1]).get_file())
			await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var model := import_source(ProjectSettings.globalize_path(spec[1]).simplify_path())
		if model == null:
			loading_sources_done+=1
			if patch.has_method("loading_event"): patch.loading_event("WARNING: could not load "+str(spec[0]))
			push_warning("Gallery asset unavailable: " + spec[0])
			continue
		model.hide()
		patch.add_child(model)
		for player in model.find_children("*", "AnimationPlayer", true, false):
			player.stop()
		await get_tree().process_frame
		# Imported skinned bounds describe the source mesh, not necessarily its
		# visible rest pose. Freeze that pose before measuring the static display.
		for mesh in model.find_children("*", "MeshInstance3D", true, false) if freeze_source_pose() else []:
			if mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) is Skeleton3D:
				var baked: ArrayMesh = mesh.bake_mesh_from_current_skeleton_pose()
				if baked != null:
					for surface in baked.get_surface_count():
						baked.surface_set_material(surface,mesh.get_active_material(surface))
					mesh.skin = null
					mesh.skeleton = NodePath()
					mesh.mesh = baked
		patch.remove_child(model)
		var bounds := model_bounds(model)
		if not spec[4]:
			if bounds.size.x > bounds.size.z:
				model.rotate_y(-PI/2)
			model.rotate_y(PI)
			bounds = model_bounds(model)
		var extent: float = bounds.size.y if spec[4] else maxf(bounds.size.x,bounds.size.z)
		if extent <= 0.001:
			model.free()
			loading_sources_done+=1
			continue
		model.scale *= float(spec[3])/extent
		bounds = model_bounds(model)
		model.position -= Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
		add_entry(spec[0],model,spec[2],bounds.size.y)
		loading_sources_done+=1
		if patch.has_method("loading_event"): patch.loading_event(str(spec[0])+" ready")
		print("GALLERY loaded: ", spec[0], " dimensions(m)=", bounds.size)
	if include_relay(): add_entry("Frontier relay",make_relay(),Vector2(25,-22),8.5)
	finished = true
	print("GALLERY ready: ", entries.size(), " static assets; no controllers" if freeze_source_pose() else " live source rigs")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		show_contacts = not show_contacts
		contact_debug.visible = show_contacts
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		focus_next()
		get_viewport().set_input_as_handled()

func focus_next() -> void:
	if entries.is_empty():
		return
	selected = (selected+1)%entries.size()
	var entry: Dictionary = entries[selected]
	var distance := maxf(12,entry.height*2.2)
	var coord: Vector2 = entry.coord - Vector2(distance,0)
	var altitude := Frame.coordinates(entry.root.position,patch.viewer._radius()).y + maxf(5,entry.height*0.85)
	patch.viewer._set_mode(patch.viewer.Mode.FLY)
	patch.viewer._cam.position = Frame.position(coord.x,altitude,coord.y,patch.viewer._radius())
	patch.viewer._look = Vector2(0,-atan2(maxf(5,entry.height*0.85)-entry.height*0.35,distance))
	patch.viewer._apply_look()

func add_entry(title: String, model: Node3D, coord: Vector2, height: float) -> void:
	var root := Node3D.new()
	root.name = title.replace(" ", "")
	patch.add_child(root)
	root.add_child(model)
	model.show()
	# Imported animation players must not shift the static proof away from its bind pose.
	for player in model.find_children("*", "AnimationPlayer", true, false):
		player.stop()
	model.process_mode = Node.PROCESS_MODE_DISABLED
	var label := Label3D.new()
	label.text = title + " / STATIC"
	label.position.y = height+1.2
	label.font_size = 32
	label.pixel_size = 0.018
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	var footprint := Vector2.ZERO
	if title == "Warthog": footprint = Vector2(1.05,1.55)
	if title == "Altay tank": footprint = Vector2(1.5,2.7)
	if title == "Frontier relay": footprint = Vector2(2.5,3.5)
	if footprint == Vector2.ZERO:
		patch.markers.append(root)
		patch.anchors.append(coord)
	entries.append({"name":title,"root":root,"model":model,"coord":coord,"height":height,
		"footprint":footprint,"label":label,"support":{}})
	patch.reground()

func reground_footprints() -> void:
	var lines := ImmediateMesh.new()
	if entries.is_empty():
		return
	var count := 0
	for entry in entries:
		if entry.footprint == Vector2.ZERO:
			continue
		var result: Dictionary = Support.fit(patch,entry.coord,entry.footprint,entry.name != "Frontier relay")
		entry.support = result
		if not result.valid:
			entry.label.text = entry.name + " / UNSUPPORTED FOOTPRINT"
			continue
		entry.root.transform = result.transform
		entry.label.text = "%s / STATIC\nfootprint gap %.2fm%s" % [entry.name,result.max_gap,
			" / UNEVEN" if result.max_gap > 0.25 else ""]
		for sample in result.samples:
			if count == 0:
				lines.surface_begin(Mesh.PRIMITIVE_LINES)
			var color := Color.ORANGE if sample.gap > 0.25 else Color.GREEN
			if sample.gap < -0.02: color = Color.RED
			lines.surface_set_color(color)
			lines.surface_add_vertex(sample.ground)
			lines.surface_set_color(color)
			lines.surface_add_vertex(sample.point+Frame.up(entry.coord.x,patch.viewer._radius())*0.15)
			count += 1
	if count > 0:
		lines.surface_end()
		contact_debug.mesh = lines
	else:
		contact_debug.mesh = null

func import_source(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var error: int
	if path.ends_with(".zip"):
		# Reuse the preserved archive in memory; no extraction or new asset copies.
		var zip := ZIPReader.new()
		if zip.open(path) != OK:
			return null
		var data = JSON.parse_string(zip.read_file("scene.gltf").get_string_from_utf8())
		if not data is Dictionary:
			zip.close()
			return null
		for group in ["buffers","images"]:
			for entry in data.get(group,[]):
				var uri: String = entry.get("uri","")
				if uri.is_empty() or uri.begins_with("data:"):
					continue
				var bytes := zip.read_file(uri.uri_decode())
				if bytes.is_empty():
					zip.close()
					return null
				var mime := "application/octet-stream" if group == "buffers" else ("image/jpeg" if uri.ends_with(".jpg") else "image/png")
				entry["uri"] = "data:"+mime+";base64,"+Marshalls.raw_to_base64(bytes)
		zip.close()
		error = doc.append_from_buffer(JSON.stringify(data).to_utf8_buffer(),"",state)
	else:
		error = doc.append_from_file(path,state)
	if error != OK:
		return null
	return doc.generate_scene(state) as Node3D

func model_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array = [[root,Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var transform: Transform3D = item[1]
		if node is Node3D:
			transform *= node.transform
		if node is MeshInstance3D and node.mesh:
			var box: AABB = transform * node.mesh.get_aabb()
			result = result.merge(box) if found else box
			found = true
		for child in node.get_children():
			stack.append([child,transform])
	return result

func make_relay() -> Node3D:
	# Extracted dimensions/layout from first-operation/study.gd build_fob:
	# relay only, translated from z=-32 to the local anchor. No mission dependencies.
	var root := Node3D.new()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.34,0.35,0.30)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16,0.20,0.22)
	metal.metallic = 0.4
	var purple := StandardMaterial3D.new()
	purple.albedo_color = Color(0.59,0.3,0.94)
	for spec in [[Vector3(0,1,0),Vector3(5,2,4),stone],
		[Vector3(0,8,0),Vector3(4,0.5,1),metal],
		[Vector3(0,8,-0.55),Vector3(3.4,0.12,0.08),purple],
		[Vector3(0,0.8,3.2),Vector3(1.2,1.6,0.6),metal]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[1]
		mesh.mesh = box
		mesh.position = spec[0]
		mesh.material_override = spec[2]
		root.add_child(mesh)
	var mast := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.17
	cylinder.bottom_radius = 0.17
	cylinder.height = 7
	mast.mesh = cylinder
	mast.position.y = 5
	mast.material_override = metal
	root.add_child(mast)
	return root
