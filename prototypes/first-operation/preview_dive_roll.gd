extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var scene=Node3D.new();root.add_child(scene)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.15,.18,.2);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;scene.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,160,0);light.shadow_enabled=true;scene.add_child(light)
	var floor_mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(20,20);floor_mesh.mesh=plane;scene.add_child(floor_mesh)
	var actor=preload("res://lizard_actor.gd").new();actor.elite=true;actor.scale=Vector3.ONE*1.5;scene.add_child(actor)
	var camera=Camera3D.new();camera.position=Vector3(4,2.5,-3);scene.add_child(camera);camera.look_at(Vector3(0,.6,0));camera.current=true
	for time in [.6,1.0,1.4,1.95]:
		actor.player.stop();actor.player.play(actor.clips.Dive,0);actor.player.advance(time);actor.player.pause()
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/roll-%.2f.png" % time)
	print("PASS: forward-roll poses captured");quit()
