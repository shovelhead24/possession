extends RefCounted
# Front-view four-bar linkage in metres. Both A-arm legs share a hinge axis along Z.
const LOWER := 0.75
const UPPER := 0.65
const UPRIGHT := 0.48
const UPPER_IN := Vector2(0.10,0.48)
const MIN_TRAVEL := -0.28
const MAX_TRAVEL := 0.28

static func solve(travel: float) -> Dictionary:
	var y := clampf(travel,MIN_TRAVEL,MAX_TRAVEL)
	var lower := Vector2(sqrt(LOWER*LOWER-y*y),y)
	var delta := lower-UPPER_IN
	var d := delta.length()
	var axis := delta/d
	var along := (UPPER*UPPER-UPRIGHT*UPRIGHT+d*d)/(2*d)
	var height := sqrt(maxf(0,UPPER*UPPER-along*along))
	var mid := UPPER_IN+axis*along
	var normal := Vector2(-axis.y,axis.x)
	var a := mid+normal*height
	var b := mid-normal*height
	var upper := a if a.y>b.y else b
	return {"lower":lower,"upper":upper,"hub":(lower+upper)*.5,"camber":atan2(upper.x-lower.x,upper.y-lower.y)}

static func at_height(height: float) -> Dictionary:
	var lo := MIN_TRAVEL
	var hi := MAX_TRAVEL
	for i in range(18):
		var mid := (lo+hi)*.5
		if solve(mid).hub.y < height: lo=mid
		else: hi=mid
	return solve((lo+hi)*.5)
