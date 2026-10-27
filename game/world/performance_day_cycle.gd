extends Node
## Session-only art preview. Does not write player, weather or gameplay saves.
## Connect lighting_changed to the review's sky/cloud tint uniforms before setup.
const Ring=preload("res://world/terrain_drive_ring.gd")
const Frame=preload("res://world/ring_frame.gd")
const SUN_TILT=PI/12.0
signal lighting_changed(sky_tint: Color, cloud_tint: Color)
var arena: Node3D
var enabled := false
var animate := false
var hour := 12.0
var hours_per_second := 0.02
var clock := 0.0
var baseline_state: Dictionary = {}
var enabled_control: CheckBox
var animate_control: CheckBox
var hour_control: HSlider
var rate_control: SpinBox
var readout: Label
var sky_tint := Color.WHITE
var cloud_tint := Color.WHITE

func setup(owner_arena: Node3D, column: VBoxContainer) -> void:
	arena=owner_arena
	process_priority=103
	enabled_control=CheckBox.new();enabled_control.text="Enable day / night cycle";column.add_child(enabled_control)
	enabled_control.toggled.connect(set_enabled)
	var row := HBoxContainer.new();column.add_child(row)
	readout=Label.new();readout.custom_minimum_size.x=115;row.add_child(readout)
	hour_control=HSlider.new();hour_control.min_value=0;hour_control.max_value=24;hour_control.step=0.05
	hour_control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;hour_control.custom_minimum_size.x=180
	row.add_child(hour_control);hour_control.value_changed.connect(set_hour)
	animate_control=CheckBox.new();animate_control.text="Animate day";column.add_child(animate_control)
	animate_control.toggled.connect(func(value: bool):
		animate=value
		if value: set_enabled(true)
	)
	row=HBoxContainer.new();column.add_child(row)
	var label := Label.new();label.text="Game hours per second";row.add_child(label)
	rate_control=SpinBox.new();rate_control.min_value=0.01;rate_control.max_value=2;rate_control.step=0.01
	row.add_child(rate_control);rate_control.value_changed.connect(func(value: float): hours_per_second=value)
	var button := Button.new();button.text="Restore lighting before preview";column.add_child(button);button.pressed.connect(reset)
	var note := Label.new();note.text="Home sector: sunrise 06:00 · sunset 18:00.\nDefault: 20-minute day. Scrub to hold a time.";column.add_child(note)
	sync_controls()

func snapshot_lighting() -> Dictionary:
	var d=arena.daylight
	var result := {"elevation":d.elevation,"azimuth":d.azimuth,"energy":d.energy,"ambient":d.ambient,"baseline":d.baseline,
		"rotation":d.sun.rotation,"sun_color":d.sun.light_color,"sun_energy":d.sun.light_energy,
		"ambient_color":d.environment.ambient_light_color,"ambient_energy":d.environment.ambient_light_energy}
	if arena.backdrop and arena.backdrop._mat:
		result["backdrop_horizon"]=arena.backdrop.horizon_color
		result["backdrop_sun"]=arena.backdrop._mat.get_shader_parameter("daylight_sun")
		result["backdrop_ambient"]=arena.backdrop._mat.get_shader_parameter("daylight_ambient")
	result["backdrop_materials"]={}
	for key in backdrop_materials():
		var material: ShaderMaterial=arena.backdrop.get(key)
		result.backdrop_materials[key]={"sky_color":material.get_shader_parameter("sky_color"),"to_sun":material.get_shader_parameter("to_sun")}
	# Weather is independently reversible; do not snapshot its temporary tint.
	var review=arena.get("cloud_review")
	if review and not review.weather_restore.is_empty():
		var original: Dictionary=review.weather_restore
		result.sun_energy=original.sun_energy
		result.ambient_energy=original.ambient_energy
		result.backdrop_horizon=original.horizon
		result.backdrop_sun=original.sun
		result.backdrop_ambient=original.ambient
		for key in result.backdrop_materials:result.backdrop_materials[key].sky_color=original.horizon
	return result

func backdrop_materials() -> Array[String]:
	var result: Array[String]=[]
	if not arena or not arena.backdrop: return result
	for key in ["_mat","_wall_mat","_field_mat"]:
		if arena.backdrop.get(key) is ShaderMaterial: result.append(key)
	return result

func set_enabled(value: bool) -> void:
	if enabled==value: return
	if value:
		baseline_state=snapshot_lighting();enabled=true;clock=0
		arena.daylight.baseline=false
		arena.daylight.apply()
		apply_time()
	else:
		enabled=false;animate=false
		restore_lighting()
	sync_controls()

func set_hour(value: float) -> void:
	hour=fposmod(value,24.0);animate=false
	if not enabled: set_enabled(true)
	else: apply_time()
	sync_controls()

func reset() -> void:
	set_enabled(false)
	hour=12;clock=0;sync_controls()

func restore_lighting() -> void:
	if baseline_state.is_empty(): return
	var d=arena.daylight
	for key in ["elevation","azimuth","energy","ambient","baseline"]: d.set(key,baseline_state[key])
	d.apply()
	d.sun.rotation=baseline_state.rotation;d.sun.light_color=baseline_state.sun_color;d.sun.light_energy=baseline_state.sun_energy
	d.environment.ambient_light_color=baseline_state.ambient_color;d.environment.ambient_light_energy=baseline_state.ambient_energy
	if arena.backdrop and arena.backdrop._mat:
		if baseline_state.has("backdrop_horizon"):arena.backdrop.horizon_color=baseline_state.backdrop_horizon
		for key in ["sun","ambient"]:
			if baseline_state.has("backdrop_"+key): arena.backdrop._mat.set_shader_parameter("daylight_"+key,baseline_state["backdrop_"+key])
	for key in backdrop_materials():
		var saved: Dictionary=baseline_state.get("backdrop_materials",{}).get(key,{})
		var material: ShaderMaterial=arena.backdrop.get(key)
		for parameter in saved: material.set_shader_parameter(parameter,saved[parameter])
	sky_tint=Color.WHITE;cloud_tint=Color.WHITE;lighting_changed.emit(sky_tint,cloud_tint)

func apply_sun_direction() -> void:
	var d=arena.daylight
	var direction=Frame.sun_direction((hour-12.0)*TAU/24.0,SUN_TILT)
	d.sun.global_basis=Basis.looking_at(-direction,Vector3.UP)
	d.elevation=-d.sun.rotation_degrees.x;d.azimuth=d.sun.rotation_degrees.y
	for key in backdrop_materials():
		var material: ShaderMaterial=arena.backdrop.get(key)
		if material.get_shader_parameter("to_sun")!=null: material.set_shader_parameter("to_sun",d.sun.global_basis.z)

func apply_time() -> void:
	if not enabled: return
	var d=arena.daylight
	apply_sun_direction()
	var height: float=Ring.up_at(arena.camera.global_position).dot(d.sun.global_basis.z)
	var daylight := smoothstep(-0.12,0.30,height)
	var direct := smoothstep(-0.025,0.20,height)
	var warm := (1.0-smoothstep(0.02,0.42,absf(height)))*smoothstep(-0.18,0.0,height)
	d.baseline=false;apply_sun_direction()
	d.energy=lerpf(0.0,1.0,direct);d.ambient=lerpf(0.09,0.48,daylight)
	d.sun.light_color=Color(1.0,0.96,0.90).lerp(Color(1.0,0.39,0.15),warm)
	d.sun.light_energy=d.energy
	d.environment.ambient_light_color=Color(0.30,0.40,0.65).lerp(Color(0.78,0.85,0.94),daylight)
	d.environment.ambient_light_energy=d.ambient
	sky_tint=Color(0.07,0.10,0.22).lerp(Color.WHITE,daylight).lerp(Color(1.0,0.58,0.40),warm*0.55)
	cloud_tint=Color(0.12,0.16,0.27).lerp(Color.WHITE,daylight).lerp(Color(1.0,0.53,0.30),warm*0.65)
	# Match the cycle sky's base horizon, including its sunset/night tint.
	var horizon := Vector3(0.62*sky_tint.r,0.74*sky_tint.g,0.86*sky_tint.b)
	if arena.backdrop:arena.backdrop.horizon_color=horizon
	for key in backdrop_materials():
		var material: ShaderMaterial=arena.backdrop.get(key)
		if material.get_shader_parameter("sky_color")!=null: material.set_shader_parameter("sky_color",horizon)
	if arena.backdrop and arena.backdrop._mat:
		var color: Color=d.sun.light_color
		arena.backdrop._mat.set_shader_parameter("daylight_sun",Vector3(color.r,color.g,color.b)*d.energy/maxf(0.001,d.original_energy))
		color=d.environment.ambient_light_color
		arena.backdrop._mat.set_shader_parameter("daylight_ambient",Vector3(color.r,color.g,color.b)*d.ambient/maxf(0.001,d.original_ambient_energy))
	lighting_changed.emit(sky_tint,cloud_tint)

func _process(delta: float) -> void:
	if not enabled: return
	if animate:
		hour=fposmod(hour+delta*hours_per_second,24.0)
		# Smooth moving shadows; colors and UI remain at 10 Hz.
		apply_sun_direction()
	clock+=delta
	if clock<0.1: return
	clock=fmod(clock,0.1)
	# Reassert preview after edits in the existing daylight dialog.
	apply_time();sync_controls()

func sync_controls() -> void:
	if not enabled_control: return
	enabled_control.set_pressed_no_signal(enabled);animate_control.set_pressed_no_signal(animate)
	hour_control.set_value_no_signal(hour);rate_control.set_value_no_signal(hours_per_second)
	var minutes := int(hour*60.0)%1440
	readout.text="%02d:%02d" % [minutes/60,minutes%60]

func capture_state() -> Dictionary:
	return {"enabled":enabled,"animate":animate,"hour":hour,"hours_per_second":hours_per_second,"clock":clock,
		"baseline_state":baseline_state.duplicate(true),"lighting":snapshot_lighting(),"sky_tint":sky_tint,"cloud_tint":cloud_tint}

func restore_state(state: Dictionary) -> void:
	# For benchmark capture: capture, set animate=false, sample, then restore.
	if enabled: set_enabled(false)
	hour=state.hour;hours_per_second=state.hours_per_second;clock=state.clock
	baseline_state=state.baseline_state.duplicate(true)
	enabled=state.enabled;animate=state.animate
	if enabled: apply_time()
	else:
		var saved := baseline_state
		baseline_state=state.lighting;restore_lighting();baseline_state=saved
		sky_tint=state.sky_tint;cloud_tint=state.cloud_tint;lighting_changed.emit(sky_tint,cloud_tint)
	sync_controls()
