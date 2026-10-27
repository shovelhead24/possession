extends SceneTree
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1440,900)
	var world=Node3D.new();root.add_child(world)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.16,.20,.24);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;world.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-30,0);world.add_child(sun)
	var assets=preload("res://world/performance_tree_assets.gd").new().load_meshes()
	var report=preload("res://world/tree_patch_assets.gd").audit(assets)
	FileAccess.open("C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/pine-lod-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	var row=0
	for name in assets:
		for lod in 4:
			var mesh=assets[name][lod];assert(mesh.get_aabb().size.y>.95 and mesh.get_aabb().size.y<1.05)
			var draw=MeshInstance3D.new();draw.mesh=mesh;draw.scale=Vector3.ONE*7;draw.position=Vector3(lod*7-10.5,0,row*10);world.add_child(draw)
			var label=Label3D.new();label.text=preload("res://world/performance_tree_assets.gd").MAPPING[name]+" / LOD"+str(lod);label.font_size=26;label.pixel_size=.012;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=draw.position+Vector3(0,8,0);world.add_child(label)
		row+=1
	var camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,24,-38);camera.look_at(Vector3(0,2,10));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=36;camera.current=true
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/pine-lod-preview.png")
	print("PASS pine variants and LOD height checks ",JSON.stringify(report));quit()
