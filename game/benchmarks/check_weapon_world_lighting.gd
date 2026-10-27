extends SceneTree
class Lighting extends RefCounted:
	var sun: DirectionalLight3D
	var environment: Environment
class Review extends RefCounted:
	var moonlight: DirectionalLight3D
	var moon_fill: OmniLight3D
class Arena extends Node3D:
	var camera: Camera3D
	var daylight=Lighting.new()
	var cloud_review=Review.new()
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(960,640)
	var arena=Arena.new();root.add_child(arena)
	arena.camera=Camera3D.new();arena.add_child(arena.camera)
	arena.daylight.sun=DirectionalLight3D.new();arena.add_child(arena.daylight.sun)
	arena.daylight.sun.rotation_degrees=Vector3(-48,-35,0)
	arena.daylight.environment=Environment.new()
	arena.daylight.environment.ambient_light_color=Color(.78,.85,.94)
	arena.daylight.environment.ambient_light_energy=.48
	arena.cloud_review.moonlight=DirectionalLight3D.new();arena.add_child(arena.cloud_review.moonlight)
	arena.cloud_review.moonlight.light_energy=0
	arena.cloud_review.moon_fill=OmniLight3D.new();arena.add_child(arena.cloud_review.moon_fill)
	arena.cloud_review.moon_fill.light_energy=0
	var weapons=preload("res://world/rebuild_weapons.gd").new();arena.add_child(weapons);weapons.arena=arena
	weapons.build_overlay();weapons.container.show()
	var importer=preload("res://world/content_gallery.gd").new()
	var model=importer.import_source(ProjectSettings.globalize_path("res://../assets/halo-ce-plasma.glb"))
	model.rotation.y=PI*.5
	var bounds: AABB=importer.model_bounds(model)
	model.scale=Vector3.ONE*(.60/maxf(bounds.size.z,.001))
	bounds=importer.model_bounds(model);model.position=Vector3(-.06,-.04,-.08)-bounds.get_center()
	weapons.strip_ce_markers(model);weapons.holder.add_child(model)
	importer.contact_debug.free();importer.free()
	var lighting=weapons.world_lighting
	assert(lighting.sync(arena,.2))
	assert(not lighting.sync(arena,.2),"Stable lighting must keep the viewport cache")
	for state in ["day","turned","moon","gap"]:
		if state=="turned":arena.camera.rotate_y(PI*.65)
		if state=="moon":
			arena.daylight.sun.light_energy=0
			arena.daylight.environment.ambient_light_color=Color(.30,.40,.65)
			arena.daylight.environment.ambient_light_energy=.09
			arena.cloud_review.moonlight.light_color=Color(.52,.66,1)
			arena.cloud_review.moonlight.rotation_degrees=Vector3(-50,40,0)
			arena.cloud_review.moonlight.light_energy=.14
			arena.cloud_review.moon_fill.light_energy=.266
		if state=="gap":
			arena.cloud_review.moonlight.light_energy=0
			arena.cloud_review.moon_fill.light_energy=0
		lighting.sync(arena,.2,true)
		assert(is_equal_approx(lighting.sun.light_energy,arena.daylight.sun.light_energy))
		assert(is_equal_approx(lighting.moon.light_energy,arena.cloud_review.moonlight.light_energy))
		weapons.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/weapon-light-"+state+".png")
	print("WEAPON_LIGHT_PASS day, rotation, moon, dark gap, unchanged-cache retention")
	quit()
