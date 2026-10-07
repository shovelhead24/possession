extends Node
## Reuse exact cached opaque terrain, never approximate across cave openings.
## Keep only a small nearby occluder set; physics is completely independent.
var arena: Node
var entries := {}
var clock := 0.0

func _process(delta: float) -> void:
	clock-=delta
	var centre: Vector2i=arena.key_at(arena.camera.position)
	# Remove invalidated occlusion immediately, before publishing edited visuals.
	for key in entries.keys():
		var entry: Dictionary=entries[key]
		if (key-centre).length_squared()>9 or not is_instance_valid(entry.node) or not is_instance_valid(entry.visual) or entry.visual.mesh!=entry.mesh or not arena.chunks.has(key) or arena.chunks[key].revision!=arena.revision or arena.preview_expected.has(key):
			if is_instance_valid(entry.node):
				entry.node.visible=false
				entry.node.queue_free()
			entries.erase(key)
	if clock>0: return
	clock=.25
	for key in entries:
		entries[key].node.visible=(key-centre).length_squared()<=9
	for key in arena.chunks:
		if entries.has(key) or (key-centre).length_squared()>4 or arena.preview_expected.has(key): continue
		if arena.chunks[key].revision!=arena.revision: continue
		for child in arena.chunks[key].node.get_children():
			if not child is MeshInstance3D or not child.mesh or child.mesh.get_surface_count()==0: continue
			var arrays: Array=child.mesh.surface_get_arrays(0)
			var occluder := ArrayOccluder3D.new()
			occluder.set_arrays(arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_INDEX])
			var node := OccluderInstance3D.new();node.occluder=occluder
			arena.chunks[key].node.add_child(node);node.transform=child.transform
			entries[key]={"node":node,"visual":child,"mesh":child.mesh}
			return # At most one new BVH contribution per update.
