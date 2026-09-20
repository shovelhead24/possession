extends SceneTree
class Fixture extends Node:
	var arena: Node3D
	var driving=null
class Arena extends Node3D:
	var walker: CharacterBody3D
func _initialize(): call_deferred("run")
func run():
	var world=Arena.new();root.add_child(world);world.walker=CharacterBody3D.new();world.add_child(world.walker)
	var kit=Fixture.new();kit.arena=world;world.add_child(kit)
	var importer=preload("res://arena_kit.gd").new();var model=importer.imported(importer.GAME+"altay_main_battle_tank_fbx.glb");world.add_child(model)
	var a=importer.bounds(model)
	if a.size.x>a.size.z: model.rotation.y=-PI*.5
	model.rotate_y(PI);a=importer.bounds(model);model.scale*=9.0/a.size.z;a=importer.bounds(model);model.position-=Vector3(a.get_center().x,a.position.y,a.get_center().z)
	var tank=preload("res://tank_controller.gd").new();world.add_child(tank);model.reparent(tank,true)
	var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(2.84,.9,6.66);collision.shape=shape;collision.position.y=.45;tank.add_child(collision);tank.floor_snap_length=1;tank.setup(model,kit)
	var floor_body=StaticBody3D.new();var floor_shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(100,1,100);floor_shape.shape=box;floor_body.add_child(floor_shape);world.add_child(floor_body);floor_body.position.y=-.5
	await physics_frame
	assert(tank.tracks.sides.size()==2 and tank.tracks.sides[0].mesh.instance_count==62 and tank.tracks.sides[1].mesh.instance_count==62)
	tank.probe_traction();assert(tank.contact_counts==Vector2i(8,8),"Eight probes on both tracks must contact flat ground")
	for step in range(90): await physics_frame;tank.drive_step(1.0/60,1,1,false)
	assert(tank.position.z< -3 and tank.track_speeds.x>5,"Forward drive")
	await physics_frame;tank.drive_step(1.0/60,0,0,false)
	assert(Vector2(tank.velocity.x,tank.velocity.z).length()<.01 and tank.track_speeds==Vector2.ZERO,"Neutral input must stop the hull")
	for step in range(90): await physics_frame;tank.drive_step(1.0/60,1,1,false)
	for step in range(2): await physics_frame;tank.drive_step(1.0/60,0,0,true)
	assert(tank.track_speeds.length()<.01 and Vector2(tank.velocity.x,tank.velocity.z).length()<.01,"Braking")
	var heading=tank.heading
	for step in range(90): await physics_frame;tank.drive_step(1.0/60,-1,1,false)
	assert(tank.track_speeds.x<0 and tank.track_speeds.y>0 and tank.heading>heading+.5,"Opposed tracks must pivot")
	# Camera/turret aim cannot rotate the locomotion frame, and contact impulses
	# cannot turn a commanded hull turn into a persistent lateral slide.
	tank.track_speeds=Vector2.ZERO
	var aim_before=tank.heading;var sideways=Vector3(12,0,0);tank.velocity=sideways
	for step in range(60): await physics_frame;tank.drive_step(1.0/60,1,1,false)
	var hull_forward=Vector3(-sin(tank.heading),0,-cos(tank.heading));var hull_right=Vector3(cos(tank.heading),0,-sin(tank.heading))
	assert(abs(Vector3(tank.velocity.x,0,tank.velocity.z).dot(hull_right))<.1,"Hull must shed lateral slide")
	assert(absf(tank.heading-aim_before)<.01,"Forward motion must not follow camera aim")
	tank.transform=Transform3D.IDENTITY;tank.heading=0;tank.velocity=Vector3.ZERO;tank.track_speeds=Vector2.ZERO
	for step in range(60): await physics_frame;tank.drive_step(1.0/60,-1,0,false)
	assert(tank.position.z>1,"Reverse drive")
	tank.transform=Transform3D(Basis.IDENTITY,Vector3(0,10,0));tank.heading=0;tank.velocity=Vector3.ZERO
	await physics_frame;tank.drive_step(1.0/60,1,-1,false)
	assert(tank.traction==Vector2.ZERO and absf(tank.velocity.x)+absf(tank.velocity.z)<.001 and tank.heading==0,"No propulsion or steering airborne")
	# Put only the left track above a narrow strip of ground.
	box.size=Vector3(1,1,100);floor_body.position.x=-1.235;tank.transform=Transform3D.IDENTITY;tank.velocity=Vector3.ZERO
	await physics_frame;tank.probe_traction();assert(tank.contact_counts==Vector2i(8,0),"Independent left/right contact")
	if OS.get_cmdline_user_args().has("--pictures"):
		var light=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-45,-40,0)
		var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.25,.3,.35);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.6;world.add_child(env)
		var camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(-9,3,6);camera.look_at(Vector3(0,1,0));camera.current=true
		for frame in range(2):
			tank.tracks.animate(.15,2,2);await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/tank-tracks-%d.png"%frame)
	importer.free();print("PASS: track links, forward, reverse, brakes, pivot, airborne and one-sided traction");quit()
