extends RefCounted
## Same tetrahedra and interpolation as the reference, with shared edge vertices.
const CORNERS := [Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
const TETS := [[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]

static func build(sample: Callable, origin: Vector3, cells: Vector3i, spacing: float, supplied := PackedFloat32Array(), normal_sampler := Callable()) -> Dictionary:
	var started := Time.get_ticks_usec()
	var nx := cells.x+1
	var ny := cells.y+1
	var count := nx*ny*(cells.z+1)
	var values := PackedFloat32Array();values.resize(count)
	var positions := PackedVector3Array();positions.resize(count)
	for z in cells.z+1:
		for y in ny:
			for x in nx:
				var id := (z*ny+y)*nx+x
				positions[id]=origin+Vector3(x,y,z)*spacing
				values[id]=supplied[id] if not supplied.is_empty() else sample.call(positions[id])
	var sampled_at := Time.get_ticks_usec()
	# Precompute polygon topology once per job, rather than allocating inside/outside
	# lists and edge lists for every tetrahedron.
	var patterns := []
	for mask in 16:
		var inside := [];var outside := [];var edges := []
		for i in 4:
			if mask & (1<<i): inside.append(i)
			else: outside.append(i)
		if not inside.is_empty() and not outside.is_empty():
			if inside.size()==1:
				for b in outside: edges.append(Vector2i(inside[0],b))
			elif outside.size()==1:
				for a in inside: edges.append(Vector2i(a,outside[0]))
			else:
				edges=[Vector2i(inside[0],outside[0]),Vector2i(inside[0],outside[1]),Vector2i(inside[1],outside[1]),Vector2i(inside[1],outside[0])]
		patterns.append({"edges":edges,"inside":inside[0] if not inside.is_empty() else 0,"outside":outside[0] if not outside.is_empty() else 0})
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var edge_vertices := {}
	var ids := PackedInt32Array();ids.resize(8)
	var polygon := PackedInt32Array();polygon.resize(4)
	var slab := nx*ny
	var corner_offsets := PackedInt32Array([0,1,nx+1,nx,slab,slab+1,slab+nx+1,slab+nx])
	for z in cells.z:
		for y in cells.y:
			for x in cells.x:
				var negative := 0
				var base_id := (z*ny+y)*nx+x
				for i in 8:
					ids[i]=base_id+corner_offsets[i]
					if values[ids[i]]<0: negative+=1
				if negative==0 or negative==8: continue
				for tet in TETS:
					var mask := 0
					for i in 4:
						if values[ids[tet[i]]]<0: mask|=1<<i
					if mask==0 or mask==15: continue
					var pattern: Dictionary=patterns[mask]
					var edges: Array=pattern.edges
					for i in edges.size():
						var a: int=ids[tet[edges[i].x]]
						var b: int=ids[tet[edges[i].y]]
						var key := mini(a,b)*count+maxi(a,b)
						if not edge_vertices.has(key):
							edge_vertices[key]=vertices.size()
							vertices.append(positions[a].lerp(positions[b],values[a]/(values[a]-values[b])))
						polygon[i]=edge_vertices[key]
					var outward := positions[ids[tet[pattern.outside]]]-positions[ids[tet[pattern.inside]]]
					for i in range(1,edges.size()-1):
						var a := polygon[0];var b := polygon[i];var c := polygon[i+1]
						var cross := (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])
						if cross.length_squared()<.00000001: continue
						if cross.dot(outward)>0:
							var swap := b;b=c;c=swap
						indices.append(a);indices.append(b);indices.append(c)
	var triangulated_at := Time.get_ticks_usec()
	if indices.is_empty(): vertices.clear()
	var normals := PackedVector3Array();normals.resize(vertices.size())
	var e := .03
	for i in vertices.size():
		var p := vertices[i]
		if normal_sampler.is_valid(): normals[i]=normal_sampler.call(p);continue
		normals[i]=Vector3(sample.call(p+Vector3(e,0,0))-sample.call(p-Vector3(e,0,0)),sample.call(p+Vector3(0,e,0))-sample.call(p-Vector3(0,e,0)),sample.call(p+Vector3(0,0,e))-sample.call(p-Vector3(0,0,e))).normalized()
	var finished := Time.get_ticks_usec()
	return {"vertices":vertices,"normals":normals,"indices":indices,"ms":(finished-started)/1000.0,"profile":{"sample_ms":(sampled_at-started)/1000.0,"triangulate_ms":(triangulated_at-sampled_at)/1000.0,"normal_ms":(finished-triangulated_at)/1000.0,"grid_samples":count,"normal_samples":vertices.size()*6,"unique_vertices":vertices.size(),"triangles":indices.size()/3}}
