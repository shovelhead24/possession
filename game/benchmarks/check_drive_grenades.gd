extends SceneTree
const Source = preload("res://world/terrain_baseline_source.gd")
const Ring = preload("res://world/terrain_drive_ring.gd")
const Destruction = preload("res://world/terrain_drive_destruction.gd")
const Stream = preload("res://world/terrain_drive_stream.gd")

class Fixture extends Node3D:
	var source: RefCounted
	var tile_entries := {}
	var tiles: Array=[]
	var material := StandardMaterial3D.new()
	var streamer: Node
	var destruction: Node
	var ready_to_play := true
	func request_crater(p: Vector3, radius: float) -> bool:
		return destruction.request(p,radius)

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): push_error("DRIVE_GRENADE_TIMEOUT");quit(1))
	run.call_deferred()

func install(arena: Node3D, key: Vector2i, data: Dictionary) -> void:
	var arrays := [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_INDEX]=data.indices
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual := MeshInstance3D.new();visual.mesh=mesh;arena.add_child(visual)
	var body := StaticBody3D.new();var shape := CollisionShape3D.new()
	shape.shape=mesh.create_trimesh_shape();body.add_child(shape);arena.add_child(body)
	arena.tile_entries[key]={"visual":visual,"body":body};arena.tiles.append(visual)

func probe(arena: Node3D, arc: float, lateral: float) -> Dictionary:
	var h: float=arena.source.surface_height(Vector2(arc,lateral))
	var p := Ring.point(arc,h,lateral);var up := Ring.up_at(p)
	return arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+up*30,p-up*30,1))

func run() -> void:
	if OS.get_cmdline_user_args().has("--full-drive-grenades"):
		await run_full();return
	var source := Source.new();source.curve_to_ring=true
	assert(source.initialize())
	for arc in [200.0,20000.0]:
		var arena := Fixture.new();arena.source=source;root.add_child(arena)
		arena.streamer=Stream.new();arena.streamer.arena=arena
		# Keep ordinary streaming idle while exercising the real destruction coordinator.
		arena.destruction=Destruction.new();arena.destruction.arena=arena;arena.add_child(arena.destruction)
		var right := Vector2i(int(arc/200),0);var left := right-Vector2i(1,0)
		for key in [left,right]: install(arena,key,source.build_tile(key))
		await physics_frame;await physics_frame
		var before := probe(arena,arc,100)
		assert(not before.is_empty(),"Initial seam collision missing")
		var grenade := preload("res://world/terrain_grenade.gd").new()
		grenade.arena=arena;grenade.radial_gravity=true;arena.add_child(grenade)
		grenade.position=before.position+Ring.up_at(before.position)*1.0
		grenade.velocity=Vector3.ZERO
		var start := Time.get_ticks_msec()
		while arena.destruction.completed<1 and Time.get_ticks_msec()-start<30000: await process_frame
		assert(arena.destruction.completed==1,"Fused grenade did not complete")
		await physics_frame;await physics_frame
		var after := probe(arena,arc,100)
		assert(not after.is_empty(),"Crater lost collision floor")
		var depth: float=(before.position-after.position).dot(Ring.up_at(before.position))
		assert(depth>.1,"Crater did not lower the rendered/collision surface")
		for offset in [-.05,.05]: assert(not probe(arena,arc+offset,100).is_empty(),"Tile seam opened")
		assert(arena.request_crater(after.position+Ring.up_at(after.position)*.93,2))
		start=Time.get_ticks_msec()
		while arena.destruction.completed<2 and Time.get_ticks_msec()-start<30000: await process_frame
		assert(arena.destruction.completed==2)
		await physics_frame;await physics_frame
		var overlap := probe(arena,arc,100)
		assert(not overlap.is_empty())
		assert((after.position-overlap.position).dot(Ring.up_at(after.position))>0,"Overlapping cut was lost")
		for key in [left,right]:
			var old: Dictionary=arena.tile_entries[key]
			var rebuilt: Dictionary=arena.streamer.build(key)
			assert(rebuilt.indices==old.visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX],"Stream reload changed crater geometry")
			assert(rebuilt.vertices==old.visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],"Stream reload lost crater vertices")
		print("DRIVE_GRENADE_PASS arc=",arc," depth=",depth," cuts=",arena.destruction.completed)
		arena.streamer.free();arena.queue_free();await process_frame
	quit()

func run_full() -> void:
	var scene: Node3D=load("res://world/terrain_drive.tscn").instantiate();root.add_child(scene)
	while not scene.ready_to_play: await process_frame
	scene.loading.close()
	scene.vehicle_kit.test_controls=true;scene.vehicle_kit.test_throttle=0;scene.vehicle_kit.test_brake=true
	for driving in [true,false]:
		scene.vehicle_kit.driving=driving
		if not driving:
			var target: Vector3=scene.vehicle_kit.car.position
			var up := Ring.up_at(target)
			scene.camera.position=target+up*4+Vector3(8,0,0)
			scene.camera.look_at(target+Vector3(12,0,-10),up)
		var before: int=scene.destruction.completed
		var key := InputEventKey.new();key.keycode=KEY_B;key.pressed=true
		scene._input(key)
		var started := Time.get_ticks_msec()
		while scene.destruction.completed==before and Time.get_ticks_msec()-started<15000: await process_frame
		assert(scene.destruction.completed==before+1,"B key failed to throw/detonate")
		print("DRIVE_GRENADE_INPUT_PASS driving=",driving," latency_ms=",Time.get_ticks_msec()-started)
	quit()
