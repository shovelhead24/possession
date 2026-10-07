extends Node
## Tiny vehicle fittings retain their visible mesh but stop issuing separate
## shadow draws when their entire bound occupies only a few screen pixels.
var camera: Camera3D
var casters: Array=[]
var clock := 0.0

func setup(vehicle: Node3D, view: Camera3D) -> void:
	camera=view
	for node in vehicle.find_children("*","MeshInstance3D",true,false):
		if node.mesh and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			var bounds: AABB=node.mesh.get_aabb()
			casters.append({"node":node,"centre":bounds.get_center(),"radius":bounds.size.length()*.5})
	update_shadows()

func _process(delta: float) -> void:
	clock-=delta
	if clock<=0: update_shadows();clock=.25

func update_shadows() -> void:
	if not is_instance_valid(camera): return
	var focal := camera.get_viewport().get_visible_rect().size.y/(2.0*tan(deg_to_rad(camera.fov)*.5))
	for item in casters:
		var node: MeshInstance3D=item.node
		if not is_instance_valid(node): continue
		var centre: Vector3=node.global_transform*item.centre
		var scale := node.global_basis.get_scale().abs()
		var radius: float=item.radius*maxf(scale.x,maxf(scale.y,scale.z))
		var pixels := 2.0*radius*focal/maxf(.01,camera.global_position.distance_to(centre)-radius)
		# Hysteresis avoids toggling shadows as the camera crosses a threshold.
		if pixels<3.0: node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif pixels>4.0: node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
