class_name CageSubdivider
extends RefCounted

# Catmull-Clark subdivision. Works on closed manifold quad-dominant meshes.
# verts: PackedVector3Array
# faces: Array of PackedInt32Array (each face is a list of vertex indices)

static func subdivide(verts: PackedVector3Array, faces: Array, levels: int) -> ArrayMesh:
	var v := verts.duplicate()
	var f := _dup_faces(faces)
	for _i in levels:
		var r := _step(v, f)
		v = r[0]
		f = r[1]
	return _to_mesh(v, f)

static func _step(verts: PackedVector3Array, faces: Array) -> Array:
	var nv := verts.size()

	# Face points
	var face_pts := PackedVector3Array()
	face_pts.resize(faces.size())
	for fi in faces.size():
		var face: PackedInt32Array = faces[fi]
		var c := Vector3.ZERO
		for vi in face:
			c += verts[vi]
		face_pts[fi] = c / face.size()

	# Edge map: "a_b" -> {a, b, face_indices}
	var emap: Dictionary = {}
	for fi in faces.size():
		var face: PackedInt32Array = faces[fi]
		for i in face.size():
			var a: int = face[i]
			var b: int = face[(i + 1) % face.size()]
			var k := _ek(a, b)
			if not emap.has(k):
				emap[k] = {"a": a, "b": b, "fi": []}
			emap[k]["fi"].append(fi)

	# Edge points
	var epts: Dictionary = {}
	for k in emap:
		var e: Dictionary = emap[k]
		var mid := (verts[e.a] + verts[e.b]) * 0.5
		if e.fi.size() == 2:
			epts[k] = (mid + (face_pts[e.fi[0]] + face_pts[e.fi[1]]) * 0.5) * 0.5
		else:
			epts[k] = mid

	# Per-vertex adjacency
	var vf: Array = []
	var ve: Array = []
	for _i in nv:
		vf.append([])
		ve.append([])
	for fi in faces.size():
		var face: PackedInt32Array = faces[fi]
		for vi in face:
			vf[vi].append(fi)
	for k in emap:
		var e: Dictionary = emap[k]
		ve[e.a].append(k)
		ve[e.b].append(k)

	# Updated original vertex positions
	var new_v := PackedVector3Array()
	new_v.resize(nv)
	for vi in nv:
		var n: int = vf[vi].size()
		if n == 0:
			new_v[vi] = verts[vi]
			continue
		var F := Vector3.ZERO
		for fi in vf[vi]:
			F += face_pts[fi]
		F /= n
		var R := Vector3.ZERO
		for k in ve[vi]:
			var e: Dictionary = emap[k]
			R += (verts[e.a] + verts[e.b]) * 0.5
		R /= ve[vi].size()
		new_v[vi] = (F + 2.0 * R + (n - 3.0) * verts[vi]) / n

	# Append face points then edge points
	var fp_start := new_v.size()
	for fp in face_pts:
		new_v.append(fp)

	var ep_start := new_v.size()
	var eidx: Dictionary = {}
	var ei := 0
	for k in emap:
		new_v.append(epts[k])
		eidx[k] = ep_start + ei
		ei += 1

	# Build new quad faces (each original n-gon → n quads)
	var new_f: Array = []
	for fi in faces.size():
		var face: PackedInt32Array = faces[fi]
		var ns := face.size()
		var fpi := fp_start + fi
		for i in ns:
			var a: int = face[i]
			var b: int = face[(i + 1) % ns]
			var pa: int = face[(i - 1 + ns) % ns]
			var e1: int = eidx[_ek(a, b)]
			var e0: int = eidx[_ek(pa, a)]
			new_f.append(PackedInt32Array([a, e1, fpi, e0]))

	return [new_v, new_f]

static func _to_mesh(verts: PackedVector3Array, faces: Array) -> ArrayMesh:
	# Indexed mesh with smooth normals
	var tri_idx := PackedInt32Array()
	for face: PackedInt32Array in faces:
		for i in range(1, face.size() - 1):
			tri_idx.append(face[0])
			tri_idx.append(face[i])
			tri_idx.append(face[i + 1])

	var norms := PackedVector3Array()
	norms.resize(verts.size())

	for i in range(0, tri_idx.size(), 3):
		var ia := tri_idx[i]
		var ib := tri_idx[i + 1]
		var ic := tri_idx[i + 2]
		var n := (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
		norms[ia] += n
		norms[ib] += n
		norms[ic] += n
	for i in norms.size():
		norms[i] = norms[i].normalized()

	var arr := Array()
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX]  = tri_idx

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

static func _ek(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]

static func _dup_faces(faces: Array) -> Array:
	var out: Array = []
	for f in faces:
		out.append(PackedInt32Array(f))
	return out
