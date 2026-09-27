extends SceneTree
func _initialize():
	for method in ClassDB.class_get_method_list("ImporterMesh"):
		if method.name in ["generate_lods","add_surface","get_mesh"]: print(method)
	quit()
