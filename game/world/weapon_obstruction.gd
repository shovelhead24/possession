extends RefCounted
## Per-shot tests against streamed static geometry without expanding live physics.
const Ring=preload("res://world/terrain_drive_ring.gd")
const Parts=preload("res://world/forge_parts.gd")
const Store=preload("res://world/forge_store.gd")

static func convex_segment(start: Vector3, end: Vector3, planes: Array) -> Dictionary:
	var direction := end-start;var near := 0.0;var far := 1.0;var normal := Vector3.ZERO
	for plane in planes:
		var distance: float=plane.normal.dot(start)-plane.d
		var speed: float=plane.normal.dot(direction)
		if absf(speed)<.0000001:
			if distance>0: return {}
			continue
		var t := -distance/speed
		if speed<0:
			if t>near: near=t;normal=plane.normal
		else: far=minf(far,t)
		if near>far: return {}
	if near<=.000001 or near>1: return {}
	return {"t":near,"normal":normal.normalized()}

static func box_planes(size: Vector3) -> Array:
	var planes := []
	for axis in 3:
		var n := Vector3.ZERO;n[axis]=1;planes.append(Plane(n,size[axis]*.5));planes.append(Plane(-n,size[axis]*.5))
	return planes

static func cylinder_segment(start: Vector3, end: Vector3, radius: float, height: float) -> Dictionary:
	if start.y>0 and start.y<height and Vector2(start.x,start.z).length_squared()<radius*radius: return {}
	var d := end-start;var candidates := []
	var a := d.x*d.x+d.z*d.z;var b := 2*(start.x*d.x+start.z*d.z);var c := start.x*start.x+start.z*start.z-radius*radius
	var discriminant := b*b-4*a*c
	if a>.0000001 and discriminant>=0:
		for t in [(-b-sqrt(discriminant))/(2*a),(-b+sqrt(discriminant))/(2*a)]:
			var p: Vector3=start+d*t
			if t>0 and t<=1 and p.y>=0 and p.y<=height: candidates.append({"t":t,"normal":Vector3(p.x,0,p.z).normalized()})
	if absf(d.y)>.0000001:
		for y in [0.0,height]:
			var t: float=(y-start.y)/d.y;var p := start+d*t
			if t>0 and t<=1 and p.x*p.x+p.z*p.z<=radius*radius: candidates.append({"t":t,"normal":Vector3.DOWN if y==0 else Vector3.UP})
	var result := {}
	for hit in candidates:
		if result.is_empty() or hit.t<result.t: result=hit
	return result

static func cast(arena: Node3D, start: Vector3, end: Vector3) -> Dictionary:
	var closest := {};var limit := 1.0
	var forge: Node=arena.get("forge")
	if forge and not forge.store.records.is_empty():
		if forge.revision!=forge.store.revision: forge.reindex()
		var cache: Dictionary=forge.get_meta("weapon_geometry",{})
		if cache.get("revision",-1)!=forge.store.revision:
			cache={"revision":forge.store.revision,"parts":{}};forge.set_meta("weapon_geometry",cache)
		var segment := end-start;var squared := segment.length_squared()
		for id in forge.nearby((start+end)*.5,start.distance_to(end)*.5+20):
			if not cache.parts.has(id):
				var record: Dictionary=forge.by_id[id];var pose := Store.pose(record);var part := Parts.get_part(record.kind)
				var entry := {"centre":pose.origin,"radius_squared":part.size.length_squared()*.25,"pieces":[]}
				for piece in part.pieces:
					var transform: Transform3D=pose*piece.pose;var planes: Array
					if piece.shape is BoxShape3D: planes=box_planes(piece.shape.size)
					else:
						planes=box_planes(part.size)
						planes.append(Plane(Vector3(0,1,float(part.size.y)/part.size.z),0))
					entry.pieces.append({"inverse":transform.affine_inverse(),"basis":transform.basis,"planes":planes})
				cache.parts[id]=entry
			var entry: Dictionary=cache.parts[id]
			var t := clampf((entry.centre-start).dot(segment)/maxf(squared,.000001),0,limit)
			if entry.centre.distance_squared_to(start+segment*t)>entry.radius_squared: continue
			for piece in entry.pieces:
				var hit := convex_segment(piece.inverse*start,piece.inverse*end,piece.planes)
				if not hit.is_empty() and hit.t<limit:
					limit=hit.t;closest={"position":start.lerp(end,limit),"normal":piece.basis*hit.normal,"collider":forge,"forge_id":id}
	var trees: Node=arena.get("painted_trees")
	if trees and trees.enabled:
		var length := start.distance_to(end);var direction := (end-start).normalized()
		var candidates: Array=trees.weapon_candidates(start,end) if trees.has_method("weapon_candidates") else trees.candidates
		for item in candidates:
			if not item.valid: continue
			var transform := Transform3D(item.transform.basis.orthonormalized(),item.transform.origin)
			var height: float=item.height*.45;var radius: float=maxf(.12,item.height*.022)
			var centre := transform.origin+transform.basis.y*height*.5
			var t := clampf((centre-start).dot(direction),0,length*limit)
			if centre.distance_squared_to(start+direction*t)>pow(height*.5+radius,2): continue
			var inverse := transform.affine_inverse();var hit := cylinder_segment(inverse*start,inverse*end,radius,height)
			if not hit.is_empty() and hit.t<limit:
				limit=hit.t;closest={"position":start.lerp(end,limit),"normal":transform.basis*hit.normal,"collider":trees}
	return closest
