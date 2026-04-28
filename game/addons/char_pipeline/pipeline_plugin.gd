@tool
extends EditorPlugin

const PipelinePanel = preload("res://addons/char_pipeline/pipeline_panel.gd")

var _panel: Control

func _enter_tree() -> void:
	_panel = PipelinePanel.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _panel)

func _exit_tree() -> void:
	if _panel:
		remove_control_from_docks(_panel)
		_panel.queue_free()
		_panel = null
