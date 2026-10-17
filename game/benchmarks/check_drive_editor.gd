extends SceneTree
const Source = preload("res://world/terrain_baseline_source.gd")
const Ring = preload("res://world/terrain_drive_ring.gd")
const Recipe = preload("res://world/sdf_recipe.gd")
const Edits = preload("res://world/terrain_drive_destruction.gd")
const Editor = preload("res://world/terrain_drive_editor.gd")
const Support = preload("res://benchmarks/check_drive_grenades.gd")
var failed := false

func _initialize() -> void:
	create_timer(300).timeout.connect(func(): push_error("DRIVE_EDITOR_TIMEOUT");quit(1))
	run.call_deferred()

func require(ok: bool, message: String) -> void:
	if not ok: failed=true;push_error(message)

func settle(edits: Node) -> void:
	var started := Time.get_ticks_msec()
	while edits.busy() and Time.get_ticks_msec()-started<60000: await process_frame
	require(not edits.busy(),"Editor update did not finish")
	await physics_frame;await physics_frame

func install(arena: Node3D, key: Vector2i, data: Dictionary) -> void:
	var arrays := [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_INDEX]=data.indices
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual := MeshInstance3D.new();visual.mesh=mesh;arena.add_child(visual)
	var body := StaticBody3D.new();var shape := CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();body.add_child(shape);arena.add_child(body)
	arena.tile_entries[key]={"visual":visual,"body":body};arena.tiles.append(visual)

func ray(arena: Node3D, a: Vector3, b: Vector3) -> Dictionary:
	return arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))

func ground(arena: Node3D, arc: float, lateral: float) -> Vector3:
	var h: float=arena.source.surface_height(Vector2(arc,lateral))
	var hit := ray(arena,Ring.point(arc,h+180,lateral),Ring.point(arc,h-180,lateral))
	require(not hit.is_empty(),"Ground collision disappeared")
	return hit.get("position",Vector3.ZERO)

func run() -> void:
	if OS.get_cmdline_user_args().has("--editor-scene-check"):
		await scene_check();return
	var source := Source.new();source.curve_to_ring=true;require(source.initialize(),"Source failed")
	var arena := Support.Fixture.new();arena.source=source;root.add_child(arena)
	var edits := Edits.new();edits.arena=arena;arena.destruction=edits;arena.add_child(edits)
	edits.save_path="C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/work/editor-test-%d.json" % OS.get_process_id()
	var editor := Editor.new();editor.arena=arena
	for key in [Vector2i(0,1),Vector2i(1,1)]: install(arena,key,source.build_tile(key))
	await physics_frame;await physics_frame
	var before := ground(arena,200,300);var before_height := Ring.coordinates(before).y
	editor.radius=12;editor.strength=6
	require(editor.sculpt(before,1),"Raise rejected");await settle(edits)
	var raised := ground(arena,200,300)
	require(Ring.coordinates(raised).y>before_height+5.5,"Raise did not raise collision")
	editor.tool="lower";editor.strength=3
	require(editor.sculpt(raised,1),"Lower rejected");await settle(edits)
	var lowered := ground(arena,200,300)
	require(absf(Ring.coordinates(lowered).y-before_height-3)<.15,"Lower did not compose with raise")
	edits.undo();await settle(edits)
	require(ground(arena,200,300).distance_to(raised)<.02,"Undo did not restore geometry/collision")
	edits.redo();await settle(edits)
	require(ground(arena,200,300).distance_to(lowered)<.02,"Redo did not restore geometry/collision")
	editor.radius=16;editor.mountain_height=24
	require(editor.place_mountain(lowered),"Mountain rejected");await settle(edits)
	var mountain := ground(arena,200,300)
	require(Ring.coordinates(mountain).y>Ring.coordinates(lowered).y+4,"Mountain did not add terrain")
	var entrance := Ring.point(180,before_height+7,300);var exit := Ring.point(220,before_height+7,300)
	require(not ray(arena,entrance,exit).is_empty(),"Tunnel test route did not initially contain solid terrain")
	editor.radius=4
	require(editor.bore_tunnel(entrance,exit),"Tunnel rejected");await settle(edits)
	require(ray(arena,entrance,exit).is_empty(),"Bored tunnel is blocked")
	for offset in [-.05,.05]: ground(arena,200+offset,300)
	require(edits.save_edits(),"Save failed: "+edits.notice)
	var saved := edits.signature(edits.cuts)
	require(edits.save_edits() and FileAccess.file_exists(edits.save_path+".bak"),"Previous-save backup missing")
	edits.undo();await settle(edits)
	require(not ray(arena,entrance,exit).is_empty(),"Undo tunnel did not restore solid mountain")
	require(edits.load_edits(),"Load failed");await settle(edits)
	require(edits.signature(edits.cuts)==saved and ray(arena,entrance,exit).is_empty(),"Load lost ordered tools or tunnel collision")
	var fresh := Edits.new();fresh.arena=arena;fresh.save_path=edits.save_path
	require(fresh.load_edits(true),"Fresh-session load failed")
	for key in [Vector2i(0,1),Vector2i(1,1)]:
		var rebuilt: Dictionary=fresh.apply(source.build_tile(key),key)
		var arrays: Array=arena.tile_entries[key].visual.mesh.surface_get_arrays(0)
		require(rebuilt.vertices==arrays[Mesh.ARRAY_VERTEX] and rebuilt.indices==arrays[Mesh.ARRAY_INDEX],"Saved recipe replay differs from live surface")
	fresh.free()
	var original_save := edits.save_path
	edits.save_path+=".invalid"
	var file := FileAccess.open(edits.save_path,FileAccess.WRITE);file.store_string('{"schema":999}');file.close()
	require(not edits.load_edits() and edits.signature(edits.cuts)==saved,"Invalid save replaced terrain")
	edits.save_path=original_save
	print("DRIVE_EDITOR_TOOLS ",JSON.stringify({"raise_m":Ring.coordinates(raised).y-before_height,"lower_m":Ring.coordinates(raised).y-Ring.coordinates(lowered).y,"mountain_added_m":Ring.coordinates(mountain).y-Ring.coordinates(lowered).y,"edits":edits.completed,"save":edits.save_path}))
	# The same tool works after travelling far around the ring.
	for key in [Vector2i(99,1),Vector2i(100,1)]: install(arena,key,source.build_tile(key))
	await physics_frame;await physics_frame
	var far_before := ground(arena,20000,300)
	editor.tool="hill";editor.radius=8;editor.strength=4
	require(editor.sculpt(far_before,1),"Far-ring edit rejected");await settle(edits)
	require((ground(arena,20000,300)-far_before).dot(Ring.up_at(far_before))>3.5,"Far-ring edit failed")
	editor.free()
	if not failed: print("DRIVE_EDITOR_PASS: four tools, undo/redo, tunnel collision, atomic save/backup, fresh-session replay, rejected invalid save, far-ring edit")
	quit(1 if failed else 0)

func scene_check() -> void:
	root.size=Vector2i(1280,800)
	var scene: Node3D=load("res://world/terrain_drive.tscn").instantiate();root.add_child(scene)
	while not scene.ready_to_play: await process_frame
	scene.loading.close()
	var editor: Node=scene.editor;var edits: Node=scene.destruction
	var event := InputEventKey.new();event.keycode=KEY_F1;event.pressed=true;scene._input(event)
	require(editor.opened and editor.panel.visible and not scene.vehicle_kit.driving,"F1 did not enter editor")
	require(editor.tool_buttons.size()==4,"Editor has unexpected tools")
	var p := ground(scene,200,300)
	editor.select_tool("mountain");editor.radius_control.value=24;editor.mountain_height=24
	require(editor.place_mountain(p),"Full scene mountain rejected");await settle(edits)
	editor.save()
	while editor.save_when_ready: await process_frame
	require(not edits.unsaved() and FileAccess.file_exists(edits.save_path),"Editor Save button did not save")
	var expected: String=edits.signature(edits.cuts)
	var saved_height := Ring.coordinates(ground(scene,200,300)).y
	scene.camera.position=Ring.point(200,Ring.coordinates(p).y+45,360)
	scene.camera.look_at(Ring.point(200,Ring.coordinates(p).y+12,300),Ring.up_at(p))
	await process_frame;await RenderingServer.frame_post_draw
	if DisplayServer.get_name()!="headless":
		root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-07/co/outputs/terrain-tools.png")
	scene._input(event);require(not editor.opened and scene.vehicle_kit.driving,"F1 did not restore play")
	scene.queue_free();await process_frame;await process_frame
	scene=load("res://world/terrain_drive.tscn").instantiate();root.add_child(scene)
	while not scene.ready_to_play: await process_frame
	await physics_frame;await physics_frame
	require(scene.destruction.signature(scene.destruction.cuts)==expected,"Startup failed to auto-load saved edits")
	require(absf(Ring.coordinates(ground(scene,200,300)).y-saved_height)<.02,"Startup collision differs from saved terrain")
	if not failed: print("DRIVE_EDITOR_SCENE_PASS: F1 panel, four tools, save action, return to driving, restart auto-load and collision")
	quit(1 if failed else 0)
