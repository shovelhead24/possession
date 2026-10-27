extends Node
## Session-only weather data/UI. The caller owns all rendering and restoration.
## Visibility is approximate 5% transmission distance: density = -ln(.05) / metres.
signal weather_changed(profile: Dictionary)
const NAMES=["Original", "Clear", "Scattered", "Overcast", "Drizzle", "Steady rain", "Wind-driven rain", "Passing showers", "Mist", "Thick fog"]
# card fraction, upper opacity, upper fill, cloud brightness, sun, ambient,
# visibility metres (0 disables weather fog), rain, wind.
const VALUES=[
	[1.0,1.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0],
	[0.18,0.12,0.0,1.05,1.05,1.0,0.0,0.0,0.15],
	[0.55,0.45,0.0,1.0,0.95,1.0,12000.0,0.0,0.25],
	[1.0,1.0,0.68,0.78,0.28,0.90,5000.0,0.0,0.35],
	[0.95,1.0,0.55,0.77,0.35,0.92,2500.0,0.18,0.20],
	[1.0,1.0,0.78,0.66,0.20,0.82,1200.0,0.58,0.40],
	[1.0,1.0,0.88,0.55,0.13,0.76,800.0,0.88,0.95],
	[0.85,0.85,0.45,0.82,0.55,0.95,2200.0,0.35,0.55],
	[0.40,0.55,0.15,0.94,0.65,0.98,650.0,0.0,0.10],
	[0.25,0.65,0.38,0.88,0.25,0.93,120.0,0.0,0.08],
]
const CYCLE_ORDER=[2,3,4,7,1,2,8,2,5,6,3,1]
const CYCLE_SECONDS=180.0
const BLEND_SECONDS=45.0
var cycling=false
var cycle_elapsed=0.0
var cycle_index=0
var cycle_from: Dictionary={}
var cycle_control: CheckBox
var arena: Node3D
var selected := 0
var rain := 0.0
var wind := 0.0
var visibility_m := 0.0
var elapsed := 0.0
var clock := 0.0
var manual_rain := false
var manual_visibility := false
var picker: OptionButton
var rain_control: SpinBox
var wind_control: SpinBox
var visibility_control: SpinBox
var last_emitted: Dictionary={}

func setup(owner_arena: Node3D, column: VBoxContainer) -> void:
	arena=owner_arena
	cycle_control=CheckBox.new();cycle_control.text="Cycle weather automatically (3 minutes / 45-second blend)";column.add_child(cycle_control)
	cycle_control.toggled.connect(set_cycling)
	picker=OptionButton.new();column.add_child(picker)
	for label in NAMES:picker.add_item("Weather: "+label)
	picker.item_selected.connect(set_preset)
	var row=HBoxContainer.new();column.add_child(row)
	var label=Label.new();label.text="Rain";row.add_child(label)
	rain_control=SpinBox.new();rain_control.min_value=0;rain_control.max_value=100;rain_control.step=1;rain_control.suffix="%";row.add_child(rain_control)
	rain_control.tooltip_text="Changing rain holds the shower intensity until you reselect a weather preset."
	rain_control.value_changed.connect(func(value: float):set_rain(value/100.0))
	label=Label.new();label.text="    Wind";row.add_child(label)
	wind_control=SpinBox.new();wind_control.min_value=0;wind_control.max_value=100;wind_control.step=1;wind_control.suffix="%";row.add_child(wind_control)
	wind_control.value_changed.connect(func(value: float):set_wind(value/100.0))
	row=HBoxContainer.new();column.add_child(row)
	label=Label.new();label.text="Visibility (0 = no weather fog)";row.add_child(label)
	visibility_control=SpinBox.new();visibility_control.min_value=0;visibility_control.max_value=50000;visibility_control.step=50;visibility_control.suffix="m";row.add_child(visibility_control)
	visibility_control.value_changed.connect(set_visibility)
	set_preset(0)

func set_preset(index: int) -> void:
	set_cycling(false)
	selected=clampi(index,0,NAMES.size()-1)
	var values: Array=VALUES[selected]
	rain=values[7];wind=values[8];visibility_m=values[6]
	elapsed=0.0;clock=0.0;manual_rain=false;manual_visibility=false
	sync_controls();emit_profile(true)

func reset() -> void:
	set_preset(0)

func set_rain(value: float) -> void:
	set_cycling(false)
	rain=clampf(value,0.0,1.0);manual_rain=true
	sync_controls();emit_profile(true)

func set_wind(value: float) -> void:
	set_cycling(false)
	wind=clampf(value,0.0,1.0)
	sync_controls();emit_profile(true)

func set_visibility(value: float) -> void:
	set_cycling(false)
	visibility_m=0.0 if value<=0.0 else clampf(value,50.0,50000.0)
	manual_visibility=true;sync_controls();emit_profile(true)

func current_profile() -> Dictionary:
	var values: Array=VALUES[selected]
	var profile={"name":NAMES[selected],"cloud_fraction":values[0],"upper_opacity":values[1],"upper_fill":values[2],"cloud_darkness":values[3],"sun_gain":values[4],"ambient_gain":values[5],"fog_density":0.0,"rain":rain,"wind":wind}
	var visibility := visibility_m
	if selected==7 and not manual_rain:
		# Repeatable 80-second shower: quiet gap, gradual build, peak, then easing.
		var wave := (sin(elapsed*TAU/80.0-PI*.5)+1.0)*0.5
		var shower := smoothstep(0.18,0.80,wave)
		profile.rain=lerpf(0.02,0.80,shower)
		profile.cloud_fraction=lerpf(0.55,1.0,shower)
		profile.upper_opacity=lerpf(0.50,1.0,shower)
		profile.upper_fill=lerpf(0.10,0.72,shower)
		profile.cloud_darkness=lerpf(1.0,0.65,shower)
		profile.sun_gain=lerpf(0.90,0.22,shower)
		profile.ambient_gain=lerpf(1.0,0.84,shower)
		if not manual_visibility:visibility=lerpf(8000.0,1400.0,shower)
	profile.fog_density=2.995732/maxf(50.0,visibility) if visibility>0.0 else 0.0
	# Metadata makes the visibility control interpretable and lets the caller
	# distinguish untouched Original from custom rain/fog on that preset.
	profile.visibility_m=visibility
	profile.is_original=selected==0 and not manual_rain and not manual_visibility and is_zero_approx(wind)
	profile.mist_density=profile.fog_density if selected==8 else 0.0
	if selected==8:profile.fog_density=0.0
	if cycling and not cycle_from.is_empty():
		var blend=smoothstep(0.0,BLEND_SECONDS,cycle_elapsed)
		for key in ["cloud_fraction","upper_opacity","upper_fill","cloud_darkness","sun_gain","ambient_gain","fog_density","mist_density","rain","wind"]:
			profile[key]=lerpf(float(cycle_from.get(key,0.0)),float(profile[key]),blend)
		profile.is_original=false
	return profile

func emit_profile(force := false) -> void:
	var profile := current_profile()
	var changed := force or last_emitted.is_empty()
	if not changed:
		for key in ["rain","cloud_fraction","upper_opacity","upper_fill","cloud_darkness","sun_gain","ambient_gain","fog_density","mist_density","wind"]:
			if absf(float(profile[key])-float(last_emitted.get(key,0.0)))>=0.002:changed=true;break
	if changed:
		last_emitted=profile.duplicate(true)
		weather_changed.emit(profile)
	# Show the actual passing-shower values rather than stale preset numbers.
	if selected==7 and not manual_rain:
		if rain_control:rain_control.set_value_no_signal(float(profile.rain)*100.0)
		if visibility_control:visibility_control.set_value_no_signal(profile.visibility_m)

func sync_controls() -> void:
	if not picker:return
	picker.select(selected);rain_control.set_value_no_signal(rain*100.0)
	wind_control.set_value_no_signal(wind*100.0);visibility_control.set_value_no_signal(visibility_m)

func set_cycling(value: bool) -> void:
	cycling=value
	if cycle_control:cycle_control.set_pressed_no_signal(value)
	cycle_from={};cycle_elapsed=0.0
	if value:
		cycle_index=0
		select_cycle_target()

func select_cycle_target() -> void:
	selected=CYCLE_ORDER[cycle_index]
	var values: Array=VALUES[selected]
	rain=values[7];wind=values[8];visibility_m=values[6]
	elapsed=0.0;manual_rain=false;manual_visibility=false
	sync_controls();emit_profile(true)

func _process(delta: float) -> void:
	if arena and arena.loading and not arena.loading.dismissed:return
	if cycling:
		cycle_elapsed+=delta
		if cycle_elapsed>=CYCLE_SECONDS:
			cycle_from=current_profile().duplicate(true)
			cycle_elapsed=fmod(cycle_elapsed,CYCLE_SECONDS)
			cycle_index=(cycle_index+1)%CYCLE_ORDER.size()
			select_cycle_target()
	if not cycling and (selected!=7 or manual_rain):return
	elapsed+=delta;clock+=delta
	if clock<0.2:return
	clock=fmod(clock,0.2);emit_profile()
