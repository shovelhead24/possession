extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var doc=GLTFDocument.new();var state=GLTFState.new();doc.append_from_file(ProjectSettings.globalize_path("res://../assets/rigged-t-rex-fabulous/source/rigged_t-rex_fabulous.glb"),state)
	var model=doc.generate_scene(state);root.add_child(model)
	var raw=preload("res://world/content_gallery.gd").new();var live=preload("res://world/arena_live_content.gd").new()
	var a=raw.model_bounds(model);var b=live.model_bounds(model)
	print("REX_BOUNDS original=",a," posed=",b," original_scale=",24/a.size.y," rebuild_scale=",24/b.size.y," ratio=",a.size.y/b.size.y)
	raw.contact_debug.free();raw.free();live.contact_debug.free();live.free();model.free();quit()
