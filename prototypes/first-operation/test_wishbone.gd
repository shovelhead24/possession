extends SceneTree
const Linkage=preload("res://wishbone.gd")
func _initialize() -> void:
	var last := -100.0
	for i in range(101):
		var travel=lerpf(Linkage.MIN_TRAVEL,Linkage.MAX_TRAVEL,i/100.0)
		var s=Linkage.solve(travel)
		assert(absf(s.lower.length()-Linkage.LOWER)<.00001)
		assert(absf(s.upper.distance_to(Linkage.UPPER_IN)-Linkage.UPPER)<.00001)
		assert(absf(s.lower.distance_to(s.upper)-Linkage.UPRIGHT)<.00001)
		assert(s.hub.y>last);last=s.hub.y
		assert(Linkage.at_height(s.hub.y).hub.distance_to(s.hub)<.0001)
	print("PASS: 101 travel samples preserve both arms and upright; continuous hub travel and inverse solve")
	quit()
