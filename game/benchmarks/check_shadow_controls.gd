extends SceneTree
class Patch extends Node3D:
	var names := []
	var shadow_revision := 0
	var enabled := false
	var count_limit := 0
	var batches := {}
class Arena extends Node3D:
	var backdrop = null
	var trees: Node3D
	var painted_trees: Node3D
	var tile_entries := {}
	var frame_times := []
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var arena := Arena.new();root.add_child(arena)
	arena.trees=Patch.new();arena.add_child(arena.trees)
	arena.painted_trees=Patch.new();arena.add_child(arena.painted_trees)
	var sun := DirectionalLight3D.new();arena.add_child(sun)
	var world := WorldEnvironment.new();world.environment=Environment.new();world.environment.ambient_light_energy=0.65;arena.add_child(world)
	var controls = load("res://world/tree_daylight.gd").new();arena.add_child(controls);controls.setup(arena)
	assert(is_equal_approx(sun.directional_shadow_max_distance,121.0))
	assert(controls.filter_control.selected==1 and controls.applied_filter==1)
	assert(not sun.directional_shadow_blend_splits)
	controls.distance_slider.value=100
	controls.split_slider.value=25
	controls.blend_toggle.button_pressed=true
	assert(is_equal_approx(sun.directional_shadow_max_distance,100.0))
	assert(is_equal_approx(sun.directional_shadow_split_1,0.25))
	assert(sun.directional_shadow_blend_splits)
	controls.split_number.value=30
	assert(is_equal_approx(sun.directional_shadow_split_1,0.30))
	controls.energy=1.5;controls.apply()
	assert(is_equal_approx(sun.directional_shadow_max_distance,100.0))
	var quality: OptionButton
	for child in controls.dialog.get_child(0).get_children():
		if child is OptionButton: quality=child
	assert(quality!=null)
	quality.item_selected.emit(1)
	assert(is_equal_approx(sun.directional_shadow_max_distance,45.0))
	assert(is_equal_approx(controls.distance_slider.value,45.0))
	assert(not controls.split_slider.editable and controls.blend_toggle.disabled)
	controls.distance_slider.value=60
	assert(is_equal_approx(sun.directional_shadow_max_distance,60.0))
	quality.item_selected.emit(0)
	assert(is_equal_approx(sun.directional_shadow_max_distance,121.0))
	assert(controls.split_slider.editable and not controls.blend_toggle.disabled)
	controls.blend_toggle.button_pressed=false
	assert(not sun.directional_shadow_blend_splits)
	controls.filter_control.item_selected.emit(1)
	assert(controls.shadow_filter==1 and controls.applied_filter==1)
	controls.filter_control.item_selected.emit(2)
	assert(controls.applied_filter==2)
	controls.filter_control.item_selected.emit(0)
	assert(controls.applied_filter==0)
	assert(is_equal_approx(sun.shadow_normal_bias,3.0))
	print("SHADOW_CONTROLS_PASS: UI values, numeric entry, preset resets, single-cascade state and blending")
	quit()
