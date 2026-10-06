extends RefCounted
## Godot's importer simplifier locks mesh borders. Keep collision/full-detail
## indices intact and cache only additional render index buffers on the worker.
static func prepare(result: Dictionary, identity: String) -> void:
	if result.vertices.is_empty(): return
	var folder := "user://terrain-render-lods-v1/"
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String=folder+(Engine.get_version_info().string+identity).sha256_text()+".bin"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		if file:
			var data: Variant=file.get_var()
			if data is Dictionary:
				result.render_lods=data;return
	var arrays := [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=result.vertices;arrays[Mesh.ARRAY_NORMAL]=result.normals;arrays[Mesh.ARRAY_INDEX]=result.indices
	var importer := ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
	importer.generate_lods(60.0,0.0,[])
	var lods := {}
	for level in importer.get_surface_lod_count(0):
		lods[importer.get_surface_lod_size(0,level)]=importer.get_surface_lod_indices(0,level)
	result.render_lods=lods
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file: file.store_var(lods)
