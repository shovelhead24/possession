extends Node
const Clouds=preload("res://mocks/ring_clouds.gd")
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var original_sky: Sky
var painted_sky: Sky
var painted_material: ShaderMaterial
var clouds: Node3D
var painted := false
var clouds_enabled := false
var elapsed := 0.0
var sky_toggle: CheckButton
var cloud_toggle: CheckButton
var weather: OptionButton
var weather_index := 2 # Original user-tuned "fresh" preset.
var legacy: Node3D
var mc_toggle: CheckButton
var billboard_toggle: CheckButton
var layer_toggle: CheckButton
var dialog: AcceptDialog
var preset_picker: OptionButton
var brightness := 1.0
var high_painterly: MeshInstance3D
var upper_altitude := 6000.0
var haze_enabled := true
var haze_strength := 1.0
var haze_reach_km := 100.0
var weather_haze_density := 0.0
var coverage_variation := 0.8
const PRESETS := ["Rebuild baseline", "Billboard clouds", "Marching cubes", "Legacy three layers", "Ring five layers", "High painterly layer", "Marching cubes + billboards", "Billboards + high cirrus", "Marching cubes + billboards + high cirrus", "Billboards + high painterly layer"]

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena
	# GL depth at the antipode rounded to the sky's far depth with near=0.2.
	# 0.5 preserves the opaque ring; weapons have their own 0.01 m camera.
	arena.camera.near=0.5
	process_priority=102
	original_sky=arena.daylight.environment.sky
	# Clone shader code so the controls only affect this scene's materials.
	for mat in [arena.backdrop._mat,arena.backdrop._wall_mat]:
		if not mat: continue
		var shader=Shader.new()
		shader.code=mat.shader.code.replace("uniform float haze_density", "uniform float haze_strength = 1.0;\nuniform float haze_density").replace("1.0 - exp(-haze_density * dist)", "haze_strength * (1.0 - exp(-haze_density * dist))").replace("1.0 - exp(-haze_density * 0.30 * dist)", "haze_strength * (1.0 - exp(-haze_density * 0.30 * dist))")
		mat.shader=shader
	painted_material=ShaderMaterial.new()
	painted_material.shader=preload("res://world/sky_painterly_background.gdshader")
	painted_sky=Sky.new();painted_sky.sky_material=painted_material
	# Sky colour changes must not replace the existing terrain/actor lighting.
	dialog=AcceptDialog.new();dialog.title="Sky and cloud comparisons";dialog.min_size=Vector2i(540,380);arena.add_child(dialog)
	dialog.add_to_group("controller_modal_ui")
	var column=VBoxContainer.new();dialog.add_child(column)
	var button=Button.new();button.text="Sky and cloud comparisons... (Ctrl+F3)"
	arena.daylight.dialog.get_child(0).add_child(button)
	button.pressed.connect(func(): dialog.popup_centered())
	dialog.visibility_changed.connect(func():
		if dialog.visible: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	)
	preset_picker=OptionButton.new();column.add_child(preset_picker)
	for label in PRESETS: preset_picker.add_item(label)
	preset_picker.item_selected.connect(apply_preset)
	sky_toggle=CheckButton.new();sky_toggle.text="High painterly cloud layer (Ctrl+F9)";column.add_child(sky_toggle)
	sky_toggle.toggled.connect(set_painted)
	cloud_toggle=CheckButton.new();cloud_toggle.text="Ring cloud deck (Ctrl+F10)";column.add_child(cloud_toggle)
	cloud_toggle.toggled.connect(set_clouds)
	billboard_toggle=CheckButton.new();billboard_toggle.text="Billboard clouds";column.add_child(billboard_toggle)
	mc_toggle=CheckButton.new();mc_toggle.text="Marching-cubes cloud geometry";column.add_child(mc_toggle)
	layer_toggle=CheckButton.new();layer_toggle.text="Legacy three-layer clouds";column.add_child(layer_toggle)
	for toggle in [billboard_toggle,mc_toggle,layer_toggle]: toggle.toggled.connect(func(_v): update_legacy())
	weather=OptionButton.new()
	for preset in Clouds.WEATHER_NAMES: weather.add_item("Cloud weather: "+preset)
	weather.select(weather_index);weather.disabled=true;column.add_child(weather)
	weather.item_selected.connect(set_weather)
	var line=HBoxContainer.new();column.add_child(line)
	var label=Label.new();label.text="Cloud brightness (0.5 = original dark layers)";line.add_child(label)
	var control=SpinBox.new();control.min_value=0.25;control.max_value=1.8;control.step=0.05;control.value=brightness;line.add_child(control)
	control.value_changed.connect(set_brightness)
	var altitude_line=HBoxContainer.new();column.add_child(altitude_line)
	var altitude_label=Label.new();altitude_label.text="Upper cloud altitude (m)";altitude_line.add_child(altitude_label)
	var altitude_control=SpinBox.new();altitude_control.min_value=3000;altitude_control.max_value=12000;altitude_control.step=500;altitude_control.value=upper_altitude;altitude_line.add_child(altitude_control)
	altitude_control.value_changed.connect(func(value): upper_altitude=value;if high_painterly: high_painterly.set_altitude(value))
	add_number(column,"Upper cloud coverage variation",0,1,0.05,coverage_variation,func(value): coverage_variation=value;apply_atmosphere())
	var haze_toggle=CheckButton.new();haze_toggle.text="Blue distance haze";haze_toggle.button_pressed=haze_enabled;column.add_child(haze_toggle)
	haze_toggle.toggled.connect(func(value): haze_enabled=value;apply_atmosphere())
	add_number(column,"Haze strength",0,1,0.05,haze_strength,func(value): haze_strength=value;apply_atmosphere())
	add_number(column,"Haze reach (km; larger = clearer further)",10,1500,10,haze_reach_km,func(value): haze_reach_km=value;apply_atmosphere())
	var note=Label.new();note.text="Ctrl+F12: next comparison preset. All layers can be combined.\nMarching cubes fills in gradually. Settings reset on restart.";column.add_child(note)
	apply_preset(9)
	apply_atmosphere()

func add_number(column: VBoxContainer,title: String,minimum: float,maximum: float,step: float,value: float,changed: Callable) -> void:
	var line=HBoxContainer.new();column.add_child(line)
	var label=Label.new();label.text=title;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(label)
	var control=SpinBox.new();control.min_value=minimum;control.max_value=maximum;control.step=step;control.value=value;line.add_child(control);control.value_changed.connect(changed)

func apply_atmosphere() -> void:
	for mat in [arena.backdrop._mat,arena.backdrop._wall_mat]:
		if not mat: continue
		mat.set_shader_parameter("haze_density",maxf(weather_haze_density,1.0/(haze_reach_km*1000.0)))
		mat.set_shader_parameter("haze_strength",haze_strength if haze_enabled else 0.0)
	if high_painterly: high_painterly.material_override.set_shader_parameter("coverage_variation",coverage_variation)

func update_legacy() -> void:
	if legacy==null:
		legacy=preload("res://world/sky_legacy_clouds.gd").new();add_child(legacy)
	legacy.configure(mc_toggle.button_pressed,billboard_toggle.button_pressed,layer_toggle.button_pressed)
	legacy.set_brightness(brightness)
	arena.frame_times.clear()

func apply_preset(index: int) -> void:
	preset_picker.select(index)
	set_painted(index in [5,9])
	mc_toggle.set_pressed_no_signal(index in [2,6,8])
	billboard_toggle.set_pressed_no_signal(index in [1,6,7,8,9])
	layer_toggle.set_pressed_no_signal(index==3)
	if legacy or index in [1,2,3,6,7,8,9]: update_legacy()
	set_weather(1 if index in [7,8] else 2)
	set_clouds(index in [4,7,8])

func set_painted(enabled: bool) -> void:
	painted=enabled
	if enabled and high_painterly==null:
		high_painterly=preload("res://world/sky_high_painterly.gd").new();high_painterly.altitude=upper_altitude;arena.add_child(high_painterly)
	if high_painterly: high_painterly.visible=enabled;high_painterly.set_brightness(brightness)
	arena.daylight.environment.sky=painted_sky if painted else original_sky
	sky_toggle.set_pressed_no_signal(painted)
	arena.frame_times.clear()

func set_clouds(enabled: bool) -> void:
	clouds_enabled=enabled
	# Allocate the historical deck only when requested; baseline has no cloud draws.
	if enabled and clouds==null:
		clouds=Clouds.new()
		clouds.ring_radius=arena.backdrop._radius()
		clouds.ring_width=arena.backdrop.WIDTHS[arena.backdrop.w_idx]
		clouds.wall_top=arena.backdrop.wall_top_h
		clouds._weather_idx=weather_index;clouds.auto_weather=false
		add_child(clouds)
		tune_ring_shapes()
	if clouds:
		clouds.visible=enabled;clouds.set_process(enabled)
		if enabled: update_clouds()
	cloud_toggle.set_pressed_no_signal(enabled);weather.disabled=not enabled
	arena.frame_times.clear()

func set_weather(index: int) -> void:
	weather_index=clampi(index,0,Clouds.WEATHER_NAMES.size()-1)
	weather.select(weather_index)
	if clouds:
		clouds._weather_idx=weather_index;clouds.retune();tune_ring_shapes();update_clouds()
	arena.frame_times.clear()

func update_clouds() -> void:
	clouds.update_around(Ring.absolute_point(arena.camera.global_position))
	for layer in clouds._layers:layer.position=-Ring.offset()
	clouds.bright_mult=brightness
	clouds.set_day(1.0,arena.daylight.sun.global_basis.z)

func set_brightness(value: float) -> void:
	brightness=value
	if legacy: legacy.set_brightness(value)
	if clouds: update_clouds()
	painted_material.set_shader_parameter("cloud_brightness",value)
	if high_painterly: high_painterly.set_brightness(value)

func tune_ring_shapes() -> void:
	# Squaring density then applying macro attenuation made fresh's threshold
	# unreachable across much of the low deck. Keep the threshold in raw-noise range.
	for i in clouds._layers.size():
		var mat=clouds._layers[i].material_override
		mat.set_shader_parameter("density_pow",1.0)
		mat.set_shader_parameter("macro_amount",0.20)
		if weather_index==2:
			mat.set_shader_parameter("coverage",[0.58,0.43,0.26,0.12,0.15][i])

func handle_input(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed): return false
	match event.keycode:
		KEY_F3:
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			dialog.popup_centered()
		KEY_F9: set_painted(not painted)
		KEY_F10: set_clouds(not clouds_enabled)
		KEY_F12: apply_preset((preset_picker.selected+1)%PRESETS.size())
		_: return false
	return true

func _process(delta: float) -> void:
	if not arena: return
	apply_atmosphere()
	if painted:
		painted_material.set_shader_parameter("local_up",Ring.up_at(arena.camera.global_position))
	if clouds_enabled: update_clouds()

func status() -> String:
	return "Ctrl+F3 sky controls | Ctrl+F12 next preset | %s | %s" % [PRESETS[preset_picker.selected],legacy.status() if legacy and legacy.visible else ""]
