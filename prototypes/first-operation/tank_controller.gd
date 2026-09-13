extends CharacterBody3D
var max_speed := 16.0
var reverse_speed := 7.0
var acceleration := 5.0
var brake_strength := 35.0
var turn_rate := 1.0
var turret_rate := 45.0
var reload_time := 2.5
var cannon_damage := 100.0
var turret: Node3D
var barrel: Node3D
var muzzle: Node3D
var kit: Node
var cooldown := 0.0
var cannon_audio: AudioStreamPlayer3D

func setup(model: Node3D, owner_kit: Node) -> void:
	kit=owner_kit
	turret=Node3D.new();turret.name="TurretYaw";add_child(turret);turret.position=Vector3(0,1.5,1.1)
	barrel=Node3D.new();turret.add_child(barrel);barrel.position=Vector3(0,.247,-2)
	muzzle=Node3D.new();barrel.add_child(muzzle);muzzle.position=Vector3(0,0,-3.6)
	var meshes=[];var stack=[model]
	while not stack.is_empty():
		var node=stack.pop_back()
		if node is MeshInstance3D: meshes.append(node)
		for child in node.get_children(): stack.append(child)
	var count=0
	for node in meshes:
		var box: AABB=global_transform.affine_inverse()*node.global_transform*node.mesh.get_aabb()
		var label=String(node.name)
		if label.begins_with("gun_1_") or label.begins_with("gun_2_") or label.begins_with("gun_support_"):
			node.reparent(barrel,true);count+=1
		elif box.get_center().y>1.65 and box.get_center().z<3.4 and absf(box.get_center().x)<1.5:
			node.reparent(turret,true);count+=1
	cannon_audio=AudioStreamPlayer3D.new();cannon_audio.stream=preload("res://mechanical_audio.gd").make_sound(true);cannon_audio.volume_db=-12;cannon_audio.unit_size=12;add_child(cannon_audio)
	print("TANK_RIG_READY: ",count," turret/barrel meshes")

func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	if not kit or kit.driving!=self or kit.menu.opened: return
	turret.rotation.y=rotate_toward(turret.rotation.y,kit.driver_look.x,deg_to_rad(turret_rate)*delta)
	barrel.rotation.x=move_toward(barrel.rotation.x,clampf(kit.driver_look.y,deg_to_rad(-8),deg_to_rad(22)),deg_to_rad(turret_rate*.6)*delta)

func fire_cannon() -> bool:
	if cooldown>0 or kit.menu.opened: return false
	cooldown=reload_time;cannon_audio.play()
	# Start at the breech so a barrel poking through a wall cannot shoot through it.
	var start=barrel.global_position
	var end=muzzle.global_position-muzzle.global_basis.z*450
	var ray=PhysicsRayQueryParameters3D.create(start,end);ray.exclude=[get_rid(),kit.arena.walker.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	var point: Vector3=hit.position if not hit.is_empty() else end
	kit.arena.get_node("PracticeRange").tracer(start,point)
	if not hit.is_empty():
		if hit.collider.has_method("take_hit"): hit.collider.take_hit(cannon_damage,start,point)
		elif hit.collider.has_meta("target_hits"): hit.collider.set_meta("target_hits",int(hit.collider.get_meta("target_hits"))+1)
		var blast=kit.arena.box(point,Vector3.ONE*.7,kit.arena.material(Color(1,.5,.1),0,.5,true))
		var tween=create_tween();tween.tween_property(blast,"scale",Vector3.ONE*2,.12);tween.tween_property(blast,"scale",Vector3.ONE*.01,.22);tween.tween_callback(blast.queue_free)
	kit.status.text="ALTAY / CANNON FIRED / %.1f s reload" % reload_time
	return true
