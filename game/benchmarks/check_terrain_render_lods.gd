extends SceneTree
const LOD=preload("res://world/terrain_render_lods.gd")

func border_edges(vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var edges := {}
	for i in range(0,indices.size(),3):
		for edge in 3:
			var a: int=indices[i+edge];var b: int=indices[i+(edge+1)%3]
			var p := vertices[a];var q := vertices[b]
			if (p.x==q.x and p.x in [0.0,32.0]) or (p.z==q.z and p.z in [0.0,32.0]):
				edges[Vector2i(mini(a,b),maxi(a,b))]=true
	return edges

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("Terrain render LOD test timeout");quit(1))
	var vertices := PackedVector3Array();var normals := PackedVector3Array();var indices := PackedInt32Array()
	for z in 17:
		for x in 17:
			vertices.append(Vector3(x*2,0,z*2));normals.append(Vector3.UP)
	for z in 16:
		for x in 16:
			var i := z*17+x;indices.append_array([i,i+1,i+17,i+1,i+18,i+17])
	var result := {"vertices":vertices,"normals":normals,"indices":indices}
	LOD.prepare(result,"unit-plane"+FileAccess.get_sha256("res://benchmarks/check_terrain_render_lods.gd"))
	assert(not result.render_lods.is_empty(),"Terrain LODs missing")
	var original := border_edges(vertices,indices)
	for lod in result.render_lods.values():
		assert(lod.size()<indices.size(),"Terrain LOD did not simplify")
		assert(border_edges(vertices,lod)==original,"Terrain LOD changed a shared chunk border")
	assert(result.vertices==vertices and result.indices==indices,"Collision source changed")
	var restored := {"vertices":vertices,"normals":normals,"indices":indices}
	LOD.prepare(restored,"unit-plane"+FileAccess.get_sha256("res://benchmarks/check_terrain_render_lods.gd"))
	assert(restored.render_lods==result.render_lods,"Render LOD cache mismatch")
	for i in vertices.size():
		var p := vertices[i]
		vertices[i].y=3.0*sin(p.x*.15)*cos(p.z*.1)
		normals[i]=Vector3(-.45*cos(p.x*.15)*cos(p.z*.1),1,.3*sin(p.x*.15)*sin(p.z*.1)).normalized()
	var curved := {"vertices":vertices,"normals":normals,"indices":indices}
	LOD.prepare(curved,"unit-curved"+FileAccess.get_sha256("res://benchmarks/check_terrain_render_lods.gd"))
	assert(not curved.render_lods.is_empty())
	for lod in curved.render_lods.values(): assert(border_edges(vertices,lod)==original,"Curved terrain border changed")
	var arrays := [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],curved.render_lods)
	var shape := mesh.create_trimesh_shape();var faces := shape.get_faces()
	assert(faces.size()==indices.size(),"Render LOD changed collision face count")
	var baseline := ArrayMesh.new();baseline.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	assert(faces==baseline.create_trimesh_shape().get_faces(),"Render LOD changed collision geometry")
	print("TERRAIN_RENDER_LOD_PASS full_triangles=",indices.size()/3," levels=",result.render_lods.size()," smallest_triangles=",result.render_lods.values()[0].size()/3," preserved_border_edges=",original.size())
	quit()
