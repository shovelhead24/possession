extends RefCounted
## Offline-style preparation, cached once; original billboard UVs survive intact.
const ARCHIVE := "res://../assets/realistic_fir_trees_pack_lods_gameready.zip"
const FOLIAGE = preload("res://mocks/tree_foliage.gdshader")
var materials := {}

static func prepare_foliage_image(source: Image) -> Image:
	var img := source.duplicate() as Image
	if img.is_compressed():
		if img.decompress()!=OK: return source
	img.clear_mipmaps()
	# Runtime GLTF textures bypass the normal texture importer's alpha-border
	# correction. Bleed leaf colours into transparent texels BEFORE downsampling.
	img.fix_alpha_edges()
	img.generate_mipmaps()
	return img

func load_meshes() -> Dictionary:
	var path := ProjectSettings.globalize_path(ARCHIVE).simplify_path()
	var identity := FileAccess.get_sha256(path)+FileAccess.get_sha256(get_script().resource_path)+FileAccess.get_sha256(FOLIAGE.resource_path)+str(Engine.get_version_info().hex)
	var cache := "user://tree-patch-"+identity.sha256_text()+".res"
	if FileAccess.file_exists(cache):
		var resource := ResourceLoader.load(cache)
		if resource and resource.has_meta("variants"): return resource.get_meta("variants")
	var importer := preload("res://world/content_gallery.gd").new()
	var source: Node3D=importer.import_source(path)
	importer.contact_debug.free();importer.free()
	if not source: return {}
	var raw := {};var regex := RegEx.new();regex.compile("(?i)^(.+?)_LOD(\\d)")
	walk(source,source,regex,raw)
	source.free()
	var result := {}
	var names := raw.keys();names.sort()
	for name in names:
		var lods: Array[Mesh]=[]
		for lod in 4:
			if not raw[name].has(lod): push_error("Missing tree LOD: "+name);return {}
			var mesh: ArrayMesh=raw[name][lod]
			var box := mesh.get_aabb()
			var scale_factor := 1.0/maxf(box.size.y,.001)
			var pivot := Vector3(box.get_center().x,box.position.y,box.get_center().z)
			var normalized := ArrayMesh.new()
			append(normalized,mesh,Transform3D(Basis().scaled(Vector3.ONE*scale_factor),-pivot*scale_factor))
			lods.append(normalized)
		result[name]=lods
	var resource := Resource.new();resource.set_meta("variants",result)
	var error := ResourceSaver.save(resource,cache)
	if error!=OK: push_warning("Tree cache write failed: "+str(error))
	return result

func walk(node: Node, root: Node3D, regex: RegEx, raw: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh:
		var match_name := regex.search(node.name)
		if match_name:
			var name := match_name.get_string(1);var lod := int(match_name.get_string(2))
			if not raw.has(name): raw[name]={}
			if not raw[name].has(lod): raw[name][lod]=ArrayMesh.new()
			var xf: Transform3D=node.transform;var parent := node.get_parent()
			while parent and parent!=root:
				xf=parent.transform*xf;parent=parent.get_parent()
			append(raw[name][lod],node.mesh,root.transform*xf)
	for child in node.get_children(): walk(child,root,regex,raw)

func append(out: ArrayMesh, mesh: Mesh, xf: Transform3D) -> void:
	for surface in mesh.get_surface_count():
		var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append_from(mesh,surface,xf);st.commit(out)
		var material: Material=mesh.surface_get_material(surface)
		if material is BaseMaterial3D:
			var id := material.get_instance_id()
			if not materials.has(id):
				var name := material.resource_name.to_lower()
				if "brunch" in name or "billboard" in name:
					var texture: Texture2D=material.albedo_texture
					var img := texture.get_image()
					if img: texture=ImageTexture.create_from_image(prepare_foliage_image(img))
					var shader_material := ShaderMaterial.new();shader_material.shader=FOLIAGE
					shader_material.set_shader_parameter("tex",texture)
					shader_material.set_shader_parameter("cut",maxf(.35,material.alpha_scissor_threshold))
					materials[id]=shader_material
				else: materials[id]=material
			material=materials[id]
		out.surface_set_material(out.get_surface_count()-1,material)

static func audit(variants: Dictionary) -> Array:
	var report := []
	for name in variants:
		var levels := []
		for mesh: Mesh in variants[name]:
			var triangles := 0
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size())/3
			levels.append({"triangles":triangles,"surfaces":mesh.get_surface_count(),"bounds":str(mesh.get_aabb())})
		report.append({"variant":name,"lods":levels})
	return report
