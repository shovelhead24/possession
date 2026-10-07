extends CanvasLayer
var kit: Node
var opened := false
var panel: PanelContainer
var controls := {}
var player_speed := 45.0
var enemy_speed := 22.0
var config_path := "user://plasma_tuning.cfg"
func _ready() -> void:
	kit=get_parent();layer=25
	var cfg=ConfigFile.new()
	if cfg.load(config_path)==OK:
		player_speed=clampf(float(cfg.get_value("plasma","player_speed",45)),5,150)
		enemy_speed=clampf(float(cfg.get_value("plasma","enemy_speed",22)),5,150)
	panel=PanelContainer.new();panel.position=Vector2(28,28);add_child(panel)
	var style=StyleBoxFlat.new();style.bg_color=Color(.04,.055,.075,1);style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=20;style.content_margin_bottom=20;panel.add_theme_stylebox_override("panel",style)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",18);panel.add_child(column)
	var title=Label.new();title.text="PLASMA / COMBAT SETUP";column.add_child(title)
	for key in ["player_speed","enemy_speed"]:
		var label=Label.new();column.add_child(label)
		var slider=HSlider.new();slider.min_value=5;slider.max_value=150;slider.step=1;slider.value=get(key);slider.custom_minimum_size=Vector2(480,32);column.add_child(slider);controls[key]=slider
		var caption="Your projectile speed" if key=="player_speed" else "Enemy projectile speed"
		label.text=caption+" / %.0f m/s" % slider.value
		slider.value_changed.connect(func(v):
			set(key,v);label.text=caption+" / %.0f m/s" % v;save_settings())
	var note=Label.new();note.text="Applies to new shots. Slower enemy bolts are easier to dodge.\nF3 / Esc closes · F2 opens vehicle setup";column.add_child(note)
	var close=Button.new();close.text="Return to game";column.add_child(close);close.pressed.connect(func(): set_open(false))
	panel.hide()
func save_settings() -> void:
	var cfg=ConfigFile.new();cfg.set_value("plasma","player_speed",player_speed);cfg.set_value("plasma","enemy_speed",enemy_speed);cfg.save(config_path)
func set_open(value: bool) -> void:
	opened=value;panel.visible=value;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
