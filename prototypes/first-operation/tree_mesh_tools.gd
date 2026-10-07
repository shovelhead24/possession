extends RefCounted
const TREE_LODS=4
var _foliage_shader=preload("res://tree_foliage.gdshader")
var _prepared: Dictionary={}
func _rel_xform(node: Node3D, root: Node3D) -> Transform3D:
	var result=node.transform
	var parent=node.get_parent()
	while parent and parent!=root:
		result=parent.transform*result;parent=parent.get_parent()
	return root.transform*result
func _prep_material(mat: Material) -> Material:
	if mat and _prepared.has(mat.get_instance_id()): return _prepared[mat.get_instance_id()]
	# foliage/billboard surfaces -> the soft wrapped-lighting foliage shader (kills the blown-out
	# up-facing billboard cap). Bark keeps its opaque StandardMaterial (real shape/shading).
	if mat is BaseMaterial3D:
		var nm := mat.resource_name.to_lower()
		if "brunch" in nm or "branch" in nm or "billboard" in nm or "leaf" in nm or "leaves" in nm or "needle" in nm:
			var tex: Texture2D = (mat as BaseMaterial3D).albedo_texture
			if tex and _foliage_shader:
				var image=tex.get_image()
				if image and not image.has_mipmaps():
					image.generate_mipmaps();tex=ImageTexture.create_from_image(image)
				var sm := ShaderMaterial.new()
				sm.shader = _foliage_shader
				sm.set_shader_parameter("tex", tex)
				_prepared[mat.get_instance_id()]=sm
				return sm
			var m := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			if m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			return m
	return mat

func _append_surfaces(out: ArrayMesh, src: Mesh, xf: Transform3D) -> void:
	for s in src.get_surface_count():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(src, s, xf)
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, _prep_material(src.surface_get_material(s)))

func _rebake(out: ArrayMesh, src: Mesh, xf: Transform3D) -> void:
	for s in src.get_surface_count():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(src, s, xf)
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))

func _billboard_from(src: Mesh) -> ArrayMesh:
	# two crossed quads, unit height, origin at the base -- 4 triangles against the pack's ~16, and
	# it inherits the source material so it still reads as the same tree at distance.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.34
	for pair in [[Vector3(-w, 0, 0), Vector3(w, 0, 0)], [Vector3(0, 0, -w), Vector3(0, 0, w)]]:
		var a: Vector3 = pair[0]
		var b: Vector3 = pair[1]
		var at := a + Vector3(0, 1, 0)
		var bt := b + Vector3(0, 1, 0)
		st.set_uv(Vector2(0, 1)); st.add_vertex(a)
		st.set_uv(Vector2(0, 0)); st.add_vertex(at)
		st.set_uv(Vector2(1, 1)); st.add_vertex(b)
		st.set_uv(Vector2(1, 1)); st.add_vertex(b)
		st.set_uv(Vector2(0, 0)); st.add_vertex(at)
		st.set_uv(Vector2(1, 0)); st.add_vertex(bt)
	st.generate_normals()
	var m := st.commit()
	var sm := src.surface_get_material(0)
	if sm != null:
		m.surface_set_material(0, sm)
	return m

func _normalize_mesh(src: ArrayMesh) -> ArrayMesh:
	# scale each LOD independently to unit height, base at y=0, centred on X/Z — so all LODs of a
	# tree render the SAME size regardless of their intrinsic mesh scale (fixes LOD0-too-small /
	# position-jump-on-switch bugs found in the object-lod mock).
	if src == null: return null
	var ab := src.get_aabb()
	var s := 1.0 / maxf(ab.size.y, 0.001)
	var pivot := Vector3(ab.position.x + ab.size.x * 0.5, ab.position.y, ab.position.z + ab.size.z * 0.5)
	var xf := Transform3D(Basis().scaled(Vector3(s, s, s)), -pivot * s)
	var out := ArrayMesh.new()
	_rebake(out, src, xf)
	return out

func _walk_lod_meshes(node: Node, root: Node, re: RegEx, by_variant: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh:
		var m := re.search(node.name)
		if m:
			var vname := m.get_string(1)
			var lod := int(m.get_string(2))
			if lod < TREE_LODS:
				if not by_variant.has(vname): by_variant[vname] = {}
				if not by_variant[vname].has(lod): by_variant[vname][lod] = ArrayMesh.new()
				_append_surfaces(by_variant[vname][lod], node.mesh, _rel_xform(node, root))
	for c in node.get_children():
		_walk_lod_meshes(c, root, re, by_variant)
