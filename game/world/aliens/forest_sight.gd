extends RefCounted
## Optical cover from intersected crowns. No new collision bodies or leaf rays.
static func chord(start: Vector3, end: Vector3, centre: Vector3, radii: Vector3) -> float:
	var origin=(start-centre)/radii
	var direction=(end-start)/radii
	var a=direction.dot(direction)
	if a<.000001: return 0.0
	var b=origin.dot(direction)
	var disc=b*b-a*(origin.dot(origin)-1.0)
	if disc<=0: return 0.0
	var near=maxf(0.0,(-b-sqrt(disc))/a)
	var far=minf(1.0,(-b+sqrt(disc))/a)
	return maxf(0.0,far-near)*start.distance_to(end)

static func depth(trees: Node, start: Vector3, end: Vector3) -> float:
	if not trees or not trees.enabled: return 0.0
	var amount=0.0
	for item in trees.weapon_candidates(start,end,trees.weapon_max_height*.75):
		if not item.valid: continue
		var box: AABB=trees.variants[trees.names[item.variant]][0].get_aabb()
		# Use the upper crown volume; open space under a tall trunk stays visible.
		var centre=box.get_center();centre.y=box.position.y+box.size.y*.60
		var radii=Vector3(maxf(.01,box.size.x*.43),maxf(.01,box.size.y*.38),maxf(.01,box.size.z*.43))
		var inverse: Transform3D=item.transform.affine_inverse()
		amount+=chord(inverse*start,inverse*end,centre,radii)*item.height*.22
		if amount>=3.0: return 3.0
	return amount
