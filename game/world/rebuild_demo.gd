extends "res://world/tree_demo.gd"
var rebuild_content: Node3D
var forge: Node3D
var aliens: Node3D
var weapons: Node
var collision_debug: Node3D
var actors: Node3D
var ai_debug: CanvasLayer
var controller: Node
var devices: Node
var dev_reload: Node

func _ready() -> void:
	super._ready()
	devices=preload("res://world/rebuild_devices.gd").new();add_child(devices);devices.setup(self)
	loading.free();loading=Loading.new();loading.brief_path="res://world/rebuild_demo_brief.json";add_child(loading)

func prepare_content() -> void:
	await super.prepare_content()
	for patch in [trees,painted_trees]:
		patch.foliage_budget=preload("res://world/tree_foliage_budget.gd").new()
		patch.foliage_budget.configure(patch.variants,patch.names);patch.foliage_budget.enabled=false;patch.dirty=true
	painted_trees.prepare_density()
	# Construction uses layer 2, just like the chassis; wheels must query it too.
	vehicle_kit.car.suspension_mask=1|2|4
	if not OS.get_cmdline_user_args().has("--no-rebuild-content"):
		loading.log_event("Restoring batched building with original doors and collision")
		rebuild_content=preload("res://world/rebuild_buildings.gd").new()
		add_child(rebuild_content);rebuild_content.setup(self)
	loading.log_event("Preparing construction palette and saved layouts")
	forge=preload("res://world/forge_world.gd").new();add_child(forge);forge.setup(self)
	collision_debug=preload("res://world/rebuild_collision_debug.gd").new();add_child(collision_debug);collision_debug.setup(self)
	editor.cursor.free();editor.guide.free();editor.free()
	dev_reload=preload("res://world/rebuild_dev_reload.gd").new();dev_reload.arena=self;add_child(dev_reload)
	editor=preload("res://world/actor_editor.gd").new();add_child(editor);editor.setup(self)
	weapons=preload("res://world/rebuild_weapons.gd").new();add_child(weapons);await weapons.setup(self)
	aliens=preload("res://world/aliens/manager.gd").new();add_child(aliens);await aliens.setup(self)
	actors=preload("res://world/actor_world.gd").new();add_child(actors);actors.setup(self)
	editor.connect_actors(actors)
	ai_debug=preload("res://world/ai_diagnostics.gd").new();add_child(ai_debug);ai_debug.setup(self)
	controller=preload("res://world/rebuild_controller.gd").new();add_child(controller);controller.source_mode=devices.controller_mode;controller.setup(self)
	devices.add_menu(vehicle_kit.menu)
	loading.log_event("Restoring reduced-detail Altay tank, tracks and cannon")
	vehicle_kit.restore_tank()

func _input(event: InputEvent) -> void:
	if dev_reload and event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode==KEY_F6:
		dev_reload.request();get_viewport().set_input_as_handled();return
	if controller and controller.intercept(event): return
	if ai_debug and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F4:
		ai_debug.enabled=not ai_debug.enabled;get_viewport().set_input_as_handled();return
	if collision_debug and ready_to_play and loading.dismissed and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_TAB:
		collision_debug.toggle_hud();get_viewport().set_input_as_handled();return
	if aliens and aliens.handle_input(event): return
	if weapons and weapons.handle_input(event): return
	super._input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if ready_to_play:
		hud.text="REBUILD DEMO / tactical aliens + weapons + construction\n"+hud.text
		if rebuild_content: hud.text+="\n"+rebuild_content.status

		if forge: hud.text+="\n"+forge.status()
		if aliens: hud.text+="\n"+aliens.status()
		if actors: hud.text+="\n"+actors.status()
