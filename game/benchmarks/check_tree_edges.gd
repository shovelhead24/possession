extends SceneTree
const Assets = preload("res://world/tree_patch_assets.gd")
var output := ""
var meshes: Array[MeshInstance3D]=[]
var original_materials: Array[Material]=[]
var camera: Camera3D
var world: Node3D

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tree-output="): output=arg.trim_prefix("--tree-output=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	run.call_deferred()

func run() -> void:
	world=Node3D.new();root.add_child(world)
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.6,.7,.8)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.75,.83,.92)
	environment.environment.ambient_light_energy=.65;world.add_child(environment)
	var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-30,0);world.add_child(sun)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=14;camera.position=Vector3(0,2,22);world.add_child(camera)
	var variants := Assets.new().load_meshes()
	var zip := ZIPReader.new();assert(zip.open(ProjectSettings.globalize_path(Assets.ARCHIVE).simplify_path())==OK)
	var paths := ["Christmas_tree_Billboard_Mat_baseColor.png","Christmas_tree_2_Billboard_Mat_baseColor.png","Christmas_tree_3_Billboard_Mat_baseColor.png"]
	var labels := CanvasLayer.new();world.add_child(labels)
	var title := Label.new();title.text="ORIGINAL (upper row) / ALPHA BORDER FIX (lower row)\nTall fir                         Medium fir                          Sapling"
	title.position=Vector2(20,20);title.add_theme_color_override("font_color",Color.BLACK);labels.add_child(title)
	var column := 0
	for name in variants:
		var source := Image.new();assert(source.load_png_from_buffer(zip.read_file("textures/"+paths[column]))==OK)
		var corrected := Assets.prepare_foliage_image(source)
		var a := source.get_data();var b := corrected.get_data()
		for i in range(3,source.get_width()*source.get_height()*4,4*97): assert(a[i]==b[i],"Alpha coverage changed at base mip")
		source.generate_mipmaps()
		for row in 2:
			var mesh := MeshInstance3D.new();mesh.mesh=variants[name][3]
			mesh.scale=Vector3.ONE*3.6;mesh.position=Vector3((column-1)*4.5,2.5-row*4.7,0)
			var material: ShaderMaterial=mesh.mesh.surface_get_material(0).duplicate()
			material.set_shader_parameter("tex",ImageTexture.create_from_image(source if row==0 else corrected))
			mesh.material_override=material;world.add_child(mesh);meshes.append(mesh);original_materials.append(material)
		column+=1
	zip.close()
	for size in [14.0,36.0,75.0]:
		camera.size=size
		await create_timer(.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("edges-"+str(int(size))+".png"))
	print("TREE_EDGES_PASS base alpha preserved, 3 variants, 3 projected sizes")
	quit()
