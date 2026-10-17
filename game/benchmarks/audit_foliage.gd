extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var variants=preload("res://world/tree_patch_assets.gd").new().load_meshes()
	for species in variants:
		for lod in 4:
			var mesh=variants[species][lod]
			for surface in mesh.get_surface_count():
				var arrays=mesh.surface_get_arrays(surface);var mat=mesh.surface_get_material(surface)
				var row={"species":species,"lod":lod,"surface":surface,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"triangles":arrays[Mesh.ARRAY_INDEX].size()/3,"material":mat.get_class(),"name":mat.resource_name}
				if mat is ShaderMaterial:
					var img=mat.get_shader_parameter("tex").get_image();if img.is_compressed(): img.decompress()
					var occupied=0;var total=0;var cut=mat.get_shader_parameter("cut")
					for y in range(0,img.get_height(),8):
						for x in range(0,img.get_width(),8):
							total+=1
							if img.get_pixel(x,y).a>=cut: occupied+=1
					row["coverage"]=float(occupied)/total;row["cut"]=cut;row["texture"]=str(img.get_size())
				var seen={};var duplicates=0
				var idx=arrays[Mesh.ARRAY_INDEX];var verts=arrays[Mesh.ARRAY_VERTEX];var uv=arrays[Mesh.ARRAY_TEX_UV]
				for i in range(0,idx.size(),3):
					var points=[]
					for j in 3: points.append(str(verts[idx[i+j]])+str(uv[idx[i+j]]))
					points.sort();var key=str(points)
					if seen.has(key): duplicates+=1
					seen[key]=true
				row["coincident_triangles"]=duplicates
				print("FOLIAGE_ASSET ",JSON.stringify(row))
	quit()
