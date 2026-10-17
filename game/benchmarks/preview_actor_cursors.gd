extends SceneTree
class Kit extends RefCounted:
	var actor_template: PackedScene
class Arena extends Node3D:
	var vehicle_kit=Kit.new()
func _initialize():
	create_timer(100).timeout.connect(func(): quit(1))
	run.call_deferred()
func run():
	root.size=Vector2i(1000,700)
	var arena=Arena.new();root.add_child(arena)
	var camera=Camera3D.new();arena.add_child(camera);camera.current=true
	var environment=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.12,.16,.2);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.8;environment.environment=env;arena.add_child(environment)
	var light=DirectionalLight3D.new();arena.add_child(light);light.rotation_degrees=Vector3(-40,-30,0)
	var importer=preload("res://world/arena_live_content.gd").new()
	var model=importer.import_source(ProjectSettings.globalize_path("res://../assets/halo_warthog.zip"))
	var bounds=importer.model_bounds(model)
	if bounds.size.x>bounds.size.z: model.rotate_y(-PI/2)
	model.rotate_y(PI);bounds=importer.model_bounds(model);model.scale*=4.8/maxf(bounds.size.x,bounds.size.z);bounds=importer.model_bounds(model);model.position-=Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)
	preload("res://world/warthog_finish.gd").finish(model,Callable(importer,"model_bounds"))
	for child in model.find_children("*","",true,false): child.owner=model
	arena.vehicle_kit.actor_template=PackedScene.new();arena.vehicle_kit.actor_template.pack(model);model.free()
	var preview=preload("res://world/actor_preview.gd").new();arena.add_child(preview)
	for kind in ["grunt","captain","squad","crate","warthog","trex"]:
		preview.configure(kind,arena);preview.place(Vector3.ZERO,0)
		for i in 3: await process_frame
		assert(preview.find_children("*","CollisionObject3D",true,false).is_empty())
		assert(preview.find_children("*","AudioStreamPlayer3D",true,false).is_empty())
		bounds=importer.model_bounds(preview)
		print(kind," bounds=",bounds)
		var centre=bounds.get_center();var distance=maxf(bounds.size.length(),3)*1.05
		camera.position=centre+Vector3(.7,.35,1).normalized()*distance;camera.look_at(centre)
		var label=Label.new();label.text=kind+" / visual-only placement cursor";label.position=Vector2(20,20);root.add_child(label)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs/cursor-"+kind+".png")
		label.free()
	importer.contact_debug.free();importer.free()
	print("PASS actor cursor visuals: six kinds, no physics bodies or audio")
	quit()
