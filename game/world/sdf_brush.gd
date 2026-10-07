extends RefCounted
const Recipe=preload("res://world/sdf_recipe.gd")
var draft: Array=[]
var samples := {}
var previous := Vector3.ZERO
var has_previous := false
var template: Dictionary
var flatten_height := 0.0

func begin(source: Array, settings: Dictionary) -> void:
	draft=source.duplicate(true);template=settings.duplicate(true);samples.clear();has_previous=false

func dab(point: Vector3, amount: float) -> void:
	if not has_previous: flatten_height=point.y
	var spacing := maxf(2,template.radius*.25)
	if template.kind=="trees": spacing=maxf(3,template.radius)
	var steps := maxi(1,ceili(previous.distance_to(point)/spacing)) if has_previous else 1
	# Interpolate fast cursor motion, distributing time rather than multiplying it.
	for i in range(1,mini(steps,128)+1):
		var p := previous.lerp(point,float(i)/mini(steps,128)) if has_previous else point
		var key := Vector2i(roundi(p.x/spacing),roundi(p.z/spacing))
		if not samples.has(key):
			if draft.size()>=2048: break
			var f := template.duplicate(true);f.x=p.x;f.z=p.z;f.y=p.y
			if f.kind=="flatten": f.y=flatten_height
			if f.kind=="bridge": f.y+=template.height
			f.amount=0.0
			samples[key]=draft.size();draft.append(f)
		var f: Dictionary=draft[samples[key]]
		if template.kind=="trees": continue
		f.amount=minf(100000,f.amount+amount/mini(steps,128))
	previous=point;has_previous=true
