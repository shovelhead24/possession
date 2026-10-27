extends SceneTree
const Old=preload("res://benchmarks/performance_reference/tyre_dynamics.gd")
const Fast=preload("res://world/tyre_dynamics.gd")
func _initialize():
	var rng=RandomNumberGenerator.new();rng.seed=4817
	var cases=[]
	for i in 10000:
		var args=[rng.randf_range(-150,150),rng.randf_range(-70,70),rng.randf_range(-30,30),rng.randf_range(.1,1.2),rng.randf_range(0,30000),rng.randf_range(.1,3),rng.randf_range(-6000,6000),rng.randf_range(0,5000),1.0/60.0]
		var a=Old.step.callv(args);var b=Fast.step.callv(args)
		if a!=b: push_error("Tyre output changed");quit(1);return
		cases.append(args)
	var timings={}
	for name in ["old","fast","old_repeat","fast_repeat"]:
		var start=Time.get_ticks_usec()
		for args in cases:
			if name.begins_with("old"): Old.step.callv(args)
			else: Fast.step.callv(args)
		timings[name]=(Time.get_ticks_usec()-start)/1000.0
	print("PASS 10000 exact tyre comparisons ",JSON.stringify(timings));quit()

