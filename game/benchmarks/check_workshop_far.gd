extends SceneTree
const Far=preload("res://world/workshop_far_terrain.gd")
const Recipe=preload("res://world/sdf_recipe.gd")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(Far.FOLDER)
	var far := Far.new();far.source_tag="regression-"+FileAccess.get_file_as_string("res://world/workshop_far_terrain.gd").sha256_text()
	var f := Recipe.feature("mountain",Vector3(500,0,500));f.radius=80
	var base := far.build(Vector2i(1,1),[],3.2,.35)
	var edited := far.build(Vector2i(1,1),[f],3.2,.35)
	var reused := far.build(Vector2i(1,1),[f],3.2,.35)
	assert(edited.vertices!=base.vertices,"Scenery must include authored edits")
	assert(reused.get("cached",false) and reused.vertices==edited.vertices,"Scenery disk cache mismatch")
	var restored := far.build(Vector2i(1,1),[],3.2,.35)
	assert(restored.vertices==base.vertices,"Undo must select the prior scenery cache")
	far.free();print("PASS: coarse SDF includes authored mountains, persists and restores/undoes without purging")
	quit()
