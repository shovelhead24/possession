extends "res://benchmarks/check_drive_grenades.gd"
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/outputs/"
func run() -> void:
	var source=Source.new();source.curve_to_ring=true;assert(source.initialize())
	var saved=JSON.parse_string(FileAccess.get_file_as_string("C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/work/sky-test/terrain-drive-edits.json"))
	var records=[]
	for mixed in [false,true]:
		var arena=Fixture.new();arena.source=source;root.add_child(arena)
		arena.destruction=Destruction.new();arena.destruction.arena=arena;arena.add_child(arena.destruction)
		if mixed:
			arena.destruction.cuts=saved.features.duplicate(true)
			arena.destruction.current_signature=arena.destruction.signature(arena.destruction.cuts)
			arena.destruction.signature_count=arena.destruction.cuts.size()
		var key=Vector2i(0,0)
		var base=source.build_tile(key)
		install(arena,key,arena.destruction.apply(base,key))
		# Measure cold edit preparation even when the visible tile was cached/loaded.
		arena.destruction.edit_cache=preload("res://world/terrain_drive_edit_cache.gd").new()
		var prep_ms=0.0
		if OS.get_cmdline_user_args().has("--prepared"):
			var prep_start=Time.get_ticks_usec()
			arena.destruction.edit_cache.protect([key])
			arena.destruction.edit_cache.warm(source,key,arena.destruction.cuts)
			prep_ms=(Time.get_ticks_usec()-prep_start)/1000.0
			var identity=source.identity+str(key)
			var builder=arena.destruction.edit_cache.entries[identity].builder
			for i in 26: arena.destruction.edit_cache.build(source,Vector2i(i%16-8,i/16-8),[])
			assert(arena.destruction.edit_cache.entries[identity].builder==builder and not arena.destruction.edit_cache.needs_warm(source,key),"Streaming evicted protected grenade terrain")
		await physics_frame;await physics_frame
		for shot in 3:
			var before=probe(arena,40+shot*6,80)
			assert(not before.is_empty())
			var revision=arena.destruction.revision
			var began=Time.get_ticks_usec()
			assert(arena.request_crater(before.position+Ring.up_at(before.position)*.93,2))
			while arena.destruction.applied_revision==revision: await process_frame
			await physics_frame;await physics_frame
			var after=probe(arena,40+shot*6,80);assert(not after.is_empty())
			assert((before.position-after.position).dot(Ring.up_at(before.position))>.05)
			var arrays=arena.tile_entries[key].visual.mesh.surface_get_arrays(0)
			var record={"mixed":mixed,"shot":shot,"total_ms":(Time.get_ticks_usec()-began)/1000.0,"worker_ms":arena.destruction.last_worker_ms,"queue_ms":arena.destruction.last_queue_ms,"mesh_ms":arena.destruction.last_mesh_ms,"collision_ms":arena.destruction.last_collision_ms,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"hash":var_to_bytes([arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_NORMAL],arrays[Mesh.ARRAY_INDEX]]).hex_encode().sha256_text()}
			record.preparation_ms=prep_ms;record.geometry_ms=arena.destruction.last_geometry_ms;record.collision_worker_ms=arena.destruction.last_collision_worker_ms;record.signature_ms=arena.destruction.last_signature_ms
			records.append(record);print("CRATER_PROFILE ",JSON.stringify(record))
			assert(arena.destruction.current_signature==arena.destruction.signature(arena.destruction.cuts),"Incremental save fingerprint differs")
			var fresh=preload("res://world/terrain_drive_edit_cache.gd").new().build(source,key,arena.destruction.cuts)
			var check_arrays=[];check_arrays.resize(Mesh.ARRAY_MAX);check_arrays[Mesh.ARRAY_VERTEX]=fresh.vertices;check_arrays[Mesh.ARRAY_NORMAL]=fresh.normals;check_arrays[Mesh.ARRAY_INDEX]=fresh.indices
			var check_mesh=ArrayMesh.new();check_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,check_arrays)
			var roundtrip=check_mesh.surface_get_arrays(0)
			assert(roundtrip[Mesh.ARRAY_VERTEX]==arrays[Mesh.ARRAY_VERTEX] and roundtrip[Mesh.ARRAY_NORMAL]==arrays[Mesh.ARRAY_NORMAL] and roundtrip[Mesh.ARRAY_INDEX]==arrays[Mesh.ARRAY_INDEX],"Cached crater differs from fresh reconstruction")
		arena.queue_free();await process_frame
	var label="after" if OS.get_cmdline_user_args().has("--after") else "before"
	if OS.get_cmdline_user_args().has("--prepared"): label="prepared"
	var file=FileAccess.open(OUT+"crater-profile-"+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "));file.close()
	quit()
