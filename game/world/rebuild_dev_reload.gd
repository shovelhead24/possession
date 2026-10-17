extends Node
## Explicit development reload. World state stays owned by the existing managers.
const PATHS := ["res://world/forge_parts.gd","res://world/forge_world.gd","res://world/actor_preview.gd","res://world/forge_editor.gd","res://world/actor_editor.gd"]
const FIELDS := ["opened","was_driving","tool","radius","strength","tree_species","tree_height","tree_density","selection","draft","moving","existing_draft","grid","angle_step","face_snap","edge_snap","face_choice","phased","floating","finish","rotation_delta","lift","hold_distance","actor_id","waypoint","operation","new_kind","pending_copy"]
var arena: Node3D
var busy := false
var last_result := ""
func report(message: String) -> void:
	last_result=message
	arena.forge.store.notice=message
	if arena.actors: arena.actors.store.notice=message
	print("DEV_RELOAD ",message)
func request() -> void:
	if busy: return
	if not arena.editor.opened: report("Open F1 editor before reloading development changes.");return
	var editor=arena.editor
	if not editor.input_strokes.is_empty() or arena.destruction.busy() or editor.painting or editor.stroke or editor.foliage_review.sampling:
		report("Finish the active terrain / tree edit or measurement before reloading.");return
	busy=true;report("Checking development changes…")
	apply.call_deferred()
static func reload_sources(paths: Array) -> String:
	var previous := {};var sources := {};var scripts := {}
	# Read every source first: missing files must not leave a partial reload.
	for path in paths:
		var script=load(path) as GDScript
		if not script: return "Cannot load "+path
		var source=FileAccess.get_file_as_string(path)
		if source.is_empty(): return "No source for "+path
		previous[path]=script.source_code;sources[path]=source;scripts[path]=script
	var touched := []
	for path in paths:
		var script=scripts[path]
		touched.append(path);script.source_code=sources[path]
		if script.reload(true)!=OK:
			for restored in touched:
				var old=scripts[restored];old.source_code=previous[restored];old.reload(true)
			return "Reload failed: "+path+". Previous scripts restored."
	return ""
func apply() -> void:
	var started=Time.get_ticks_msec()
	# Compile disk sources in a separate process before touching live scripts.
	var output := []
	var status=OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://world/rebuild_demo.gd","--check-only"]),output,true,false)
	var log_text="\n".join(output)
	if status!=0 or "SCRIPT ERROR" in log_text or "Parse Error" in log_text or "Compile Error" in log_text:
		var detail="Script check failed."
		for line in log_text.split("\n"):
			if "SCRIPT ERROR" in line: detail=line.strip_edges();break
		busy=false;report("Reload rejected; running world retained. "+detail);print(log_text);return
	var old=arena.editor
	var state := {}
	for key in FIELDS:
		var value=old.get(key);state[key]=value.duplicate(true) if value is Array or value is Dictionary else value
	var error=reload_sources(PATHS)
	if not error.is_empty(): busy=false;report(error);return
	var replacement=load("res://world/actor_editor.gd").new()
	# Restore settings before UI creation so its controls display the active values.
	for key in FIELDS:
		if not (state[key] is Array or state[key] is Dictionary): replacement.set(key,state[key])
	arena.forge.refresh_geometry()
	arena.add_child(replacement);replacement.setup(arena);replacement.connect_actors(arena.actors)
	for key in FIELDS: replacement.set(key,state[key])
	replacement.update_panels();replacement.refresh_selection();replacement.sync_fields();replacement.refresh_actors()
	if not replacement.draft.is_empty(): replacement.create_previews()
	arena.forge.hidden_ids=replacement.selection.duplicate() if replacement.moving else []
	arena.editor=replacement
	# Editor-owned visuals are parented into the world, not beneath the editor.
	for key in ["cursor","guide","outline","edge_guide","markers","placement_marker","object_preview"]:
		var node=old.get(key)
		if is_instance_valid(node): node.free()
	for node in old.preview_nodes:
		if is_instance_valid(node): node.free()
	old.free()
	busy=false;report("Development changes reloaded in %.2f s. Layouts, undo and camera retained." % ((Time.get_ticks_msec()-started)/1000.0))
