extends "res://world/rebuild_tank.gd"
func setup_tank(model: Node3D, owner_kit: Node) -> void:
	kit=owner_kit
	# Pivots are expressed in the normalized source pose, with forward along -Z.
	turret=Node3D.new();turret.name="TurretYaw";add_child(turret);turret.position=Vector3(0,1.09,.89)
	barrel=Node3D.new();barrel.name="BarrelPitch";turret.add_child(barrel);barrel.position=Vector3(0,.42,-1.09)
	muzzle=Node3D.new();muzzle.name="Muzzle";barrel.add_child(muzzle)
	tracks=preload("res://world/performance_tank_wheels.gd").new();add_child(tracks)
	var meshes=model.find_children("*","MeshInstance3D",true,false)
	var barrel_bounds=AABB();var first=true
	for node in meshes:
		var label=String(node.name)
		if label.begins_with("Barrel"):
			node.reparent(barrel,true)
			var bounds=global_transform.affine_inverse()*node.global_transform*node.mesh.get_aabb()
			barrel_bounds=bounds if first else barrel_bounds.merge(bounds);first=false
		elif label.begins_with("Turret"):
			node.reparent(turret,true)
		elif label.begins_with("Wheel"):
			var bounds=global_transform.affine_inverse()*node.global_transform*node.mesh.get_aabb()
			var pivot=Node3D.new();tracks.add_child(pivot);pivot.position=bounds.get_center();node.reparent(pivot,true)
			tracks.wheels.append({"pivot":pivot,"side":signf(pivot.position.x),"radius":maxf(.1,bounds.size.y*.5)})
	assert(not first,"Articulated tank has no barrel")
	muzzle.position=barrel.to_local(to_global(Vector3(barrel_bounds.get_center().x,barrel_bounds.get_center().y,barrel_bounds.position.z)))
	cannon_audio=AudioStreamPlayer3D.new();cannon_audio.stream=preload("res://world/mechanical_audio.gd").make_sound(true);cannon_audio.volume_db=-12;cannon_audio.unit_size=12;add_child(cannon_audio)
	build_contacts()

