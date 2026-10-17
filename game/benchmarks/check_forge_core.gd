extends SceneTree
const Parts=preload("res://world/forge_parts.gd")
const Store=preload("res://world/forge_store.gd")
const World=preload("res://world/forge_world.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
class Source extends RefCounted:
	var identity := "forge-test-base"
class Editor extends RefCounted:
	var opened := true
class Kit extends RefCounted:
	var car: Node3D
class Arena extends Node3D:
	var source := Source.new()
	var editor := Editor.new()
	var vehicle_kit := Kit.new()
	var on_foot: Node3D
	var ready_to_play := false
	var camera: Camera3D
	var tile_entries := {Vector2i(0,0):{}}
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--forge-test-dir="): output=arg.trim_prefix("--forge-test-dir=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	create_timer(40).timeout.connect(func(): push_error("Forge test timeout");quit(1))
	run.call_deferred()
func near_pose(a: Transform3D,b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin)<.04 and a.basis.is_equal_approx(b.basis)
func run() -> void:
	for kind in Parts.NAMES:
		var part := Parts.get_part(kind)
		assert(part.mesh.get_surface_count()==1 and not part.pieces.is_empty())
		assert(part.mesh.get_aabb().size.is_equal_approx(part.size),kind+" bounds mismatch")
	var target := Transform3D(Basis.from_euler(Vector3(.3,.8,-.2)),Vector3(50,2,20))
	for axis in [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]:
		var n: Vector3=target.basis*axis
		var result := Parts.snap_face(target,Vector3(4,3,.25),target.basis,Vector3(4,3,.25),n)
		var expected := Parts.support(target.basis,Vector3(4,3,.25),n)*2
		assert(absf((result.origin-target.origin).dot(n)-expected)<.0001)
	var store := Store.new();store.path=output.path_join("layout.json");store.base="unit-test"
	var p := Ring.point(100000,8,40);var t := Transform3D(Ring.tangent_basis(p,.6),p)
	var a := store.make("wall",t);var b := store.make("floor",Transform3D(t.basis,p+t.basis.x*4),2)
	var before := store.snapshot();store.records=[a,b];store.commit(before)
	store.join([a.id,b.id]);assert(store.expanded([a.id]).size()==2)
	var relative := Store.pose(a).affine_inverse()*Store.pose(b)
	var turn := Basis(Vector3.UP,.4);store.transform_selection([a.id,b.id],Transform3D(turn,p-turn*p+Vector3(0,3,0)))
	assert(near_pose(Store.pose(a).affine_inverse()*Store.pose(b),relative))
	store.undo();assert(near_pose(Store.pose(store.find(a.id)),t));store.redo()
	assert(store.unsaved() and store.save() and not store.unsaved())
	var loaded := Store.new();loaded.path=store.path;loaded.base=store.base;assert(loaded.load_saved(true))
	assert(loaded.records.size()==2 and loaded.expanded([a.id]).size()==2)
	assert(near_pose(Store.pose(loaded.find(a.id)),Store.pose(store.find(a.id))))
	before=loaded.snapshot();loaded.erase([a.id]);loaded.undo();assert(loaded.records==before)
	var invalid := FileAccess.open(store.path,FileAccess.WRITE);invalid.store_string('{"schema":1,"base":"wrong","frame":"terrain-drive-ring-metres","parts":[]}');invalid.close()
	assert(not loaded.load_saved() and loaded.records==before)
	var bad: Dictionary=before[0].duplicate(true);bad.b[0]=2;assert(not Store.valid_record(bad))
	bad=before[0].duplicate(true);bad.p[1]=INF;assert(not Store.valid_record(bad))
	var arena := Arena.new();root.add_child(arena);arena.camera=Camera3D.new();arena.add_child(arena.camera)
	arena.vehicle_kit.car=Node3D.new();arena.add_child(arena.vehicle_kit.car)
	var world := World.new();arena.add_child(world)
	# Set up an isolated store without touching the player's save path.
	world.arena=arena
	for i in 3: world.materials.append(StandardMaterial3D.new())
	for i in 5000:
		var point := Ring.point(10000+i*4,2,10000)
		world.store.records.append(world.store.make("wall",Transform3D(Ring.tangent_basis(point,0),point)))
	for i in 20:
		var point := Ring.point(10+i*4,2,10)
		world.store.records.append(world.store.make("wall",Transform3D(Ring.tangent_basis(point,0),point)))
	world.reindex();world.update_visuals(Vector3.ZERO);world.update_collision(Vector3.ZERO)
	assert(world.active_count==20 and world.batches.size()==1 and world.collision_queue.size()==20)
	for id in world.collision_queue: world.create_body(world.by_id[id])
	world.collision_queue.clear()
	var seam := Ring.point(1499990,0,0);var seam_record := world.store.make("wall",Transform3D(Ring.tangent_basis(seam,0),seam))
	world.store.records.append(seam_record);world.reindex()
	assert(seam_record.id in world.nearby(Ring.point(-1499990,0,0),50))
	world.update_visuals(Ring.point(500000,0,0));assert(world.active_count==0 and world.batches.is_empty())
	# Doorway and ramp use actual physics shapes at a rotated ring position.
	var door := store.make("door",t);world.create_body(door)
	var ramp_pose := Transform3D(t.basis,p+t.basis.x*10)
	var ramp := store.make("ramp",ramp_pose);world.create_body(ramp)
	await physics_frame;await physics_frame
	var space := arena.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(t*Vector3(0,0,2),t*Vector3(0,0,-2),2)
	assert(space.intersect_ray(query).is_empty())
	query.from=t*Vector3(1.5,0,2);query.to=t*Vector3(1.5,0,-2);assert(not space.intersect_ray(query).is_empty())
	query.from=ramp_pose*Vector3(0,4,0);query.to=ramp_pose*Vector3(0,-3,0)
	var hit := space.intersect_ray(query);assert(not hit.is_empty())
	assert(absf((ramp_pose.affine_inverse()*hit.position).y)<.05)
	assert(hit.normal.dot(t.basis.y)>.85)
	print("FORGE_CORE_PASS: 10 meshes, rotated face snap, joined relative transforms, undo/redo, validated save/load, 5021 spatial records, seam query, actual doorway and ramp collision")
	arena.free();quit()

