@tool
extends EditorPlugin

var _gizmo: CageMeshGizmoPlugin
var _panel: CagePanel

func _enter_tree() -> void:
	_gizmo = CageMeshGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_gizmo)

	_panel = CagePanel.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _panel)

func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmo)
	_gizmo = null
	if _panel:
		remove_control_from_docks(_panel)
		_panel.queue_free()
		_panel = null
