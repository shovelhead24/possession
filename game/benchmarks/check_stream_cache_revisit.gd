extends SceneTree
const Stream=preload("res://world/terrain_drive_stream.gd")
const Destruction=preload("res://world/terrain_drive_destruction.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
const Recipe=preload("res://world/sdf_recipe.gd")
class Source extends RefCounted:
	var identity := "stream-cache-regression"
	var base_hash := "stream-cache-regression"
	var features := []
	var curve_to_ring := true
	func base_field(p: Vector3,_r: float,_rough: float) -> float: return p.y
	func surface_height(_p: Vector2) -> float: return 0.0
	func build_tile(_key: Vector2i) -> Dictionary:
		var result := {"vertices":PackedVector3Array([Vector3(0,0,0),Vector3(0,0,200),Vector3(200,0,0),Vector3(200,0,200)]),"normals":PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP,Vector3.UP]),"indices":PackedInt32Array([0,1,2,2,1,3]),"render_lods":{},"cached":true}
		Ring.warp_mesh(result);return result
class Arena extends Node3D:
	var source := Source.new()
	var ready_to_play := true
	var tile_entries := {}
	var tiles := []
	var material := StandardMaterial3D.new()
	var destruction: Node
	var streamer: Node
func require(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var arena := Arena.new();root.add_child(arena)
	var edit := Destruction.new();arena.destruction=edit;edit.arena=arena;arena.add_child(edit);edit.set_process(false);edit.set_physics_process(false)
	var stream := Stream.new();arena.streamer=stream;stream.arena=arena;arena.add_child(stream);stream.set_process(false);stream.set_physics_process(false);stream.plan_clock=10000
	# Existing edits elsewhere make streaming use the edit cache, even for untouched tiles.
	var distant := Recipe.feature("carve",Vector3(1000,0,1000));distant.radius=2;edit.cuts=[distant]
	for cycle in 32:
		stream.stage=stream.build(Vector2i.ZERO)
		if not require(not stream.stage.has("visual") and not stream.stage.has("body") and not stream.stage.has("next_collision"),"Cached tile leaked completed publication state on revisit %d" % cycle): return
		for i in 5: stream._process(.016)
		if not require(stream.stage.is_empty() and not stream.publish.is_empty(),"Collision staging did not finish"): return
		stream._physics_process(.016)
		if not require(arena.tile_entries.size()==1 and arena.tile_entries[Vector2i.ZERO].body.get_child_count()==2,"Published collision missing"): return
		# Queue an edit while another streaming job is staged; it must finish afterward.
		if cycle==31:
			stream.stage=stream.build(Vector2i(1,0))
			var feature := Recipe.feature("carve",Vector3(3,0,3));feature.radius=1
			if not require(edit.request_feature(feature),"Edit request rejected"): return
			edit._process(.016)
			if not require(edit.busy() and edit.worker==null,"Edit must wait for staged streaming publication"): return
			for i in 5: stream._process(.016)
			stream._physics_process(.016)
			for tick in 600:
				edit._process(.016);edit._physics_process(.016)
				if not edit.busy(): break
				await process_frame
			if not require(not edit.busy() and edit.publications==1 and edit.applied_revision==edit.revision,"Terrain edit failed to drain after revisits"): return
		var old: Dictionary=arena.tile_entries[Vector2i.ZERO];old.visual.free();old.body.free();arena.tiles.clear();arena.tile_entries.clear()
	print("STREAM_CACHE_PASS: 32 tile retire/revisit cycles, clean cached data, collision publication, subsequent edit queue drained")
	arena.free();quit()


