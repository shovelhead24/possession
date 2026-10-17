extends "res://world/rebuild_demo.gd"
## The complete current Rebuild scene, with optional sky comparisons only.
var sky_comparison: Node

func _ready() -> void:
	super._ready()
	loading.free()
	loading=Loading.new();loading.brief_path="res://world/sky_demo_brief.json";add_child(loading)

func prepare_content() -> void:
	await super.prepare_content()
	sky_comparison=preload("res://world/sky_comparison.gd").new()
	add_child(sky_comparison);sky_comparison.setup(self)

func _input(event: InputEvent) -> void:
	if sky_comparison and ready_to_play and loading.dismissed and sky_comparison.handle_input(event):
		get_viewport().set_input_as_handled();return
	super._input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if ready_to_play and sky_comparison:
		hud.text=hud.text.replace("REBUILD DEMO /", "SKY DEMO /")
		hud.text+="\n"+sky_comparison.status()
