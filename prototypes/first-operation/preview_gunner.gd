extends SceneTree
class PreviewArena extends Node3D:
	var camera: Camera3D
	var walker: CharacterBody3D
	func material(color: Color,_a: float,_b: float,emissive: bool) -> Material:
		var m=StandardMaterial3D.new();m.albedo_color=color
		if emissive: m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		return m
class PreviewMenu extends CanvasLayer:
	var opened=false
	var settings={"camera_mode":0,"camera_fov":75.0}
func _initialize(): call_deferred("run")
func run():
	var arena=PreviewArena.new();root.add_child(arena)
	var kit=preload("res://arena_kit.gd").new();kit.arena=arena;kit.warthog_menu=PreviewMenu.new();kit.menu=kit.warthog_menu
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.current=true;arena.camera.near=.5
	arena.walker=CharacterBody3D.new();var collision=CollisionShape3D.new();collision.shape=CapsuleShape3D.new();arena.walker.add_child(collision);arena.add_child(arena.walker)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.24,.3,.35);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;arena.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.shadow_enabled=true;arena.add_child(sun)
	var floor_mesh=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(30,30);floor_mesh.mesh=plane;arena.add_child(floor_mesh)
	var body=StaticBody3D.new();arena.add_child(body);kit.driving=body;kit.gunning=true
	var model=kit.imported(kit.GAME+"halo_warthog/scene.gltf");body.add_child(model);var a=kit.bounds(model)
	if a.size.x>a.size.z: model.rotation.y=-PI*.5
	model.rotate_y(PI);a=kit.bounds(model);model.scale*=4.8/a.size.z;a=kit.bounds(model);model.position-=Vector3(a.get_center().x,a.position.y,a.get_center().z)
	preload("res://warthog_finish.gd").finish(model,Callable(kit,"bounds"))
	var turret=preload("res://warthog_turret.gd").new();body.add_child(turret);turret.setup(kit,body,model);turret.set_physics_process(false)
	for yaw in [0,90,180,270]:
		for elevation in [-30,30]:
			kit.driver_look=Vector2(deg_to_rad(yaw),deg_to_rad(elevation));turret.yaw.rotation.y=kit.driver_look.x;turret.pitch.rotation.x=kit.driver_look.y;turret.crouch=0 if elevation<0 else 1
			turret.pose_player.seek(turret.crouch*turret.pose_player.get_animation(turret.crouch_clip).length,true)
			for mode in [0,1]:
				kit.warthog_menu.settings.camera_mode=mode;turret.update_camera()
				if mode==0:
					arena.camera.position=Vector3(4,3.6,4);arena.camera.look_at(Vector3(0,1.6,.8))
				await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://captures/pose-%d-%d-%d.png" % [yaw,elevation,mode])
	kit.warthog_menu.free();kit.free();print("PASS: all cardinal yaw and elevation-limit views captured");quit()
