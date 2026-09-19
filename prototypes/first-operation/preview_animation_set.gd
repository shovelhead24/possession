extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var scene=Node3D.new();root.add_child(scene)
	var environment=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.13,.16,.19);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.75,.8,1);env.ambient_light_energy=.6;environment.environment=env;scene.add_child(environment)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,160,0);light.shadow_enabled=true;scene.add_child(light)
	var floor_mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(19,12);floor_mesh.mesh=plane;floor_mesh.position=Vector3(5.4,-.02,-1.7);scene.add_child(floor_mesh)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.5;camera.position=Vector3(5.4,8,-12);scene.add_child(camera);camera.look_at(Vector3(5.4,.6,-1.75));camera.current=true
	var names=["Idle","Walk","Run","Strafe","Jump","Crouch","Dive","Flee","Check","Scratch","Look","Talk","Fire","Death"]
	for i in range(names.size()):
		var actor=preload("res://lizard_actor.gd").new();actor.elite=i%2==0;actor.position=Vector3((i%7)*1.8,0,-int(i/7)*3.5);scene.add_child(actor);actor.set_fleeing(names[i]=="Flee");actor.player.play(actor.clips[names[i]],0);actor.player.advance(.45 if names[i]!="Death" else 1.1);actor.player.pause()
		var label=Label3D.new();label.text=names[i];label.position=actor.position+Vector3(0,1.7,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=30;label.pixel_size=.006;scene.add_child(label)
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/animation-set.png")
	print("PASS: animation set captured");quit()

