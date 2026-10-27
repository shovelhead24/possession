extends SceneTree
class TestArena extends Node3D:
	var loading={"dismissed":true}
func _initialize():
	run.call_deferred()
func run():
	var arena=TestArena.new();root.add_child(arena)
	var column=VBoxContainer.new();root.add_child(column)
	var weather=preload("res://world/performance_weather.gd").new();root.add_child(weather)
	weather.setup(arena,column);weather.set_cycling(true)
	for step in weather.CYCLE_ORDER.size():
		var previous=weather.current_profile()
		weather._process(weather.CYCLE_SECONDS-weather.cycle_elapsed)
		var start=weather.current_profile()
		weather._process(weather.BLEND_SECONDS*.5)
		var middle=weather.current_profile()
		weather._process(weather.BLEND_SECONDS*.5)
		var end=weather.current_profile()
		for key in ["rain","wind","fog_density","mist_density","upper_fill"]:
			assert(is_finite(float(middle[key])) and float(middle[key])>=0)
			if weather.selected!=7:assert(is_equal_approx(float(middle[key]),lerpf(float(start[key]),float(end[key]),.5)))
		print("WEATHER_BLEND_PASS ",end.name)
	weather.set_preset(1);assert(not weather.cycling)
	weather.set_cycling(true);assert(weather.cycling)
	weather.set_rain(.4);assert(not weather.cycling)
	weather.reset();assert(weather.current_profile().is_original)
	weather.set_preset(8);assert(weather.current_profile().mist_density>0 and weather.current_profile().fog_density==0)
	print("WEATHER_CYCLE_PASS")
	quit()
