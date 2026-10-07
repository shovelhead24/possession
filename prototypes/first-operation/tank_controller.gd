extends "res://wishbone_vehicle.gd"
# Same suspension, tyre forces, braking/reverse and steering as the Warthog.
# Four invisible contacts per side; original tracks and turret remain visible.
var kit: Node
var turret: Node3D
var barrel: Node3D
var muzzle: Node3D
var tracks: Node3D
var cannon_audio: AudioStreamPlayer3D
var turret_rate := 45.0
var reload_time := 2.5
var cannon_damage := 100.0
var cooldown := 0.0
var track_speeds := Vector2.ZERO

func _ready() -> void:
	super._ready()
	mass=1600.0
	center_of_mass=Vector3(0,.48,.64)
	top_speed=11.0
	engine_force=1800.0
	steer_max=28.0
	steer_fast=12.0

func build_contacts() -> void:
	suspension_exclusions.append(kit.arena.walker.get_rid())
	# Locations span the existing belt's road-wheel run.
	for side in [-1.0,1.0]:
		for z in [-1.65,-.10,1.45,2.95]:
			var center=Vector3(side*tracks.half_width,.40,z)
			var hub=Node3D.new();add_child(hub);hub.position=center
			var spin=Node3D.new();hub.add_child(spin)
			corners.append({"anchor":center-Vector3(side*rest_hub.x,rest_hub.y,0),
				"side":side,"radius":.40,"hub":hub,"spin":spin,"links":[],
				"front":z<.65,"travel":0.0,"compression":0.0})
	print("TANK_SUSPENSION_READY: eight invisible Warthog wheel contacts")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	track_speeds=Vector2.ZERO
	for corner in corners:
		var side=0 if corner.side<0 else 1
		track_speeds[side]+=corner.get("omega",0.0)*corner.radius/4.0
	if tracks: tracks.animate(delta,track_speeds.x,track_speeds.y)

func toggle_inspection() -> void:
	# No visible suspension wheels: preserve the tank silhouette.
	pass

func setup_tank(model: Node3D, owner_kit: Node) -> void:
	kit=owner_kit
	preload("res://tank_finish.gd").apply(model)
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
	tracks=preload("res://tank_tracks.gd").new();add_child(tracks);tracks.setup(model,self);build_contacts()

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
		var impact=AudioStreamPlayer3D.new();impact.stream=cannon_audio.stream;impact.pitch_scale=.7;impact.volume_db=-8;impact.unit_size=20;impact.max_distance=300;kit.arena.add_child(impact);impact.global_position=point;impact.finished.connect(impact.queue_free);impact.play()
		if hit.collider.has_method("take_hit"): hit.collider.take_hit(cannon_damage,start,point)
		elif hit.collider.has_meta("target_hits"): hit.collider.set_meta("target_hits",int(hit.collider.get_meta("target_hits"))+1)
		var blast=kit.arena.box(point,Vector3.ONE*.7,kit.arena.material(Color(1,.5,.1),0,.5,true))
		var tween=create_tween();tween.tween_property(blast,"scale",Vector3.ONE*2,.12);tween.tween_property(blast,"scale",Vector3.ONE*.01,.22);tween.tween_callback(blast.queue_free)
	kit.status.text="ALTAY / CANNON FIRED / %.1f s reload" % reload_time
	return true
