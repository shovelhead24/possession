extends SceneTree
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grip-output="): output=arg.trim_prefix("--grip-output=")
	run.call_deferred()
func run() -> void:
	var world=Node3D.new();root.add_child(world)
	var camera=Camera3D.new();world.add_child(camera);camera.near=.01;camera.fov=65;camera.make_current()
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.18,.22,.25);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.7;world.add_child(env)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);world.add_child(light)
	var holder=Node3D.new();holder.position=Vector3(.3,-.25,-.5);camera.add_child(holder)
	var importer=preload("res://world/content_gallery.gd").new()
	var arms=importer.import_source(ProjectSettings.globalize_path("res://../assets/fp_arms.zip"))
	preload("res://world/rebuild_weapons.gd").stop_animations(arms)
	arms.set_script(preload("res://fp_arms_controller.gd"))
	arms.transform=Transform3D(Basis(Vector3(-.180993,0,.010583),Vector3(0,.1813025,0),Vector3(-.010583,0,-.180993)),Vector3(-.29,.19,.45));holder.add_child(arms)
	var model=importer.import_source(ProjectSettings.globalize_path("res://../assets/halo-ce-plasma.glb"))
	model.rotation.y=PI*.5
	var bounds: AABB=importer.model_bounds(model)
	model.scale=Vector3.ONE*(.60/maxf(bounds.size.z,.001));bounds=importer.model_bounds(model)
	model.position=Vector3(-.06,-.04,-.08)-bounds.get_center();holder.add_child(model)
	preload("res://world/rebuild_weapons.gd").strip_ce_markers(model)
	arms.set_weapon_pose("plasma");arms.align_grip(Vector3(.006,-.085,-.085),3.0)
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material=mesh.get_active_material(surface)
			print("SURFACE ",surface," ",material.resource_name)
			var points=[]
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point=holder.to_local(mesh.to_global(vertex))
				if point.y>-.14 and point.y<-.04 and point.z>-.13 and point.z<-.035: points.append(point.x)
			if not points.is_empty(): points.sort();print("GRIP X ",points[0]," ",points[points.size()/2]," ",points[-1])
	for i in 5: await process_frame
	var rig: Skeleton3D=arms.skeleton
	for i in rig.get_bone_count():
		if rig.get_bone_name(i).begins_with("R_"):
			print("BONE ",i," ",rig.get_bone_name(i)," holder=",holder.to_local(rig.to_global(rig.get_bone_global_pose(i).origin)))
	print("MODEL ",model.transform," BOUNDS ",importer.model_bounds(model))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output)
	var side=Camera3D.new();world.add_child(side);side.projection=Camera3D.PROJECTION_ORTHOGONAL;side.size=.85;side.near=.001
	side.position=holder.global_position+Vector3(1,0,0);side.look_at(holder.global_position+Vector3(0,0,0));side.make_current()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.replace(".png","-side.png"))
	var loading=preload("res://world/workshop_loading.gd").new();loading.brief_path="res://world/rebuild_demo_brief.json";world.add_child(loading)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.replace(".png","-brief.png"))
	importer.contact_debug.free();importer.free();quit()
