extends Node
## Tree-demo-only daylight controls. No terrain or paint save writes.
var arena: Node3D
var sun: DirectionalLight3D
var environment: Environment
var dialog: AcceptDialog
var elevation := 48.0
var azimuth := -30.0
var energy := 1.0
var ambient := 0.48
var shadows := true
var baseline := false
var clock := 0.0
var shadow_quality := 0 # 0 balanced proxies, 1 fast proxies, 2 original detailed trees
var proxies: Node3D
var applied_quality := -1
var shadow_distance := 121.0
var near_split_percent := 12.0
var blend_splits := false
var shadow_filter := 1 # Compatibility: hard, 5-tap PCF, 13-tap PCF
var applied_filter := -1
var filter_control: OptionButton
var distance_slider: HSlider
var split_slider: HSlider
var split_number: SpinBox
var blend_toggle: CheckButton
var split_note: Label
var original_rotation: Vector3
var original_color: Color
var original_ambient: Color
var original_energy: float
var original_ambient_energy: float

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena
	process_priority=101
	proxies=preload("res://world/tree_shadow_proxy.gd").new();arena.add_child(proxies);proxies.setup(arena.trees)
	if arena.backdrop:
		var shader := Shader.new()
		shader.code=arena.backdrop._mat.shader.code.replace("uniform vec3 to_sun","uniform vec3 daylight_sun = vec3(1.0);
 uniform vec3 daylight_ambient = vec3(1.0);
 uniform vec3 to_sun").replace("(0.20 + 0.80 * diffuse)","(0.20 * daylight_ambient + 0.80 * diffuse * daylight_sun)")
		arena.backdrop._mat.shader=shader
	for child in arena.get_children():
		if child is DirectionalLight3D: sun=child
		if child is WorldEnvironment: environment=child.environment
	assert(sun != null and environment != null)
	original_rotation=sun.rotation
	original_color=sun.light_color;original_energy=sun.light_energy
	original_ambient=environment.ambient_light_color;original_ambient_energy=environment.ambient_light_energy
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance=shadow_distance
	sun.directional_shadow_fade_start=0.75
	sun.shadow_bias=0.3
	sun.shadow_normal_bias=3.0
	RenderingServer.directional_shadow_atlas_set_size(2048,false)
	dialog=AcceptDialog.new();dialog.title="Daylight · session settings";dialog.min_size=Vector2i(560,520);arena.add_child(dialog)
	var column := VBoxContainer.new();dialog.add_child(column)
	var note := Label.new();note.text="One sun shared by terrain, trees and backdrop.\nQuality presets reset distance: Balanced / Detailed 121 m, Fast 45 m.";column.add_child(note)
	row(column,"Sun elevation",10,85,elevation,func(v): elevation=v;apply())
	row(column,"Sun azimuth",-180,180,azimuth,func(v): azimuth=v;apply())
	row(column,"Sun brightness",0.2,2.0,energy,func(v): energy=v;apply(),0.05)
	row(column,"Ambient brightness",0.1,1.0,ambient,func(v): ambient=v;apply(),0.01)
	var shadow_toggle := CheckButton.new();shadow_toggle.text="Near shadows (measure performance)";column.add_child(shadow_toggle);shadow_toggle.button_pressed=shadows
	shadow_toggle.toggled.connect(func(v): shadows=v;apply();refresh_casters())
	var quality := OptionButton.new();quality.add_item("Balanced · simplified tree shadows",0);quality.add_item("Fast · 45 m / one shadow split",1);quality.add_item("Detailed · original leaf-card shadows",2);column.add_child(quality)
	quality.item_selected.connect(func(index):
		shadow_quality=index
		shadow_distance=45.0 if index==1 else 121.0
		distance_slider.set_value_no_signal(shadow_distance)
		apply();refresh_casters())
	distance_slider=slider_row(column,"Shadow distance (m)",10,200,shadow_distance,func(v): shadow_distance=v;apply())
	split_slider=slider_row(column,"Near cascade split (%)",1,90,near_split_percent,func(v): near_split_percent=v;apply())
	split_number=split_slider.get_parent().get_child(2) as SpinBox
	blend_toggle=CheckButton.new();blend_toggle.text="Blend shadow cascades";column.add_child(blend_toggle)
	blend_toggle.toggled.connect(func(v): blend_splits=v;apply())
	split_note=Label.new();split_note.add_theme_font_size_override("font_size",12);column.add_child(split_note)
	var filter_line := HBoxContainer.new();column.add_child(filter_line)
	var filter_label := Label.new();filter_label.text="Shadow edge filter";filter_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filter_line.add_child(filter_label)
	filter_control=OptionButton.new();filter_control.add_item("Sharp",0);filter_control.add_item("Soft · 5 samples",1);filter_control.add_item("Softer · 13 samples",2);filter_line.add_child(filter_control);filter_control.select(shadow_filter)
	filter_control.item_selected.connect(func(index): shadow_filter=index;apply())
	filter_control.tooltip_text="Sharp reduces blur but exposes shadow-map pixels. Cascade blending is a separate setting."
	var compare := CheckButton.new();compare.text="Compare original lighting";column.add_child(compare)
	compare.toggled.connect(func(v): baseline=v;apply();refresh_casters())
	var footer := Label.new();footer.text="Comparison restores original sun + ambient and disables shadows.\nSettings reset on restart. F11 toggles the frame cap.";footer.add_theme_font_size_override("font_size",12);column.add_child(footer)
	apply();refresh_casters()

func row(column: VBoxContainer, title: String, low: float, high: float, value: float, callback: Callable, step := 1.0) -> void:
	var line := HBoxContainer.new();column.add_child(line)
	var label := Label.new();label.text=title;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(label)
	var control := SpinBox.new();control.min_value=low;control.max_value=high;control.step=step;control.value=value;line.add_child(control);control.value_changed.connect(callback)

func slider_row(column: VBoxContainer, title: String, low: float, high: float, value: float, callback: Callable) -> HSlider:
	var line := HBoxContainer.new();column.add_child(line)
	var label := Label.new();label.text=title;label.custom_minimum_size.x=190;line.add_child(label)
	var slider := HSlider.new();slider.min_value=low;slider.max_value=high;slider.step=1;slider.value=value
	slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;slider.custom_minimum_size.x=150;line.add_child(slider)
	var number := SpinBox.new();line.add_child(number);slider.share(number)
	slider.value_changed.connect(callback)
	return slider

func apply() -> void:
	if baseline:
		sun.rotation=original_rotation;sun.light_color=original_color;sun.light_energy=original_energy
		environment.ambient_light_color=original_ambient;environment.ambient_light_energy=original_ambient_energy
	else:
		sun.rotation_degrees=Vector3(-elevation,azimuth,0)
		sun.light_color=Color(1.0,0.96,0.90);sun.light_energy=energy
		environment.ambient_light_color=Color(0.78,0.85,0.94);environment.ambient_light_energy=ambient
	sun.shadow_enabled=shadows and not baseline
	if applied_quality!=shadow_quality:
		applied_quality=shadow_quality
		sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL if shadow_quality==1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		RenderingServer.directional_shadow_atlas_set_size(1024 if shadow_quality==1 else 2048,false)
	if applied_filter!=shadow_filter:
		applied_filter=shadow_filter
		var filters := [RenderingServer.SHADOW_QUALITY_HARD,RenderingServer.SHADOW_QUALITY_SOFT_LOW,RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
		RenderingServer.directional_soft_shadow_filter_set_quality(filters[shadow_filter])
	sun.directional_shadow_max_distance=shadow_distance
	sun.directional_shadow_split_1=near_split_percent/100.0
	sun.directional_shadow_blend_splits=blend_splits
	if split_slider:
		var cascaded := shadow_quality!=1
		split_slider.editable=cascaded;split_number.editable=cascaded;blend_toggle.disabled=not cascaded
		split_note.text=("Near cascade ends at approximately %.1f m; shadows fade from %.1f m." % [shadow_distance*near_split_percent/100.0,shadow_distance*0.75]) if cascaded else "Fast uses one cascade: split and blending are inactive."
	if arena.backdrop:
		arena.backdrop._mat.set_shader_parameter("daylight_sun",Vector3.ONE if baseline else Vector3(sun.light_color.r,sun.light_color.g,sun.light_color.b)*energy/original_energy)
		arena.backdrop._mat.set_shader_parameter("daylight_ambient",Vector3.ONE if baseline else Vector3.ONE*ambient/original_ambient_energy)
	arena.frame_times.clear()

func refresh_casters() -> void:
	var enabled := shadows and not baseline
	for entry in arena.tile_entries.values():
		var tile: MeshInstance3D=entry.visual
		if is_instance_valid(tile): tile.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for patch in [arena.trees,arena.painted_trees]:
		for key in patch.batches:
			patch.batches[key].cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled and shadow_quality==2 and key.w<2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	proxies.refresh(arena,enabled and shadow_quality!=2)

func _process(delta: float) -> void:
	if arena and arena.backdrop:
		arena.backdrop._sky_mat.set_shader_parameter("local_up",preload("res://world/terrain_drive_ring.gd").up_at(arena.camera.global_position))
	clock+=delta
	if clock<0.25 or arena==null: return
	clock=0.0;refresh_casters()
