extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var scene=Node3D.new();root.add_child(scene)
	var floor_body=StaticBody3D.new();var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(20,.2,20);collision.shape=box;floor_body.add_child(collision);scene.add_child(floor_body);floor_body.position.y=-.1
	var mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(20,20);mesh.mesh=plane;scene.add_child(mesh)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.15,.18,.2);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;scene.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,160,0);light.shadow_enabled=true;scene.add_child(light)
	var camera=Camera3D.new();camera.position=Vector3(4,4,-6);scene.add_child(camera);camera.look_at(Vector3(0,.5,0));camera.current=true
	var actors=[]
	for i in range(2):
		var actor=preload("res://lizard_actor.gd").new();actor.elite=i==1;actor.scale=Vector3.ONE*(1.5 if actor.elite else 1);actor.position=Vector3(i*2-1,1,0);scene.add_child(actor);actors.append(actor)
	await physics_frame;await physics_frame
	for actor in actors: actor.die(Vector3.ZERO,Vector3(1.5,.3,1))
	await create_timer(3).timeout
	for actor in actors:
		assert(actor.ragdoll.is_simulating_physics());assert(actor.ragdoll.get_child_count()==19)
		var pelvis=actor.ragdoll.get_node("Physics_Pelvis").global_position
		print("RAGDOLL_PELVIS ",pelvis)
		assert(pelvis.y>-.3 and pelvis.y<1,"Ragdoll must fall onto terrain and stay above it")
		for bone in actor.ragdoll.get_children(): assert(bone.global_position.distance_to(pelvis)<3,"Ragdoll must remain jointed")
	if OS.get_cmdline_user_args().has("--pictures"):
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/physics-ragdolls.png")
	print("PASS: both scales use 19 simulated jointed bodies and settle on terrain");quit()



