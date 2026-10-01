extends RefCounted
## Static footprint fit, not suspension or a stability solver.
const Frame = preload("res://benchmarks/mesh_snapshot/world/ring_frame.gd")

static func fit(tile: Node3D, coord: Vector2, half_size: Vector2, tilt: bool) -> Dictionary:
	var radius: float = tile.viewer._radius()
	var origin: Vector3 = tile.triangle_point(coord)
	var up := Frame.up(coord.x,radius)
	var right := up.cross(Vector3.BACK).normalized()
	var basis := Basis(right,up,Vector3.BACK)
	var offsets: Array[Vector2] = []
	for z in [-1.0,0.0,1.0]:
		for x in [-1.0,0.0,1.0]:
			var offset := Vector2(x*half_size.x,z*half_size.y)
			if not tile.contains(coord+offset):
				return {"valid":false}
			offsets.append(offset)
	if tilt:
		var corners: Array[Vector3] = []
		for i in [0,2,6,8]:
			corners.append(tile.triangle_point(coord+offsets[i]))
		var along_x := ((corners[1]-corners[0])+(corners[3]-corners[2])).normalized()
		var along_z := ((corners[2]-corners[0])+(corners[3]-corners[1])).normalized()
		var normal := along_z.cross(along_x).normalized()
		if normal.dot(up) < 0.1:
			return {"valid":false}
		basis = Basis(normal.cross(along_z).normalized(),normal,along_z).orthonormalized()
	# Re-sample the actual projected support points after rotation. Lift until
	# none of these samples penetrates. Unmodeled ground between samples may do so.
	for iteration in 4:
		var lift := -INF
		for offset in offsets:
			var point := origin + basis*Vector3(offset.x,0,offset.y)
			var ring := Frame.coordinates(point,radius)
			var p := Vector2(ring.x,ring.z)
			if not tile.contains(p):
				return {"valid":false}
			var ground: Vector3 = tile.triangle_point(p)
			lift = maxf(lift,(ground-point).dot(up))
		origin += up*lift
	var samples: Array[Dictionary] = []
	var max_gap := 0.0
	var min_gap := INF
	for offset in offsets:
		var point := origin + basis*Vector3(offset.x,0,offset.y)
		var ring := Frame.coordinates(point,radius)
		var ground: Vector3 = tile.triangle_point(Vector2(ring.x,ring.z))
		var gap := (point-ground).dot(up)
		max_gap = maxf(max_gap,gap)
		min_gap = minf(min_gap,gap)
		samples.append({"point":point,"ground":ground,"gap":gap})
	return {"valid":true,"transform":Transform3D(basis,origin),
		"samples":samples,"max_gap":max_gap,"min_gap":min_gap}
