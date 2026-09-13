extends CanvasLayer
var kit: Node
var panel: PanelContainer
var settings := {"camera_mode":0.0,"camera_distance":8.0,"camera_height":4.0,"camera_fov":75.0,"camera_smoothing":8.0}
var controls: Dictionary={}
var readout: Label
var opened := false
var loading := false
var car: RigidBody3D
const PATH="user://vehicle_tuning.cfg"

func _ready() -> void:
	kit=get_parent();car=kit.vehicles[0];layer=20
	panel=PanelContainer.new();panel.position=Vector2(24,24);panel.size=Vector2(540,620);add_child(panel)
	var background=StyleBoxFlat.new();background.bg_color=Color(.055,.065,.075,1)
	background.content_margin_left=16;background.content_margin_right=16;background.content_margin_top=12;background.content_margin_bottom=12
	panel.add_theme_stylebox_override("panel",background)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);panel.add_child(column)
	var title=Label.new();title.text="WARTHOG / VEHICLE SETUP";title.add_theme_font_size_override("font_size",24);column.add_child(title)
	var hint=Label.new();hint.text="F2 or Esc closes · Changes apply immediately\nVehicle brakes while this menu is open.";column.add_child(hint)
	var tabs=TabContainer.new();tabs.custom_minimum_size=Vector2(510,430);column.add_child(tabs)
	var suspension=page(tabs,"Suspension")
	slider(suspension,"spring_rate","Spring stiffness · N/m",10000,60000,1000,car.spring_rate)
	slider(suspension,"damping","Damping · Ns/m",500,6000,100,car.damping)
	slider(suspension,"travel_limit","Travel each way · m",.12,.28,.01,car.travel_limit)
	slider(suspension,"grip","Tyre grip",.4,2,.05,car.grip)
	var steering=page(tabs,"Steering")
	slider(steering,"steer_max","Low-speed steering · degrees",10,50,1,car.steer_max)
	slider(steering,"steer_fast","High-speed steering · degrees",5,25,1,car.steer_fast)
	slider(steering,"steer_rate","Steering response · rad/s",.3,4,.1,car.steer_rate)
	var engine=page(tabs,"Engine")
	slider(engine,"engine_force","Drive force per wheel · N",500,4000,100,car.engine_force)
	slider(engine,"top_speed","Speed limit · m/s",8,45,1,car.top_speed)
	slider(engine,"brake_strength","Brake strength",300,2000,50,car.brake_strength)
	var camera=page(tabs,"Camera")
	var mode=OptionButton.new();mode.add_item("Chase camera");mode.add_item("Driver seat");camera.add_child(mode);controls.camera_mode=mode
	mode.item_selected.connect(func(i): settings.camera_mode=float(i);kit.driver_look=Vector2.ZERO;save_settings())
	slider(camera,"camera_distance","Chase distance · m",3,14,.25,8)
	slider(camera,"camera_height","Chase height · m",1,7,.1,4)
	slider(camera,"camera_fov","Field of view · degrees",55,100,1,75)
	slider(camera,"camera_smoothing","Chase response",1,20,.5,8)
	var note=Label.new();note.text="Driver view: mouse looks around; Home centres view.\nChase camera pulls forward when scenery blocks it.";camera.add_child(note)
	readout=Label.new();column.add_child(readout)
	var buttons=HBoxContainer.new();column.add_child(buttons)
	var reset=Button.new();reset.text="Reset defaults";buttons.add_child(reset);reset.pressed.connect(reset_defaults)
	var close=Button.new();close.text="Return to game";buttons.add_child(close);close.pressed.connect(func(): set_open(false))
	load_settings();panel.hide()

func page(tabs: TabContainer,label: String) -> VBoxContainer:
	var box=VBoxContainer.new();box.name=label;box.add_theme_constant_override("separation",12);tabs.add_child(box);return box

func slider(box: VBoxContainer,key: String,label: String,low: float,high: float,step: float,value: float) -> void:
	var text=Label.new();box.add_child(text)
	var slide=HSlider.new();slide.min_value=low;slide.max_value=high;slide.step=step;slide.value=value;slide.custom_minimum_size=Vector2(480,24);box.add_child(slide)
	controls[key]=slide;slide.set_meta("default",value)
	text.text=label+"  "+str(snappedf(value,.01))
	slide.value_changed.connect(func(v):
		text.text=label+"  "+str(snappedf(v,.01))
		if key.begins_with("camera_"): settings[key]=v
		else: car.set(key,v)
		save_settings())

func set_open(value: bool) -> void:
	opened=value;panel.visible=value
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func save_settings() -> void:
	if loading: return
	var config=ConfigFile.new()
	for key in controls:
		config.set_value("vehicle",key,settings[key] if key.begins_with("camera_") else car.get(key))
	config.save(PATH)

func load_settings() -> void:
	var config=ConfigFile.new()
	if config.load(PATH)!=OK: return
	loading=true
	for key in controls:
		var v=config.get_value("vehicle",key,null)
		if v==null or not (v is float or v is int): continue
		if key=="camera_mode":
			settings[key]=clampf(float(v),0,1);controls[key].select(int(settings[key]))
		else:
			controls[key].value=clampf(float(v),controls[key].min_value,controls[key].max_value)
			if key.begins_with("camera_"): settings[key]=controls[key].value
			else: car.set(key,controls[key].value)
	loading=false

func reset_defaults() -> void:
	for key in controls:
		if key=="camera_mode": settings[key]=0.0;controls[key].select(0)
		else: controls[key].value=controls[key].get_meta("default")
	save_settings()

func _process(_delta: float) -> void:
	if opened: readout.text="%.0f km/h · %d wheels grounded · %.2f m compression" % [car.linear_velocity.length()*3.6,car.grounded_count,car.max_compression]
