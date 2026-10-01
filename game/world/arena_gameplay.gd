extends Node
var arena: Node3D
var content: Node
var initialized := false
var actors: Array[Node3D]=[]
var vehicle: RigidBody3D
var vehicle_home := Transform3D.IDENTITY
var controlled_actor: Node3D
var driving := false
var vehicle_patrol := false
var vehicle_route: Array[Vector3]=[Vector3(-28,0,-34),Vector3(-58,0,-55),Vector3(-48,0,-10),Vector3(-28,0,-5)]
var vehicle_waypoint := 0
var weapons: Array[Node3D]=[]
var selected := 0
var holder: Node3D
var arms: Node3D
var ammo := [30,5]
var reloading := 0.0
var shot_wait := 0.0
var player_health := 100.0
var turret_yaw: Node3D
var turret_muzzle: Node3D
var routes: MeshInstance3D
var show_routes := false
var health_hud: Label
var crosshair: Label
var message := ""
var message_time := 0.0
var shots := 0
var checks_started := false
var gun_audio: AudioStreamPlayer
var test_complete := false
var test_vehicle_controls := false
var test_capture := false
var weapon_sounds: Array[AudioStream]=[]

func setup_turret(model: Node3D) -> void:
	var gun := model.find_child("Gun1",true,false) as Node3D
	if not gun: gun=model.find_child("Gun",true,false) as Node3D
	turret_yaw=Node3D.new();vehicle.add_child(turret_yaw)
	turret_yaw.position=Vector3(0,1.45,.6)
	if gun: gun.reparent(turret_yaw,true)
	turret_muzzle=Node3D.new();turret_yaw.add_child(turret_muzzle);turret_muzzle.position=Vector3(0,.8,-1.4)

func build_weapons() -> void:
	# Reuse archive importer and established first-operation transforms.
	var layer := CanvasLayer.new();add_child(layer)
	health_hud=Label.new();health_hud.position=Vector2(12,130);layer.add_child(health_hud)
	crosshair=Label.new();crosshair.text="+";layer.add_child(crosshair)
	var container := SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter=Control.MOUSE_FILTER_IGNORE;container.stretch=true;layer.add_child(container)
	# Viewmodel cannot clip into landscape; separate transparent viewport.
	var view := SubViewport.new();view.size=Vector2i(get_viewport().get_visible_rect().size)
	view.transparent_bg=true;view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	container.add_child(view)
	get_viewport().size_changed.connect(func(): view.size=Vector2i(get_viewport().get_visible_rect().size))
	var camera := Camera3D.new();camera.near=.01;camera.far=10;camera.fov=65;view.add_child(camera)
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7;view.add_child(environment)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);view.add_child(light)
	holder=Node3D.new();holder.position=Vector3(.3,-.25,-.5);camera.add_child(holder)
	arms=content.import_source(ProjectSettings.globalize_path("res://../assets/fp_arms.zip").simplify_path())
	if arms:
		arms.set_script(preload("res://fp_arms_controller.gd"))
		arms.transform=Transform3D(Basis(Vector3(-.180993,0,.010583),Vector3(0,.1813025,0),Vector3(-.010583,0,-.180993)),Vector3(-.29,.19,.45))
		holder.add_child(arms)
	for name in ["halo_-_carbine","halo_railgun_redesigned"]:
		await get_tree().process_frame
		var model: Node3D=content.import_source(ProjectSettings.globalize_path("res://../assets/"+name+".zip").simplify_path())
		assert(model!=null,"Weapon archive unavailable: "+name)
		if weapons.is_empty():
			model.transform=Transform3D(Basis(Vector3(.034928,-.001051,-.001979),Vector3(.001057,.034984,.000066),Vector3(-.001976,.000125,-.034944)),Vector3(-.257,.18,.31))
		else:
			model.transform=Transform3D(Basis(Vector3(0,0,.0035),Vector3(0,.0035,0),Vector3(.0035,0,0)),Vector3(-.25,.23,.29))
		holder.add_child(model);weapons.append(model)
	select_weapon(0)
	gun_audio=AudioStreamPlayer.new();gun_audio.stream=load("res://plasma_rifle.mp3");gun_audio.volume_db=-18;add_child(gun_audio)
	weapon_sounds=[gun_audio.stream,load("res://quake railgun sound effect.mp3")]

func select_weapon(index: int) -> void:
	if reloading>0 or weapons.is_empty(): return
	selected=posmod(index,weapons.size())
	for i in weapons.size(): weapons[i].visible=i==selected
	if arms: arms.set_weapon_pose("carbine" if selected==0 else "railgun")

func move_direction() -> Vector3:
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: return Vector3.ZERO
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): direction-=arena.camera.basis.z
	if Input.is_key_pressed(KEY_S): direction+=arena.camera.basis.z
	if Input.is_key_pressed(KEY_A): direction-=arena.camera.basis.x
	if Input.is_key_pressed(KEY_D): direction+=arena.camera.basis.x
	direction.y=0;return direction.normalized()

func own_movement() -> bool:
	return controlled_actor!=null or driving

func handle_input(event: InputEvent) -> bool:
	if not initialized: return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				var index := actors.find(controlled_actor)
				release_control();possess(actors[(index+1)%actors.size()]);return true
			KEY_E:
				if own_movement(): release_control()
				elif arena.camera.position.distance_to(vehicle.position)<9: enter_vehicle()
				else:
					var nearest: Node3D
					var distance := 8.0
					for actor in actors:
						var d: float=arena.camera.position.distance_to(actor.position)
						if actor.health>0 and d<distance: nearest=actor;distance=d
					if nearest: possess(nearest)
				return true
			KEY_BACKSPACE: release_control();return true
			KEY_Q: select_weapon(selected+1);return true
			KEY_R:
				if arena.walking and not own_movement() and reloading<=0: reloading=1.5
				return arena.walking or own_movement()
			KEY_P:
				if driving:
					vehicle_patrol=not vehicle_patrol;release_control()
				elif controlled_actor: controlled_actor.patrol_enabled=not controlled_actor.patrol_enabled
				else:
					for actor in actors: actor.patrol_enabled=not actor.patrol_enabled
				return true
			KEY_V: show_routes=not show_routes;routes.visible=show_routes;return true
			KEY_Y: reset_all();return true
			KEY_H:
				release_control();arena.walking=false;arena.camera.position=vehicle.position+Vector3(0,3,6)
				arena.camera.look_at(vehicle.position+Vector3.UP);arena.look=Vector2(arena.camera.rotation.y,arena.camera.rotation.x);return true
			KEY_F:
				if own_movement(): release_control();return true
			KEY_0,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9: release_control()
	return false

func possess(actor: Node3D) -> void:
	if actor.health<=0: return
	release_control();controlled_actor=actor;actor.controlled=true;arena.walking=false
	arena.look=Vector2(actor.rotation.y,-.2);arena.camera.rotation=Vector3(arena.look.y,arena.look.x,0)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func enter_vehicle() -> void:
	release_control();driving=true;vehicle.controlled=true;vehicle_patrol=false;arena.walking=false
	arena.look=Vector2(vehicle.rotation.y,-.2);arena.camera.rotation=Vector3(arena.look.y,arena.look.x,0)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func release_control() -> void:
	if controlled_actor: controlled_actor.controlled=false
	controlled_actor=null;driving=false
	if vehicle: vehicle.controlled=vehicle_patrol;vehicle.set_controls(0,0,true)

func reset_all() -> void:
	release_control();vehicle_patrol=false;vehicle_waypoint=0
	vehicle.transform=vehicle_home;vehicle.linear_velocity=Vector3.ZERO;vehicle.angular_velocity=Vector3.ZERO
	for actor in actors: actor.reset_actor()
	player_health=100;ammo=[30,5];reloading=0

func player_hit(damage: float) -> void:
	player_health=maxf(0,player_health-damage)
	if player_health<=0:
		arena.walking=false;arena.camera.position+=Vector3.UP*8;message="Down — Y resets the arena";message_time=4

func aim_direction(origin: Vector3, shooter: CollisionObject3D) -> Vector3:
	var end: Vector3=arena.camera.position-arena.camera.basis.z*300
	var query := PhysicsRayQueryParameters3D.create(arena.camera.position,end,3)
	query.exclude=[shooter.get_rid()]
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
	return ((hit.position if not hit.is_empty() else end)-origin).normalized()

func shoot(origin: Vector3, direction: Vector3, damage: float, reach: float, shooter: Node3D, color: Color) -> Dictionary:
	direction=direction.normalized()
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*reach,3)
	if shooter is CollisionObject3D: query.exclude=[shooter.get_rid()]
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
	var end := origin+direction*reach
	if not hit.is_empty():
		end=hit.position
		if hit.collider.has_method("take_hit"): message=hit.collider.take_hit(damage,origin,end);message_time=1.5
		elif hit.collider==arena.player: player_hit(damage)
	var mesh := ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(origin);mesh.surface_add_vertex(end);mesh.surface_end()
	var tracer := MeshInstance3D.new();tracer.mesh=mesh
	var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color
	tracer.material_override=material;arena.add_child(tracer)
	get_tree().create_timer(.08).timeout.connect(tracer.queue_free)
	flash(end,color);shots+=1
	return hit

func flash(point: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new();var sphere := SphereMesh.new();sphere.radius=.08;sphere.height=.16
	visual.mesh=sphere;var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color
	visual.material_override=material;arena.add_child(visual);visual.global_position=point
	get_tree().create_timer(.1).timeout.connect(visual.queue_free)

func build_routes() -> void:
	routes=MeshInstance3D.new();arena.add_child(routes)
	var mesh := ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var paths: Array=[]
	for actor in actors: paths.append(actor.route)
	paths.append(vehicle_route)
	for path in paths:
		for i in path.size():
			for point in [path[i],path[(i+1)%path.size()]]:
				var hit: Dictionary=content.ground_at(Vector2(point.x,point.z))
				mesh.surface_add_vertex((hit.position if not hit.is_empty() else point)+Vector3.UP*.2)
	mesh.surface_end();routes.mesh=mesh
	var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(1,.7,.15)
	routes.material_override=material;routes.visible=false

func _physics_process(delta: float) -> void:
	if not initialized: return
	if test_capture: return
	shot_wait=maxf(0,shot_wait-delta);message_time=maxf(0,message_time-delta)
	if reloading>0:
		reloading-=delta
		if reloading<=0: ammo[selected]=30 if selected==0 else 5
	if controlled_actor:
		if controlled_actor.health<=0: release_control()
		else:
			var radius := 14.0 if controlled_actor.kind=="T-Rex" else 5.0
			arena.camera.position=controlled_actor.position+Vector3.UP*(5.0 if radius>10 else 2.5)+arena.camera.basis.z*radius
	if driving:
		vehicle.controlled=true
		if test_vehicle_controls: vehicle.set_controls(.8,0,false)
		else: vehicle.driver_controls(Input.is_key_pressed(KEY_W),Input.is_key_pressed(KEY_S),Input.is_key_pressed(KEY_SPACE),float(Input.is_key_pressed(KEY_A))-float(Input.is_key_pressed(KEY_D)))
		arena.camera.position=vehicle.position+Vector3.UP*3.2+arena.camera.basis.z*8
	elif vehicle_patrol:
		var goal := vehicle_route[vehicle_waypoint];goal.y=vehicle.position.y
		if vehicle.position.distance_to(goal)<5: vehicle_waypoint=(vehicle_waypoint+1)%vehicle_route.size()
		var direction := (goal-vehicle.position).normalized()
		var steer := clampf((-vehicle.basis.z).signed_angle_to(direction,Vector3.UP)*1.5,-1,1)
		vehicle.controlled=true;vehicle.set_controls(.5,steer,vehicle.linear_velocity.length()>9)
	else: vehicle.controlled=false;vehicle.set_controls(0,0,true)
	# Never simulate a vehicle onto missing collision during streaming.
	vehicle.freeze=not arena.neighborhood_ready(vehicle.position)
	if driving and turret_yaw:
		turret_yaw.rotation.y=arena.camera.rotation.y-vehicle.rotation.y
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and shot_wait<=0:
			shot_wait=.1;shoot(turret_muzzle.global_position,aim_direction(turret_muzzle.global_position,vehicle),15,220,vehicle,Color(1,.8,.2))
	elif arena.walking and not controlled_actor and player_health>0 and reloading<=0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and shot_wait<=0 and ammo[selected]>0:
			shot_wait=.18 if selected==0 else 1.0;ammo[selected]-=1
			shoot(arena.camera.position,-arena.camera.basis.z,25 if selected==0 else 120,250 if selected==0 else 600,arena.player,Color(.4,1,.5) if selected==0 else Color(.5,.8,1))
			gun_audio.stream=weapon_sounds[selected];gun_audio.play();holder.position.z=-.43
	if holder:
		holder.visible=arena.walking and not own_movement()
		holder.position.z=lerpf(holder.position.z,-.5,delta*12)
	health_hud.text="Tab possess aliens/Rex | H find Warthog, E enter/exit | Backspace observer\nLMB fire/bite | Q weapon | R reload | P patrol/hold | V routes | Y reset\n%s | %s %d | %s" % ["Warthog" if driving else (controlled_actor.kind if controlled_actor else "Player %.0f HP" % player_health),"Carbine" if selected==0 else "Railgun",ammo[selected],"Reloading" if reloading>0 else (message if message_time>0 else "")]
	crosshair.visible=arena.walking or own_movement()
	crosshair.position=get_viewport().get_visible_rect().size*.5-Vector2(4,12)
	if OS.get_cmdline_user_args().has("--gameplay-check") and not checks_started:
		checks_started=true;check_gameplay.call_deferred()

func check_gameplay() -> void:
	assert(actors.size()==4 and weapons.size()==2 and vehicle.corners.size()==4)
	for actor in actors:
		assert(actor.skeleton!=null and actor.animator!=null and not actor.clips.is_empty())
		var skins := 0
		for mesh in actor.model.find_children("*","MeshInstance3D",true,false):
			if mesh.skin: skins+=1
		assert(skins>0,"Live rig lost skin")
	var initial: Vector3=actors[0].position
	for i in 120: await get_tree().physics_frame
	assert(actors[0].position.distance_to(initial)>1,"Patrol did not move")
	var alien: Node3D=actors[0]
	alien.patrol_enabled=false
	var hp: float=alien.health
	var hit := shoot(alien.position+Vector3(0,1,-4),Vector3.BACK,25,8,null,Color.GREEN)
	assert(not hit.is_empty() and hit.collider==alien and alien.health==hp-25,"Damage ray did not hit actor")
	var before_shots := shots
	alien.controlled=true;alien.cooldown=0;alien.attack();alien.controlled=false
	assert(shots==before_shots+1 and alien.animator.current_animation==alien.clips["fire"])
	var rex: Node3D=actors[1]
	rex.patrol_enabled=false;alien.position=rex.position-rex.basis.z*5
	alien.health=100;rex.cooldown=0;rex.attack()
	assert(alien.health==20 and rex.action_time>0,"Rex bite did not damage front target")
	alien.take_hit(25);assert(alien.health==0)
	alien.reset_actor();assert(alien.health==alien.max_health)
	select_weapon(1);assert(weapons[1].visible and not weapons[0].visible);select_weapon(0)
	possess(alien);assert(alien.controlled and own_movement());release_control();assert(not alien.controlled)
	enter_vehicle();assert(driving and vehicle.controlled);release_control()
	vehicle.controlled=true;vehicle.set_controls(.6,0,false)
	var start: Vector3=vehicle.position
	# Exercise real traction without depending on physical keyboard state.
	driving=true;test_vehicle_controls=true
	for i in 180: await get_tree().physics_frame
	driving=false;test_vehicle_controls=false
	assert(vehicle.grounded_count>0,"Vehicle suspension has no ground contact")
	assert(vehicle.position.distance_to(start)>2,"Vehicle did not drive")
	print("GAMEPLAY_VEHICLE displacement=",vehicle.position.distance_to(start)," contacts=",vehicle.grounded_count)
	reset_all();test_complete=true
	print("PASS: live skins/clips, patrol movement, weapons/switching, alien fire/death/reset, Rex bite, possession/release, four-wheel driving")
	if OS.get_cmdline_user_args().has("--gameplay-capture"):
		arena.walking=true
		var floor_hit: Dictionary=content.ground_at(Vector2(8,-37))
		arena.player.position=floor_hit.position+Vector3.UP*.1
		arena.camera.position=arena.player.position+Vector3.UP*1.6;arena.camera.look_at(actors[0].position+Vector3.UP)
		arena.look=Vector2(arena.camera.rotation.y,arena.camera.rotation.x)
		for i in 10: await get_tree().process_frame
		test_capture=true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://sdf-arena-gameplay.png")
		select_weapon(1)
		health_hud.text=health_hud.text.replace("Carbine 30","Railgun 5")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://sdf-arena-railgun.png")
	get_tree().quit()
