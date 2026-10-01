extends Node3D
# Cone values are half angles: maximum deviation from the aim direction.
const MIN_SPREAD := .2
const MAX_SPREAD := 2.0
const COLD_DELAY := 1.0
const RAMP_TIME := 1.5
const MIN_RATE := 5.0
const MAX_RATE := 15.0
var kit: Node
var body: Node3D
var yaw: Node3D
var pitch: Node3D
var muzzle: Node3D
var audio: AudioStreamPlayer3D
var motor: AudioStreamPlayer3D
var spin := 0.0
var bloom := 0.0
var shot_wait := 0.0
var shots := 0
var rng := RandomNumberGenerator.new()
var flash: MeshInstance3D
var flash_time := 0.0
var gunner: Node3D
var pose_player: AnimationPlayer
var crouch_clip: StringName
var crouch := .5
var rotor: Node3D
var samples: Node3D

func setup(owner_kit: Node, vehicle: Node3D, model: Node3D) -> void:
	kit=owner_kit;body=vehicle;rng.randomize()
	var gun=model.find_child("Gun",true,false) as Node3D
	if not gun: push_error("Warthog turret mesh missing");return
	var box: AABB=body.global_transform.affine_inverse()*gun.get_parent().global_transform*kit.bounds(gun)
	yaw=Node3D.new();add_child(yaw);yaw.position=Vector3(.04,box.position.y,1.19)
	pitch=Node3D.new();yaw.add_child(pitch);pitch.position=Vector3(0,1.75-box.position.y,-.52)
	gun.reparent(yaw,true)
	# Keep the pedestal planted; only the upper receiver, grips and barrels elevate.
	for part in gun.get_children():
		var part_box: AABB=body.global_transform.affine_inverse()*part.get_parent().global_transform*kit.bounds(part)
		if part_box.position.y>1.67: part.reparent(pitch,true)
	rotor=Node3D.new();pitch.add_child(rotor);rotor.position=Vector3(0,.25,-.5)
	for part in pitch.get_children():
		if String(part.name) in ["pCylinder9","pCylinder11","pCylinder10","pCylinder7","pCylinder6"]: part.reparent(rotor,true)
	muzzle=Node3D.new();pitch.add_child(muzzle)
	muzzle.position=Vector3(0,.25,box.position.z-.67-.05)
	gunner=kit.imported("res://../prototypes/first-operation/gunner.glb");yaw.add_child(gunner);gunner.rotation.y=PI;gunner.position=Vector3(0,.85-box.position.y,.45)
	for node in gunner.find_children("*","AnimationPlayer",true,false): pose_player=node
	if pose_player:
		for clip in pose_player.get_animation_list():
			if "GunnerCrouch" in clip: crouch_clip=clip
		pose_player.play(crouch_clip);pose_player.pause()
	gunner.hide()
	flash=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.07;mesh.height=.14;flash.mesh=mesh
	flash.material_override=kit.material(Color(1,.8,.25));muzzle.add_child(flash);flash.hide()
	samples=preload("res://world/turret_audio.gd").new();muzzle.add_child(samples)
	audio=samples.firing;motor=samples.motor

func spread_degrees() -> float: return lerpf(MIN_SPREAD,MAX_SPREAD,bloom)
func fire_rate() -> float: return lerpf(MIN_RATE,MAX_RATE,clampf((spin-COLD_DELAY)/RAMP_TIME,0,1))

func advance_trigger(delta: float, held: bool) -> int:
	var previous=spin
	spin=clampf(spin+delta if held else spin-delta*1.5,0,COLD_DELAY+RAMP_TIME)
	if not held:
		bloom=move_toward(bloom,0,delta*.8);shot_wait=maxf(0,shot_wait-delta);return 0
	if spin<COLD_DELAY: return 0
	var firing_delta=delta if previous>=COLD_DELAY else maxf(0,spin-COLD_DELAY)
	shot_wait-=firing_delta
	var count=0
	while shot_wait<=0:
		count+=1;shot_wait+=1.0/fire_rate()
	return count

func cone_direction(forward: Vector3) -> Vector3:
	var axis=Vector3.UP if absf(forward.dot(Vector3.UP))<.95 else Vector3.RIGHT
	var right=forward.cross(axis).normalized();var up=right.cross(forward).normalized()
	var cos_angle=lerpf(1,cos(deg_to_rad(spread_degrees())),rng.randf());var azimuth=rng.randf()*TAU
	return (forward*cos_angle+(right*cos(azimuth)+up*sin(azimuth))*sqrt(1-cos_angle*cos_angle)).normalized()

func fire_round() -> void:
	var arena=kit.arena
	# Converge on the crosshair, then trace from the breech so cover blocks the gun.
	var aim_ray=PhysicsRayQueryParameters3D.create(arena.camera.global_position,arena.camera.global_position-arena.camera.global_basis.z*500)
	aim_ray.exclude=[body.get_rid(),arena.player.get_rid()]
	var space=arena.get_world_3d().direct_space_state;var aim_hit=space.intersect_ray(aim_ray)
	var aim: Vector3=aim_hit.position if not aim_hit.is_empty() else aim_ray.to
	var start=pitch.global_position;var direction=cone_direction((aim-start).normalized())
	var ray=PhysicsRayQueryParameters3D.create(start,start+direction*500);ray.exclude=aim_ray.exclude
	var hit=space.intersect_ray(ray);var end: Vector3=hit.position if not hit.is_empty() else ray.to
	kit.tracer(start,end)
	if not hit.is_empty():
		if hit.collider.has_method("take_hit"): hit.collider.take_hit(14.0,start,end)
		elif hit.collider.has_meta("target_hits"): hit.collider.set_meta("target_hits",int(hit.collider.get_meta("target_hits"))+1)
	shots+=1;bloom=minf(1,bloom+.045);flash_time=.035;flash.show()

func _physics_process(delta: float) -> void:
	if not yaw: return
	var occupied=kit.gunning and kit.driving==body
	var debug_menu=kit.arena.get("rex_menu")
	var active=occupied and not kit.menu.opened and not (debug_menu and debug_menu.blocks_player()) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED
	var held=active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rounds=advance_trigger(delta,held)
	samples.update(delta,held,held and spin>=COLD_DELAY,spin,COLD_DELAY)
	if active:
		yaw.rotation.y=kit.driver_look.x;pitch.rotation.x=kit.driver_look.y
		for i in range(rounds): fire_round()
	crouch=move_toward(crouch,clampf((pitch.rotation.x+PI/6)/(PI/3),0,1),delta*3)
	if pose_player: pose_player.seek(crouch*pose_player.get_animation(crouch_clip).length,true)
	gunner.visible=occupied and int(kit.warthog_menu.settings.camera_mode)==0
	if spin>.01:
		rotor.rotation.z-=spin*delta*35
	flash_time-=delta
	if flash_time<=0: flash.hide()
	if occupied and not kit.menu.opened:
		kit.status.text="WARTHOG TURRET · Hold left mouse fire · E exit · C view\n%s · %.0f RPM · %.1f° spread" % ["SPINNING UP" if spin>0 and spin<COLD_DELAY else "READY",fire_rate()*60,spread_degrees()]

func update_camera() -> void:
	kit.arena.player.global_position=yaw.to_global(Vector3(0,.85-yaw.position.y,.45))
	var basis=body.global_basis*Basis.from_euler(Vector3(kit.driver_look.y,kit.driver_look.x,0))
	# Eye remains behind the receiver throughout pitch travel; never orbit it into the gun.
	var chase=int(kit.warthog_menu.settings.camera_mode)==0
	# Centre the sight line above the receiver and rotate it with the barrel.
	var eye=yaw.to_global(Vector3(0,1.82-.35*crouch,.95)) if chase else pitch.to_global(Vector3(0,.62,1.15))
	var wanted=eye+yaw.global_basis.z*3.8+body.global_basis.y*.9 if chase else eye
	gunner.visible=chase
	var ray=PhysicsRayQueryParameters3D.create(eye,wanted);ray.exclude=[body.get_rid(),kit.arena.player.get_rid()]
	var hit=kit.arena.get_world_3d().direct_space_state.intersect_ray(ray)
	kit.arena.camera.global_transform=Transform3D(basis,hit.position+hit.normal*.15 if not hit.is_empty() else wanted)
	kit.arena.camera.fov=kit.warthog_menu.settings.camera_fov
