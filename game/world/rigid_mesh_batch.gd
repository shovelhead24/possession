extends RefCounted
## Batch only explicitly rigid subtrees, preserving independent rig pivots.
static func combine(root: Node3D, excluded: Array, identity: String) -> void:
	var groups := {};var sources := [];var signature := []
	var stack: Array=[[root,Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array=stack.pop_back();var node: Node=item[0];var transform: Transform3D=item[1]
		if node!=root and (node in excluded or (node is Node3D and not node.visible)): continue
		if node is MeshInstance3D and node.mesh is ArrayMesh and not node.skin:
			var eligible: bool=node.mesh.get_blend_shape_count()==0
			for surface in node.mesh.get_surface_count():
				if node.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: eligible=false
			if eligible:
				sources.append(node);signature.append([str(root.get_path_to(node)),str(transform)])
				for surface in node.mesh.get_surface_count():
					var material: Material=node.get_active_material(surface)
					if not groups.has(material): groups[material]=[]
					groups[material].append([node.mesh,surface,transform])
		for child in node.get_children():
			stack.append([child,transform*child.transform if child is Node3D else transform])
	if sources.size()<2: return
	var tag := FileAccess.get_file_as_string("res://world/rigid_mesh_batch.gd").sha256_text()
	var folder := "user://rigid_mesh_batches/";DirAccess.make_dir_recursive_absolute(folder)
	var path := folder+(identity+tag+JSON.stringify(signature)).sha256_text()+".bin"
	var cached: Array=[]
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		if file:
			var data: Variant=file.get_var()
			if data is Array and data.size()==groups.size(): cached=data
	var result := [];var index := 0
	for material in groups:
		var arrays: Array;var lods: Dictionary
		if not cached.is_empty():
			arrays=cached[index].arrays;lods=cached[index].lods
		else:
			var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for part in groups[material]: surface.append_from(part[0],part[1],part[2])
			arrays=surface.commit_to_arrays()
			var importer := ImporterMesh.new();importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
			importer.generate_lods(60.0,0.0,[]);lods={}
			for level in importer.get_surface_lod_count(0): lods[importer.get_surface_lod_size(0,level)]=importer.get_surface_lod_indices(0,level)
		var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods)
		var draw := MeshInstance3D.new();draw.name="RigidMaterialBatch"+str(index);draw.mesh=mesh;draw.material_override=material;root.add_child(draw)
		result.append({"arrays":arrays,"lods":lods});index+=1
	# Preserve original nodes for rig references; only their draws are replaced.
	for node in sources: node.layers=0
	if cached.is_empty():
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file: file.store_var(result)
	print("RIGID_MESH_BATCH sources=",sources.size()," draws=",groups.size()," cached=",not cached.is_empty())
