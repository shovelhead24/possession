extends SceneTree

func _initialize() -> void:
	var recipe=load("res://world/sdf_recipe.gd")
	var preset=load("res://world/stress_course.gd")
	var features: Array=preset.features()
	assert(features.size()==228)
	assert(recipe.validate(recipe.document(features)))
	assert(JSON.stringify(features)==JSON.stringify(preset.features()))
	var normal=load("res://world/sdf_authoring.tscn").instantiate()
	var stress=load("res://world/sdf_stress_course.tscn").instantiate()
	assert(normal.recipe_save_path()=="user://sdf-authoring.json")
	assert(stress.recipe_save_path()=="user://sdf-stress-course.json")
	for i in 12:
		var z := -120.0-i*44.0
		# New features leave the centre driving lane open at car-roof height.
		assert(recipe.compose(Vector3(-14,4,z),4.0,features)>0)
		assert(recipe.compose(Vector3(-14,12,z),12.0,features)<0,"Missing overhead deck")
	normal.free();stress.free()
	print("STRESS_COURSE_PASS features=228 separate_save=true");quit()
