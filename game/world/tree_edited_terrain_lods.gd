extends Node
## Explicit editor render pass. Loading cached results/fallbacks never simplifies.
const Lods = preload("res://world/terrain_render_lods.gd")
var arena: Node3D
var worker: Thread
var job := {}
var entries := {}
var affected := {}
var revision := -1
var clock := 0.0
var enabled := true
var published := 0
var generated_tiles := 0
var triangles_full := 0
var triangles_coarse := 0
var requested := {}
var total := 0
var completed := 0
var status := "Build LODs explicitly for loaded edited terrain."
var hidden_keys := {}
var dialog: AcceptDialog
var status_label: Label

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena
	dialog=AcceptDialog.new();dialog.title="Authored terrain · rendering pass";dialog.min_size=Vector2i(500,260);arena.add_child(dialog)
	var column := VBoxContainer.new();dialog.add_child(column)
	var help := Label.new();help.text="Build render LODs when you are ready. This covers loaded edited tiles.\nNo background simplification starts automatically.\nUnbuilt edits beyond 220 m use the underlying terrain.\nFull edits return within 180 m; collision stays unchanged.";column.add_child(help)
	var use_lods := CheckButton.new();use_lods.text="Use distant LODs / unbuilt-edit fallback";use_lods.button_pressed=true;column.add_child(use_lods)
	use_lods.toggled.connect(func(value): enabled=value;clock=0)
	var buttons := HBoxContainer.new();column.add_child(buttons)
	var bake := Button.new();bake.text="Build loaded terrain LODs";buttons.add_child(bake);bake.pressed.connect(request_build)
	var stop := Button.new();stop.text="Stop after tile";buttons.add_child(stop);stop.pressed.connect(stop_build)
	status_label=Label.new();status_label.add_theme_font_size_override("font_size",12);column.add_child(status_label)

static func cache_path(identity: String) -> String:
	return "user://terrain-render-lods-v1/"+(Engine.get_version_info().string+identity).sha256_text()+".bin"

static func build(arrays: Array, identity: String, source: RefCounted, key: Vector2i, generate: bool) -> Dictionary:
	var result := {"vertices":arrays[Mesh.ARRAY_VERTEX],"normals":arrays[Mesh.ARRAY_NORMAL],"indices":arrays[Mesh.ARRAY_INDEX],"render_lods":{}}
	if generate: Lods.prepare(result,identity)
	elif FileAccess.file_exists(cache_path(identity)):
		var file := FileAccess.open(cache_path(identity),FileAccess.READ)
		var cached: Variant=file.get_var() if file else null
		if cached is Dictionary: result.render_lods=cached
	return {"arrays":arrays,"lods":result.render_lods,"base":source.build_tile(key)}

static func mesh_from(data: Dictionary) -> ArrayMesh:
	var arrays := [];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=data.vertices;arrays[Mesh.ARRAY_NORMAL]=data.normals;arrays[Mesh.ARRAY_INDEX]=data.indices
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],data.get("render_lods",{}));return mesh

func request_build() -> void:
	if arena.destruction.busy(): status="Finish the terrain edit before building LODs.";return
	requested.clear();completed=0
	for key in arena.destruction.keys_for(arena.destruction.cuts):
		if arena.tile_entries.has(key): requested[arena.tile_entries[key].visual.get_instance_id()]=true
	total=requested.size()
	status="Building loaded edits: 0 / %d" % total if total else "No loaded edited tiles to build."
	clock=0

func stop_build() -> void:
	requested.clear();status="Stopped; current tile may finish."

func is_edit_hidden(key: Vector2i) -> bool:
	return hidden_keys.has(key)

func _process(delta: float) -> void:
	if not arena or not arena.ready_to_play: return
	if worker and not worker.is_alive():
		var data: Dictionary=worker.wait_to_finish();worker=null
		var visual: MeshInstance3D=instance_from_id(job.id) as MeshInstance3D
		if is_instance_valid(visual) and not visual.is_queued_for_deletion():
			var entry: Dictionary=entries[job.id]
			entry.base=mesh_from(data.base);entry.loaded=true
			if not data.lods.is_empty():
				var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data.arrays,[],data.lods)
				entry.lod=mesh;published+=1
				var full: int=data.arrays[Mesh.ARRAY_INDEX].size()/3;var coarse := full
				for indices in data.lods.values(): coarse=mini(coarse,indices.size()/3)
				triangles_full+=full;triangles_coarse+=coarse
			elif job.generate: entry.lod=entry.full # Simplifier found no useful reduction.
		if job.generate: generated_tiles+=1
		if job.generate and requested.has(job.id):
			requested.erase(job.id);completed+=1
			status="Built %d / %d loaded tiles." % [completed,total]
		job={};clock=0
	clock-=delta
	if clock>0 or arena.destruction.busy(): return
	clock=.25
	if status_label: status_label.text=status+"\nCached results are reused; moving elsewhere may load unbuilt edits."
	if revision!=arena.destruction.revision:
		revision=arena.destruction.revision;affected.clear()
		for key in arena.destruction.keys_for(arena.destruction.cuts): affected[key]=true
	var live := {};var next := {};var hidden := {}
	for key in arena.tile_entries:
		if not affected.has(key): continue
		var visual: MeshInstance3D=arena.tile_entries[key].visual
		var id := visual.get_instance_id();live[id]=true
		if not entries.has(id): entries[id]={"full":visual.mesh,"base":null,"lod":null,"loaded":false,"far":false}
		var entry: Dictionary=entries[id]
		var bounds: AABB=entry.full.get_aabb()
		var camera: Vector3=visual.to_local(arena.camera.global_position)
		var distance := camera.distance_to(camera.clamp(bounds.position,bounds.end))
		if distance<180: entry.far=false
		elif distance>220: entry.far=true
		var desired: Mesh=entry.full
		if entry.far and enabled:
			if entry.lod: desired=entry.lod
			elif entry.base: desired=entry.base;hidden[key]=true
		if visual.mesh!=desired: visual.mesh=desired
		visual.lod_bias=1.0 if entry.far and enabled else 1000000.0
		if not worker and next.is_empty() and (not entry.loaded or requested.has(id)):
			next={"id":id,"key":key,"generate":requested.has(id)}
	for id in entries.keys():
		if not live.has(id):
			entries.erase(id)
			if requested.has(id): requested.erase(id);status="Tile unloaded; build remaining loaded edits again if needed."
	if hidden!=hidden_keys:
		hidden_keys=hidden
		for patch in [arena.trees,arena.painted_trees]: patch.dirty=true;patch.update_batches()
	if not next.is_empty():
		job=next
		var arrays: Array=entries[job.id].full.surface_get_arrays(0)
		var identity: String=arena.source.identity+str(job.key)+arena.destruction.current_signature+"edited-render-v1"
		worker=Thread.new()
		if worker.start(build.bind(arrays,identity,arena.source,job.key,job.generate))!=OK: worker=null;job={};status="Could not start render worker."

func _exit_tree() -> void:
	if worker: worker.wait_to_finish()
