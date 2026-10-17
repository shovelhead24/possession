extends RefCounted

static func right_axis(front: Vector3, local_up: Vector3, previous: Vector3, delta: float) -> Vector3:
	var horizontal=local_up.cross(front)
	var strength=horizontal.length()
	var right=previous-front*previous.dot(front)
	if right.length_squared()<0.000001:
		if strength>0.001: return horizontal.normalized()
		right=Vector3.RIGHT-front*front.x
		if right.length_squared()<0.000001: right=Vector3.FORWARD-front*front.z
	right=right.normalized()
	# Through zenith retain the previous world orientation. Outside that cone,
	# ease back to the local horizon without a 180-degree sign flip.
	if strength>0.12:
		var target=horizontal.normalized()
		var angle=atan2(front.dot(right.cross(target)),right.dot(target))
		var limit=maxf(delta,0.0)*1.8*smoothstep(0.12,0.45,strength)
		right=right.rotated(front,clampf(angle,-limit,limit))
	return right.normalized()
