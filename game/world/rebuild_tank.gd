extends "res://world/tank_controller.gd"
const Ring=preload("res://world/terrain_drive_ring.gd")
var animation_clock := 0.0
var aim_layer: CanvasLayer
var aim_mark: Label
func _ready() -> void:
	super._ready()
	aim_layer=CanvasLayer.new();add_child(aim_layer)
	aim_mark=Label.new();aim_mark.text="+";aim_mark.add_theme_font_size_override("font_size",28);aim_mark.add_theme_color_override("font_color",Color(.25,.7,1));aim_mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;aim_layer.add_child(aim_mark);aim_mark.hide()
func build_contacts() -> void:
	suspension_exclusions.append(kit.arena.on_foot.get_rid())
	for side in [-1.0,1.0]:
		for z in [-1.65,-.10,1.45,2.95]:
			var center=Vector3(side*tracks.half_width,.40,z)
			var hub=Node3D.new();add_child(hub);hub.position=center
			var spin=Node3D.new();hub.add_child(spin)
			corners.append({"anchor":center-Vector3(side*rest_hub.x,rest_hub.y,0),"side":side,"radius":.40,"hub":hub,"spin":spin,"links":[],"front":z<.65,"travel":0.0,"compression":0.0})
func _physics_process(delta: float) -> void:
	# Invoke the shared tyre/suspension implementation, but budget belt animation.
	if freeze or streaming_suspended: return
	suspension_step(delta)
	animation_clock+=delta
	var distance=kit.arena.camera.global_position.distance_squared_to(global_position)
	var interval=1.0/30.0 if distance<3600 else .1
	if animation_clock<interval: return
	track_speeds=Vector2.ZERO
	for corner in corners: track_speeds[0 if corner.side<0 else 1]+=corner.get("omega",0.0)*corner.radius/4.0
	if track_speeds.length_squared()>.0025 and distance<40000: tracks.animate(animation_clock,track_speeds.x,track_speeds.y)
	animation_clock=0
func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	if aim_mark: aim_mark.hide()
	if not kit or not kit.driving or kit.car!=self or kit.menu.opened or kit.arena.editor.opened or not kit.arena.loading.dismissed: return
	turret.rotation.y=rotate_toward(turret.rotation.y,kit.driver_look.x,deg_to_rad(turret_rate)*delta)
	barrel.rotation.x=move_toward(barrel.rotation.x,clampf(kit.driver_look.y,deg_to_rad(-8),deg_to_rad(22)),deg_to_rad(turret_rate*.6)*delta)
	var aim=muzzle.global_position-muzzle.global_basis.z*150
	if not kit.arena.camera.is_position_behind(aim):
		aim_mark.position=kit.arena.camera.unproject_position(aim)-Vector2(9,20);aim_mark.show()
	if not DisplayServer.window_is_focused(): return
	var pad=kit.arena.controller
	if (Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) or (pad and pad.using_controller and pad.buttons.get(JOY_BUTTON_RIGHT_SHOULDER,false)):
		fire_cannon()
func fire_cannon() -> bool:
	if cooldown>0 or not kit.driving or kit.car!=self or kit.menu.opened or kit.arena.editor.opened or not kit.arena.loading.dismissed: return false
	cooldown=reload_time;cannon_audio.play()
	var start=barrel.global_position;var end=muzzle.global_position-muzzle.global_basis.z*450
	var ray=PhysicsRayQueryParameters3D.create(start,end,7);ray.exclude=[get_rid(),kit.arena.on_foot.get_rid()]
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	var point: Vector3=hit.position if not hit.is_empty() else end
	var weapons=kit.arena.weapons
	weapons.effects.append({"from":start,"to":point,"color":Color(1,.7,.2),"ttl":.16,"hit":not hit.is_empty()});weapons.update_effects()
	if not hit.is_empty():
		if hit.collider.has_method("take_hit"): hit.collider.take_hit(cannon_damage,start,point)
		for prop in get_tree().get_nodes_in_group("blast_props"):
			if prop.has_method("blast_impulse"): prop.blast_impulse(point,6.0,4500.0)
	return true
