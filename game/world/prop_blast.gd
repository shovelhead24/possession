extends RefCounted
## Apply a bounded blast to movable props only; walls shield the impulse.
static func apply(source: Node3D, origin: Vector3, radius := 9.0, strength := 1800.0) -> void:
	var up=preload("res://world/terrain_drive_ring.gd").up_at(origin)
	for prop in source.get_tree().get_nodes_in_group("blast_props"):
		if prop.global_position.distance_to(origin)>=radius: continue
		var ray=PhysicsRayQueryParameters3D.create(origin+up*.15,prop.global_position,7)
		if source is CollisionObject3D: ray.exclude=[source.get_rid()]
		var hit=source.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider!=prop: continue
		prop.blast_impulse(origin,radius,strength)
