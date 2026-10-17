extends RefCounted
const Ring=preload("res://world/terrain_drive_ring.gd")
var manager: Node
var slots: Array[Vector3]=[]
func refresh() -> void:
	slots.clear()
	var forge=manager.arena.forge
	if forge.revision!=forge.store.revision: forge.reindex()
	for id in forge.nearby(manager.arena.camera.global_position,140):
		var record=forge.by_id[id];var pose=preload("res://world/forge_store.gd").pose(record)
		var size=preload("res://world/forge_parts.gd").get_part(record.kind).size
		for offset in [Vector3(size.x*.5+1,0,0),Vector3(-size.x*.5-1,0,0),Vector3(0,0,size.z*.5+1),Vector3(0,0,-size.z*.5-1)]:
			var ground=manager.ground(pose.origin+pose.basis*offset)
			if not ground.is_empty() and manager.clear_body(ground.position,1.3): slots.append(ground.position)
			if slots.size()>=64: return
func obscures(point: Vector3, threat: Vector3, ids: Array[RID]) -> bool:
	var origin=point+Ring.up_at(point)*.65
	var ray=PhysicsRayQueryParameters3D.create(origin,threat+Ring.up_at(threat)*1.0,7);ray.exclude=ids
	var hit=manager.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.position.distance_to(threat)>2.0
