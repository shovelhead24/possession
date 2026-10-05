extends RefCounted
const Recipe=preload("res://world/sdf_recipe.gd")

static func features() -> Array:
	var result: Array=[]
	for station in 12:
		var tier := 1+station/4
		var z := -120.0-station*44.0
		for side in [-1.0,1.0]:
			for lane in int(tier)*2:
				var x: float=-14.0+side*(44.0+lane*10.0)
				var ridge := Recipe.feature("ridge",Vector3(x,2,z))
				ridge.merge({"radius":8.0,"length":48.0,"yaw":90.0,"bend":side*(8.0+lane*2.0)},true)
				result.append(ridge)
				var tunnel := ridge.duplicate(true)
				tunnel.kind="tunnel";tunnel.y=3.0;tunnel.radius=3.5
				result.append(tunnel)
			var ravine := Recipe.feature("lower",Vector3(-14+side*27,0,z))
			ravine.radius=10.0;ravine.height=10.0;ravine.shape="ellipse";ravine.aspect=2.0
			result.append(ravine)
		var bridge := Recipe.feature("bridge",Vector3(-14,13,z))
		bridge.length=140.0;bridge.width=9.0;bridge.thickness=3.0;bridge.height=16.0
		result.append(bridge)
	return result

static func signs(parent: Node3D) -> void:
	for tier in 3:
		var label := Label3D.new()
		label.text="SDF STRESS / TIER %d\nDrive -Z beneath the bridges\nF8 begin / end capture" % (tier+1)
		label.position=Vector3(-14,19,-105-tier*176)
		label.font_size=80;label.pixel_size=.025
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		parent.add_child(label)
