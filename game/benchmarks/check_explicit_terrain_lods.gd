extends SceneTree
const Pass = preload("res://world/tree_edited_terrain_lods.gd")
class Source extends RefCounted:
	var identity := "explicit-lod-test-"+str(Time.get_ticks_usec())
	var data: Dictionary
	func build_tile(_key: Vector2i) -> Dictionary: return data
class Edits extends RefCounted:
	var revision := 0
	var cuts: Array=[]
	var current_signature := "test"
	func busy() -> bool: return false
	func keys_for(_cuts: Array) -> Array: return [Vector2i.ZERO]
class Patch extends Node:
	var dirty := false
	func update_batches() -> void: pass
class Arena extends Node3D:
	var ready_to_play := true
	var source := Source.new()
	var destruction := Edits.new()
	var tile_entries := {}
	var camera: Camera3D
	var trees := Patch.new()
	var painted_trees := Patch.new()
func _initialize() -> void:
	create_timer(20).timeout.connect(func(): push_error("Explicit LOD test timeout");quit(1))
	run.call_deferred()
func run() -> void:
	var arena := Arena.new();root.add_child(arena);arena.add_child(arena.trees);arena.add_child(arena.painted_trees)
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.position=Vector3(500,20,0)
	var plane := PlaneMesh.new();plane.size=Vector2(200,200);plane.subdivide_width=30;plane.subdivide_depth=30
	var arrays := plane.get_mesh_arrays()
	arena.source.data={"vertices":arrays[Mesh.ARRAY_VERTEX].duplicate(),"normals":arrays[Mesh.ARRAY_NORMAL].duplicate(),"indices":arrays[Mesh.ARRAY_INDEX].duplicate(),"render_lods":{}}
	var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size(): verts[i].y=30*exp(-Vector2(verts[i].x,verts[i].z).length_squared()/1000)
	arrays[Mesh.ARRAY_VERTEX]=verts
	var full := ArrayMesh.new();full.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual := MeshInstance3D.new();visual.mesh=full;arena.add_child(visual)
	var body := StaticBody3D.new();arena.add_child(body)
	arena.tile_entries[Vector2i.ZERO]={"visual":visual,"body":body}
	var pass_node := Pass.new();arena.add_child(pass_node);pass_node.setup(arena)
	while not pass_node.is_edit_hidden(Vector2i.ZERO): await process_frame
	assert(pass_node.published==0 and pass_node.generated_tiles==0 and pass_node.requested.is_empty())
	assert(visual.mesh!=full and visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==arena.source.data.vertices)
	arena.camera.position=Vector3(0,50,0);await create_timer(.4).timeout
	assert(visual.mesh==full and not pass_node.is_edit_hidden(Vector2i.ZERO))
	pass_node.request_build()
	while not pass_node.requested.is_empty() or pass_node.worker: await process_frame
	assert(pass_node.published==1)
	arena.camera.position=Vector3(500,20,0);await create_timer(.4).timeout
	assert(not pass_node.is_edit_hidden(Vector2i.ZERO) and visual.mesh!=full)
	assert(visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==full.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	assert(arena.tile_entries[Vector2i.ZERO].body==body)
	# Re-edit: old bake must not authorize simplification of new terrain.
	var replacement := MeshInstance3D.new();replacement.mesh=full;arena.add_child(replacement)
	arena.tile_entries[Vector2i.ZERO].visual=replacement;visual.queue_free()
	arena.destruction.revision+=1;arena.destruction.current_signature="changed"
	await create_timer(.7).timeout
	assert(pass_node.is_edit_hidden(Vector2i.ZERO) and pass_node.published==1)
	pass_node.request_build();pass_node.stop_build();assert(pass_node.requested.is_empty())
	print("EXPLICIT_LOD_PASS: no automatic generation, distant base fallback, near edit restoration, explicit bake, unchanged vertices/collision, edit invalidation and stop")
	if OS.get_cmdline_user_args().has("--render-panel"):
		pass_node.dialog.popup_centered();await create_timer(.2).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-08/we-x20/outputs/terrain-render-pass.png")
	arena.free();quit()
