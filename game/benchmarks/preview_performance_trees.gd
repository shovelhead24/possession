extends SceneTree
func _initialize():
	run.call_deferred()
func run():
	root.size=Vector2i(1280,720)
	var world=Node3D.new();root.add_child(world)
	var env=WorldEnvironment.new();var e=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color(.13,.16,.20);e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color.WHITE;e.ambient_light_energy=.65;env.environment=e;world.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);world.add_child(sun)
	var importer=preload("res://world/arena_live_content.gd").new()
	for index in 1:
		var title="Supplied tree pack"
		var doc=GLTFDocument.new();var state=GLTFState.new()
		assert(doc.append_from_file("C:/Users/Bran the builder/Downloads/simple_low-mid_poly_trees.glb",state)==OK)
		var model=doc.generate_scene(state);world.add_child(model)
		var bounds=importer.model_bounds(model)
		model.scale*=6.0/maxf(bounds.size.x,bounds.size.z)
		bounds=importer.model_bounds(model);model.position-=bounds.get_center();model.position.x+=0
		print(title," bounds ",bounds)
		var label=Label3D.new();label.text=title+" / about 5.8–6.1k triangles per tree";label.font_size=50;label.pixel_size=.008;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=Vector3(0,3.3,0);world.add_child(label)
	var camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(11,9,17);camera.look_at(Vector3.ZERO);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9;camera.current=true
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/tree-pack-preview.png")
	importer.contact_debug.free();importer.free();quit()


