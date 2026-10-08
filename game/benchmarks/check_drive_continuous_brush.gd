extends SceneTree
const Source=preload("res://world/terrain_baseline_source.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
const Edits=preload("res://world/terrain_drive_destruction.gd")
const Editor=preload("res://world/terrain_drive_editor.gd")
const Support=preload("res://benchmarks/check_drive_grenades.gd")
var arena: Node3D
var edits: Node
var editor: Node
var latencies:=[]
var workers:=[]
var last_publication:=0
var failed:=false

func _initialize() -> void:
	Engine.max_fps=120
	create_timer(90).timeout.connect(func(): push_error("CONTINUOUS_BRUSH_TIMEOUT");quit(1))
	run.call_deferred()

func require(ok: bool, message: String) -> void:
	if not ok: failed=true;push_error(message)

func install(key: Vector2i, data: Dictionary) -> void:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_INDEX]=data.indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual:=MeshInstance3D.new();visual.mesh=mesh;arena.add_child(visual)
	var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape);arena.add_child(body)
	arena.tile_entries[key]={"visual":visual,"body":body};arena.tiles.append(visual)

func height(arc: float, lateral: float) -> float:
	var h: float=arena.source.surface_height(Vector2(arc,lateral))
	var query:=PhysicsRayQueryParameters3D.create(Ring.point(arc,h+100,lateral),Ring.point(arc,h-100,lateral),1)
	var hit:Dictionary=arena.get_world_3d().direct_space_state.intersect_ray(query)
	require(not hit.is_empty(),"Brush removed collision")
	return Ring.coordinates(hit.get("position",Vector3.ZERO)).y

func track() -> void:
	if edits.publications!=last_publication:
		last_publication=edits.publications;latencies.append(edits.last_update_ms);workers.append(edits.last_worker_ms)

func drain() -> void:
	while not editor.input_strokes.is_empty() or edits.busy():
		editor.flush_strokes();await process_frame;track()
	await physics_frame;await physics_frame

func run() -> void:
	var source:=Source.new();source.curve_to_ring=true;require(source.initialize(),"DEM missing")
	arena=Support.Fixture.new();arena.source=source;root.add_child(arena)
	edits=Edits.new();edits.arena=arena;arena.destruction=edits;arena.add_child(edits)
	edits.save_path="C:/Users/Bran the builder/Documents/Codex/2026-10-07/co/work/continuous-brush-%d.json" % OS.get_process_id()
	editor=Editor.new();editor.arena=arena;editor.radius=12;editor.strength=4
	for key in [Vector2i(0,1),Vector2i(1,1)]: install(key,source.build_tile(key))
	await physics_frame;await physics_frame
	var base_height:=height(200,300)
	editor.start_stroke(Ring.point(200,base_height,300))
	var intermediate_updates:=0
	for frame in 180:
		editor.active_stroke.brush.dab(Ring.point(200,base_height,300),4.0/60)
		editor.flush_strokes();await physics_frame;track()
		if frame==90: intermediate_updates=edits.publications
	editor.finish_stroke();await drain()
	var increase:=height(200,300)-base_height
	require(absf(increase-(12+4.0/60))<.02,"Held brush dropped time/doses while worker was busy")
	require(edits.cuts.size()==1,"Stationary stroke stacked redundant shapes")
	require(intermediate_updates>=5,"Terrain did not publish progressively during held stroke")
	require(edits.undo_stack.size()==1,"One held stroke produced multiple undo entries")
	edits.undo();await drain();require(absf(height(200,300)-base_height)<.02,"Whole-stroke undo failed")
	edits.redo();await drain();require(absf(height(200,300)-base_height-increase)<.02,"Whole-stroke redo failed")
	# A freehand path crosses a tile seam while workers remain busy. Every small
	# movement is still collected and the original brush interpolates the trail.
	var base_ridge: Array=[]
	for x in range(178,231,4): base_ridge.append(height(x,330))
	editor.start_stroke(Ring.point(178,source.surface_height(Vector2(178,330)),330))
	for frame in 240:
		var arc:=lerpf(178,230,float(frame)/239)
		editor.active_stroke.brush.dab(Ring.point(arc,source.surface_height(Vector2(arc,330)),330),4.0/60)
		editor.flush_strokes();await physics_frame;track()
	editor.finish_stroke();await drain()
	var minimum_ridge:=INF;var index:=0
	for x in range(178,231,4):
		minimum_ridge=minf(minimum_ridge,height(x,330)-base_ridge[index]);index+=1
	require(minimum_ridge>.8,"Moving stroke left a gap in the ridge")
	require(edits.undo_stack.size()==2,"Freehand stroke was not one undo step")
	require(edits.save_edits(),"Continuous stroke save failed")
	var fresh:=Edits.new();fresh.arena=arena;fresh.save_path=edits.save_path;require(fresh.load_edits(true),"Continuous stroke reload failed")
	for key in [Vector2i(0,1),Vector2i(1,1)]:
		var restored:Dictionary=fresh.apply(source.build_tile(key),key)
		var arrays:Array=arena.tile_entries[key].visual.mesh.surface_get_arrays(0)
		require(restored.vertices==arrays[Mesh.ARRAY_VERTEX] and restored.indices==arrays[Mesh.ARRAY_INDEX],"Continuous stroke replay differs from live mesh")
	fresh.free();editor.free()
	latencies.sort();workers.sort()
	print("CONTINUOUS_BRUSH_RESULT ",JSON.stringify({"updates":edits.publications,"stationary_increase_m":increase,"ridge_minimum_m":minimum_ridge,"features":edits.cuts.size(),"intermediate_updates_at_1_5s":intermediate_updates,"worker_median_ms":workers[workers.size()/2],"publication_median_ms":latencies[latencies.size()/2],"publication_p95_ms":latencies[int(latencies.size()*.95)],"publication_worst_ms":latencies.back()}))
	if not failed: print("CONTINUOUS_BRUSH_PASS")
	quit(1 if failed else 0)
