extends RefCounted
## Cache only generated index levels: source vertices, materials and rig hierarchy
## remain authoritative. Skinned/blend-shaped meshes require separate validation.
static func prepare(state: GLTFState, path: String, allow_skinned := false) -> void:
	var started := Time.get_ticks_usec()
	var identity: String=("actor-lod-v1|" if allow_skinned else "vehicle-lod-v1|")+Engine.get_version_info().string+"|"+FileAccess.get_sha256(path)
	var directory := "user://vehicle_mesh_lod"
	DirAccess.make_dir_recursive_absolute(directory)
	var cache_path := directory+"/"+identity.sha256_text()+".bin"
	var cached: Dictionary={}
	if FileAccess.file_exists(cache_path):
		var input := FileAccess.open(cache_path,FileAccess.READ)
		if input:
			var data: Variant=input.get_var()
			if data is Dictionary: cached=data
	var result := {};var generated := 0;var hits := 0;var levels := 0
	var meshes := state.get_meshes()
	for index in meshes.size():
		var mesh: ImporterMesh=meshes[index].mesh
		if mesh==null or mesh.get_blend_shape_count()>0: continue
		var eligible := true
		for surface in mesh.get_surface_count():
			var arrays := mesh.get_surface_arrays(surface)
			if not allow_skinned and arrays[Mesh.ARRAY_BONES]!=null and not arrays[Mesh.ARRAY_BONES].is_empty(): eligible=false
		if not eligible: continue
		var saved: Array=cached.get(index,[])
		if saved.size()!=mesh.get_surface_count():
			mesh.generate_lods(60.0,0.0,[]);generated+=1;saved=[]
			for surface in mesh.get_surface_count():
				var lods := {}
				for level in mesh.get_surface_lod_count(surface):
					lods[mesh.get_surface_lod_size(surface,level)]=mesh.get_surface_lod_indices(surface,level)
				saved.append(lods)
		else:
			# Rebuild the importer mesh with cached indices before scene conversion.
			var replacement := ImporterMesh.new()
			for surface in mesh.get_surface_count():
				replacement.add_surface(mesh.get_surface_primitive_type(surface),mesh.get_surface_arrays(surface),[],saved[surface],mesh.get_surface_material(surface),mesh.get_surface_name(surface),mesh.get_surface_format(surface))
			meshes[index].mesh=replacement;hits+=1
		result[index]=saved
		for lods in saved: levels+=lods.size()
	if generated>0:
		var output := FileAccess.open(cache_path,FileAccess.WRITE)
		if output: output.store_var(result)
	print("VEHICLE_MESH_LOD ",path.get_file()," generated=",generated," cached=",hits," levels=",levels," ms=",(Time.get_ticks_usec()-started)/1000.0)
