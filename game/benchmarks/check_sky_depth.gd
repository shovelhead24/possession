extends SceneTree
func _initialize(): run.call_deferred()
func run():
	root.size=Vector2i(640,480)
	var world=Node3D.new();root.add_child(world)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_SKY;env.environment.sky=Sky.new();var sm=ShaderMaterial.new();sm.shader=load("res://world/sky_painterly_background.gdshader");env.environment.sky.sky_material=sm;world.add_child(env)
	var img=Image.load_from_file("res://world/cloud_cache/painterly-v1.png");var alphas=[]
	for y in range(0,2048,16):
		for x in range(0,2048,16): alphas.append(img.get_pixel(x,y).a)
	alphas.sort();print("ALPHAS ",[alphas[0],alphas[4096],alphas[8192],alphas[12288],alphas[-1]])
	var camera=Camera3D.new();camera.far=1200000;world.add_child(camera);camera.position=Vector3(0,100,0);camera.look_at(Vector3(0,955000,0),Vector3.FORWARD);camera.current=true
	var ring=preload("res://world/sky_high_painterly.gd").new();ring.altitude=0;world.add_child(ring)
	var mat=ShaderMaterial.new();var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled;void fragment(){ALBEDO=vec3(1,0,1);}";mat.shader=shader;ring.material_override=mat
	for clip in [0.2,0.3,0.5,0.75,1.0,2.0]:
		camera.near=clip
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		var image=root.get_texture().get_image();var count=0
		for x in range(0,640):
			var color=image.get_pixel(x,240)
			if color.r>0.8 and color.b>0.8 and color.g<0.2: count+=1
		print("DEPTH near=",clip," center=",image.get_pixel(320,240)," row_pixels=",count)
	quit()

