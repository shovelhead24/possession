extends "res://world/terrain_drive.gd"
var trees: Node3D
var tree_view := 0
var painted_trees: Node3D
var daylight: Node
var edited_render_lods: Node
var on_foot: CharacterBody3D

func _ready() -> void:
	super._ready()
	# Base build is deferred; replace its briefing before loading starts.
	loading.free()
	loading=Loading.new();loading.brief_path="res://world/tree_demo_brief.json";add_child(loading)

func prepare_content() -> void:
	await super.prepare_content()
	loading.log_event("Preparing fir meshes and original billboard LODs")
	trees=preload("res://world/tree_patch.gd").new();add_child(trees);trees.setup(self)
	painted_trees=preload("res://world/tree_paint.gd").new();add_child(painted_trees);painted_trees.setup(self)
	edited_render_lods=preload("res://world/tree_edited_terrain_lods.gd").new();add_child(edited_render_lods);edited_render_lods.setup(self)
	daylight=preload("res://world/tree_daylight.gd").new();add_child(daylight);daylight.setup(self)
	on_foot=preload("res://world/tree_on_foot.gd").new();add_child(on_foot);on_foot.setup(self)
	# Replace only this scene's editor with the terrain-editor extension.
	editor.cursor.free();editor.guide.free();editor.free()
	editor=preload("res://world/tree_paint_editor.gd").new();add_child(editor);editor.setup(self)
	if OS.get_cmdline_user_args().has("--no-trees"): trees.set_enabled(false);painted_trees.set_enabled(false)

func _input(event: InputEvent) -> void:
	if on_foot and on_foot.handle_input(event): return
	if ready_to_play and loading.dismissed and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F6:
				trees.set_enabled(not trees.enabled);painted_trees.set_enabled(trees.enabled);frame_times.clear();return
			KEY_F9:
				editor.finish_paint();editor.finish_stroke();set_tree_view(tree_view);tree_view=(tree_view+1)%3;return
			KEY_F10:
				trees.forced_lod=(trees.forced_lod+2)%5-1;painted_trees.forced_lod=trees.forced_lod
				trees.update_batches();painted_trees.update_batches();frame_times.clear();return
			KEY_F11: Engine.max_fps=0 if Engine.max_fps!=0 else 120;frame_times.clear();return
	super._input(event)

func set_tree_view(index: int) -> void:
	if on_foot: on_foot.deactivate()
	vehicle_kit.driving=false
	var positions := [Vector2(100,180),Vector2(310,210),Vector2(100,650)]
	var coord: Vector2=positions[index]
	var ground := tree_view_ground(coord)
	camera.position=ground+Ring.up_at(ground)*(5 if index==0 else 22)
	var target_coord := Vector2(115,320)
	var target := tree_view_ground(target_coord)
	camera.look_at(target+Ring.up_at(target)*6,Ring.up_at(camera.position))
	frame_times.clear()

func tree_view_ground(coord: Vector2) -> Vector3:
	var h: float=source.surface_height(coord)
	var estimated := Ring.point(coord.x,h,coord.y);var up := Ring.up_at(estimated)
	var query := PhysicsRayQueryParameters3D.create(estimated+up*250,estimated-up*250,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else estimated

func _process(delta: float) -> void:
	var old_diagnostic := diagnostic
	if on_foot and on_foot.active: diagnostic=true
	super._process(delta)
	diagnostic=old_diagnostic
	if ready_to_play and trees:
		# Parent rewrites its HUD every frame; append once after it.
		hud.text+="\n"+painted_trees.status()+" | "+("AUTO" if painted_trees.forced_lod<0 else "FORCED LOD "+str(painted_trees.forced_lod))
		hud.text+="\nPainted trees: %d | %s | F1 paint / erase" % [painted_trees.store.records.size(),"Unsaved" if painted_trees.store.unsaved() else "Saved"]


	if ready_to_play and on_foot:
		hud.text=hud.text.replace("E fly/drive","E exit / enter vehicle")
		if on_foot.active:
			hud.text=hud.text.replace("WASD drive · Space brake · C camera · E exit / enter vehicle · R recover","WASD walk · Shift sprint · Space jump · E enter vehicle")
			hud.text=hud.text.replace("RMB look · Shift fast flight","Mouse look · Esc cursor")
			hud.text+="\nON FOOT · WASD walk · Shift sprint · Space jump · E enter · Esc cursor · Click to look"
		if not on_foot.notice.is_empty(): hud.text+="\n"+on_foot.notice
