extends SceneTree
class Patch extends Node3D:
	var ring_background: Node3D

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): push_error("Tree cache timeout");quit(1))
	run.call_deferred()

func run() -> void:
	var patch := Patch.new();root.add_child(patch)
	patch.ring_background=load("res://world/arena_ring_background.gd").new();patch.add_child(patch.ring_background)
	var content=load("res://world/arena_content.gd").new();patch.add_child(content);content.patch=patch
	content.add_child(content.contact_debug)
	var started := Time.get_ticks_msec()
	var original: Dictionary=content.prepared_tree_meshes()
	var first_ms := Time.get_ticks_msec()-started
	started=Time.get_ticks_msec()
	var warm: Dictionary=content.prepared_tree_meshes()
	assert(not original.is_empty() and original.keys()==warm.keys())
	for name in original:
		assert(original[name].size()==4 and warm[name].size()==4)
		for lod in 4:
			var a: Mesh=original[name][lod];var b: Mesh=warm[name][lod]
			assert(a.get_surface_count()==b.get_surface_count())
			for surface in a.get_surface_count():
				assert(a.surface_get_arrays(surface)==b.surface_get_arrays(surface),"Cached tree geometry differs")
				assert(b.surface_get_material(surface)!=null,"Cached tree lost material")
		assert(warm[name][3]==warm[name][2],"Far tree must retain atlas-safe source geometry")
	print("TREE_CACHE_PASS variants=",warm.size()," first_ms=",first_ms," warm_ms=",Time.get_ticks_msec()-started)
	patch.queue_free();await process_frame;quit()
