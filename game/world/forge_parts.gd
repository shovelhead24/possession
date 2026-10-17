extends RefCounted
## Shared, centred modular meshes and matching analytic collision shapes.
static var cache := {}
const COLOR_NAMES := ["Stone","Steel","Sand","White","Red","Orange","Yellow","Green","Teal","Blue","Purple","Charcoal"]
const COLORS := [Color(.53,.57,.60),Color(.22,.29,.35),Color(.65,.55,.38),Color(.88,.90,.92),Color(.75,.12,.12),Color(.95,.35,.07),Color(.95,.76,.1),Color(.18,.55,.25),Color(.08,.58,.58),Color(.12,.32,.8),Color(.5,.18,.7),Color(.08,.095,.11)]
const NAMES := {"wall":"Wall · 4 × 3 m","wall_long":"Long wall · 8 × 3 m","door":"Doorway · 2 m opening","window":"Window wall","floor":"Floor · 4 × 4 m","floor_large":"Floor · 8 × 8 m","ramp":"Ramp · 4 m / 2 m rise","block":"Block · 2 m","pillar":"Pillar · 3 m","building":"Building · 12 × 14 m"}

static func box(size: Vector3, position := Vector3.ZERO) -> Dictionary:
	var shape := BoxShape3D.new();shape.size=size
	return {"shape":shape,"pose":Transform3D(Basis.IDENTITY,position)}

static func get_part(kind: String) -> Dictionary:
	if cache.has(kind): return cache[kind]
	var pieces: Array=[];var size := Vector3.ONE
	match kind:
		"wall": size=Vector3(4,3,.25);pieces=[box(size)]
		"wall_long": size=Vector3(8,3,.25);pieces=[box(size)]
		"floor": size=Vector3(4,.25,4);pieces=[box(size)]
		"floor_large": size=Vector3(8,.25,8);pieces=[box(size)]
		"block": size=Vector3(2,2,2);pieces=[box(size)]
		"pillar": size=Vector3(.5,3,.5);pieces=[box(size)]
		"door":
			size=Vector3(4,3,.25)
			pieces=[box(Vector3(1,3,.25),Vector3(-1.5,0,0)),box(Vector3(1,3,.25),Vector3(1.5,0,0)),box(Vector3(2,.5,.25),Vector3(0,1.25,0))]
		"window":
			size=Vector3(4,3,.25)
			pieces=[box(Vector3(1,3,.25),Vector3(-1.5,0,0)),box(Vector3(1,3,.25),Vector3(1.5,0,0)),box(Vector3(2,.75,.25),Vector3(0,1.125,0)),box(Vector3(2,1,.25),Vector3(0,-1,0))]
		"building":
			var source := Node3D.new();preload("res://world/arena_compounds.gd").new().building(source,Vector3.ZERO)
			var bounds := AABB();var first := true
			for child in source.get_children():
				var b: AABB=child.transform*child.mesh.get_aabb()
				bounds=b if first else bounds.merge(b);first=false
			size=bounds.size
			for child in source.get_children(): pieces.append(box(child.mesh.size,child.position-bounds.get_center()))
			source.free()
		"ramp":
			size=Vector3(4,2,4)
			var shape := ConvexPolygonShape3D.new()
			shape.points=PackedVector3Array([Vector3(-2,-1,-2),Vector3(2,-1,-2),Vector3(2,-1,2),Vector3(-2,-1,2),Vector3(-2,1,-2),Vector3(2,1,-2)])
			pieces=[{"shape":shape,"pose":Transform3D.IDENTITY}]
	var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind=="ramp":
		var v: PackedVector3Array=pieces[0].shape.points
		for face in [[0,3,2,1],[0,1,5,4],[0,4,3],[1,2,5],[4,5,2,3]]:
			for i in range(1,face.size()-1):
				var a: Vector3=v[face[0]];var b: Vector3=v[face[i]];var c: Vector3=v[face[i+1]]
				var normal := (b-a).cross(c-a).normalized()
				if normal.dot((a+b+c)/3-Vector3(0,-.3,0))<0: normal=-normal
				if (b-a).cross(c-a).dot(normal)>0:
					var temp := b;b=c;c=temp
				for vertex in [a,b,c]: surface.set_normal(normal);surface.add_vertex(vertex)
	else:
		for piece in pieces:
			var mesh := BoxMesh.new();mesh.size=piece.shape.size
			surface.append_from(mesh,0,piece.pose)
	var result := {"mesh":surface.commit(),"size":size,"pieces":pieces}
	cache[kind]=result;return result

static func support(basis: Basis, size: Vector3, normal: Vector3) -> float:
	return (absf(normal.dot(basis.x))*size.x+absf(normal.dot(basis.y))*size.y+absf(normal.dot(basis.z))*size.z)*.5

static func face_center(target: Transform3D, size: Vector3, normal: Vector3) -> Vector3:
	var local := target.basis.inverse()*normal
	var axis := local.abs().max_axis_index()
	return target.origin+target.basis[axis]*size[axis]*.5*(1 if local[axis]>=0 else -1)

static func snap_face(target: Transform3D, target_size: Vector3, moving_basis: Basis, moving_size: Vector3, normal: Vector3, aimed_point: Vector3=Vector3.INF, center_faces: bool=false) -> Transform3D:
	var local := target.basis.inverse()*normal
	var axis := local.abs().max_axis_index()
	var world_normal := target.basis[axis]*(1 if local[axis]>=0 else -1)
	var centre := face_center(target,target_size,normal)
	if center_faces:
		var facing := moving_basis.inverse()*(-world_normal)
		var moving_axis := facing.abs().max_axis_index()
		var offset := moving_basis[moving_axis]*moving_size[moving_axis]*.5*(1 if facing[moving_axis]>=0 else -1)
		return Transform3D(moving_basis,centre-offset)
	var anchor := centre if aimed_point==Vector3.INF else aimed_point-world_normal*(aimed_point-centre).dot(world_normal)
	return Transform3D(moving_basis,anchor+world_normal*support(moving_basis,moving_size,world_normal))

# Align the projected boundary of the moving box to the camera-nearest edge
# of the contacted target face. No rotation or world-axis assumptions.
static func snap_edge(target: Transform3D, target_size: Vector3, moving: Transform3D, moving_size: Vector3, normal: Vector3, camera: Vector3) -> Dictionary:
	var local := target.basis.inverse()*normal
	var face_axis := local.abs().max_axis_index()
	var centre := face_center(target,target_size,normal)
	var relative := target.basis.inverse()*(moving.origin-target.origin)
	for axis in 3:
		if axis==face_axis: continue
		if absf(relative[axis])>target_size[axis]*.5+support(moving.basis,moving_size,target.basis[axis])+.001: return {}
	var best := INF
	var result := {}
	for axis in 3:
		if axis==face_axis: continue
		var along := 3-face_axis-axis
		for sign_value in [-1.0,1.0]:
			var edge_centre: Vector3= centre+target.basis[axis]*target_size[axis]*.5*sign_value
			var half_edge := target.basis[along]*target_size[along]*.5
			var a: Vector3=edge_centre-half_edge;var b: Vector3= edge_centre+half_edge
			var distance := camera.distance_squared_to(Geometry3D.get_closest_point_to_segment(camera,a,b))
			if distance>=best: continue
			best=distance
			var outward: Vector3= target.basis[axis]*sign_value
			var desired: float= edge_centre.dot(outward)-support(moving.basis,moving_size,outward)
			var pose := moving;pose.origin+=outward*(desired-moving.origin.dot(outward))
			result={"pose":pose,"a":a,"b":b}
	return result


static func boxes_overlap(a: Transform3D, a_size: Vector3, b: Transform3D, b_size: Vector3) -> bool:
	var axes: Array[Vector3]=[a.basis.x,a.basis.y,a.basis.z,b.basis.x,b.basis.y,b.basis.z]
	for i in 3:
		for j in 3: axes.append(a.basis[i].cross(b.basis[j]))
	for axis in axes:
		if axis.length_squared()<.000001: continue
		axis=axis.normalized()
		if absf((b.origin-a.origin).dot(axis))>support(a.basis,a_size,axis)+support(b.basis,b_size,axis)+.02: return false
	return true
