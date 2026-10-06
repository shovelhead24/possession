extends SceneTree
const Linkage=preload("res://world/wishbone.gd")

func original(height: float) -> Dictionary:
	var lo := Linkage.MIN_TRAVEL;var hi := Linkage.MAX_TRAVEL
	for i in 18:
		var mid := (lo+hi)*.5
		if Linkage.solve(mid).hub.y<height: lo=mid
		else: hi=mid
	return Linkage.solve((lo+hi)*.5)

func _initialize() -> void:
	var started := Time.get_ticks_usec();Linkage.prepare_height_search()
	var prepare_ms := (Time.get_ticks_usec()-started)/1000.0
	var samples := [];var reference := [];var greatest := 0.0
	var low: float=Linkage.solve(-.28).hub.y;var high: float=Linkage.solve(.28).hub.y
	for i in 2001: samples.append(lerpf(low-.1,high+.1,float(i)/2000))
	started=Time.get_ticks_usec()
	for value in samples: reference.append(original(value))
	var old_ms := (Time.get_ticks_usec()-started)/1000.0
	started=Time.get_ticks_usec()
	for i in samples.size():
		var result := Linkage.at_height(samples[i])
		for key in ["lower","upper","hub"]: greatest=maxf(greatest,result[key].distance_to(reference[i][key]))
		assert(absf(result.camber-reference[i].camber)<.00001)
	assert(greatest<.000003,"Cached suspension search changed geometry")
	var new_ms := (Time.get_ticks_usec()-started)/1000.0
	Linkage.height_search=PackedFloat32Array();Linkage.prepare_height_search()
	assert(Linkage.height_search.size()==262143,"Search cache failed to reload")
	print("SUSPENSION_CACHE_PASS prepare_ms=",prepare_ms," original_ms=",old_ms," cached_ms=",new_ms," max_position_error_m=",greatest)
	quit()
