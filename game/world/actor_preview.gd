extends Node3D
## Visual-only placement models: no AI, collision, audio or encounter registration.
const Lizard=preload("res://world/aliens/lizard_actor.gd")
const Rex=preload("res://world/aliens/trex.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
var kind := ""
func configure(value: String, arena: Node3D) -> void:
	if kind==value: return
	kind=value
	for child in get_children(): child.free()
	if kind in ["grunt","captain","squad"]:
		for i in (5 if kind=="squad" else 1):
			var visual=Lizard.new();visual.elite=kind=="captain" or (kind=="squad" and i==0)
			visual.scale=Vector3.ONE*(1.5 if visual.elite else 1.0);add_child(visual)
			if kind=="squad": visual.position=Vector3((i%3-1)*2.0,0,(i/3)*2.5)
			if visual.player: visual.player.advance(.05);visual.player.pause()
			visual.set_process(false)
	elif kind=="warthog":
		if arena.vehicle_kit.actor_template: add_child(arena.vehicle_kit.actor_template.instantiate())
	elif kind=="tank":
		var factory=preload("res://world/rebuild_tank_factory.gd");factory.prepare()
		var model=factory.template.instantiate();add_child(model);preload("res://world/tank_finish.gd").apply(model)
		preload("res://world/rigid_mesh_batch.gd").combine(model,[],"rebuild-tank-preview-v2"+FileAccess.get_sha256("res://altay_main_battle_tank_fbx.glb"))
	elif kind=="crate":
		var source=preload("res://world/heavy_crate.gd").new()
		# Build visuals without entering the tree or invoking the body's _ready.
		source.build_visuals()
		for child in source.get_children(): source.remove_child(child);add_child(child);child.position.y+=.96
		source.free()
	elif kind=="trex":
		if not Rex.cached_model:
			var doc=GLTFDocument.new();var state=GLTFState.new()
			if doc.append_from_file(ProjectSettings.globalize_path("res://../assets/rigged-t-rex-fabulous/source/rigged_t-rex_fabulous.glb"),state)!=OK: return
			var source=doc.generate_scene(state);Rex.cached_model=PackedScene.new();Rex.cached_model.pack(source);source.free()
		var model=Rex.cached_model.instantiate();add_child(model)
		var raw=preload("res://world/content_gallery.gd").new()
		var bounds=raw.model_bounds(model);model.scale*=Rex.SCALE_HEIGHT/maxf(bounds.size.y,.01)*Rex.SIZE_MULTIPLIER
		raw.contact_debug.free();raw.free()
		var importer=preload("res://world/arena_live_content.gd").new()
		bounds=importer.model_bounds(model);model.position.x-=bounds.get_center().x;model.position.z-=bounds.get_center().z;model.rotate_y(PI)
		var player=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
		if player:
			for clip in player.get_animation_list():
				if player.get_animation(clip).length>Rex.WALK_FIRST_FRAME/30.0:
					player.play(clip);player.seek(Rex.WALK_FIRST_FRAME/30.0,true);player.pause();break
		importer.contact_debug.free();importer.free()
	for mesh in find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end=0
	for player in find_children("*","AnimationPlayer",true,false): player.pause()
func place(point: Vector3, yaw: float) -> void:
	transform=Transform3D(Ring.tangent_basis(point,deg_to_rad(yaw)),point)
	show()
