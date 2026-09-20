extends Node
# Local source assets remain in their original directories; no duplicate imported art in Git.
const GAME := "C:/Games/possession/game/"
const WORKSHOP := "C:/Users/Bran the builder/Documents/Codex/Possession-models/model-workshop/assets/weapons/"
var arena: Node3D
var view: SubViewport
var overlay: SubViewportContainer
var holder: Node3D
var arms: Node3D
var weapons: Array[Node3D] = []
var names: Array[String] = []
var selected := 0
var cooldown := 0.0
var recoil := 0.0
var vehicles: Array = []
var driving
var gunning := false
var warthog_turret: Node3D
var speed := 0.0
var status: Label
var shot_count := 0
var ammo := {"Carbine":24,"Railgun":6}
var reloading := false
var shot_audio: AudioStreamPlayer
var gun_sounds: Dictionary={}

func reload_weapon() -> void:
	if reloading or driving or names[selected] not in ammo: return
	var key=names[selected];var capacity=24 if key=="Carbine" else 6
	if ammo[key]==capacity: return
	reload_audio.play();reloading=true;status.text=key+" / RELOADING"
	await get_tree().create_timer(1.5 if key=="Carbine" else 2.2).timeout
	ammo[key]=capacity;reloading=false;status.text=key+" / %d ROUNDS" % ammo[key]
var menu: CanvasLayer
var warthog_menu: CanvasLayer
var combat_menu: CanvasLayer
var tank_menu: CanvasLayer
var reload_audio: AudioStreamPlayer
var driver_model: Node3D
var driver_look := Vector2.ZERO
var seat_position := Vector3(-.52,.92,-.08)
var foot_fov := 75.0

func build_driver() -> void:
	driver_model=imported("res://seated_driver.glb")
	if not driver_model: driver_model=Node3D.new()
	vehicles[0].add_child(driver_model)
	# The reference soldier faces +Z. Place its hip at the left-hand seat.
	driver_model.rotation.y=PI
	driver_model.position=seat_position-Vector3(0,.98,0)
	driver_model.hide()

func handle_vehicle_input(event: InputEvent) -> bool:
	if not menu: return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F3:
			var was_open=menu==combat_menu and menu.opened
			menu.set_open(false);menu=combat_menu;menu.set_open(not was_open);get_viewport().set_input_as_handled();return true
		if event.keycode==KEY_ESCAPE and menu.opened:
			menu.set_open(false);get_viewport().set_input_as_handled();return true
		if event.keycode==KEY_G:
			arena.get_node("PracticeRange").throw_grenade();get_viewport().set_input_as_handled();return true
		if event.keycode==KEY_R and not driving and arena.camera.position.distance_to(Vector3(0,2,0))>=7:
			reload_weapon();get_viewport().set_input_as_handled();return true
		if event.keycode==KEY_F2:
			if not menu.opened or menu==combat_menu:
				menu.set_open(false)
				var chosen=driving
				if not chosen:
					chosen=vehicles[0]
					for v in vehicles:
						if arena.walker.position.distance_to(v.position)<6: chosen=v
				menu=tank_menu if chosen==vehicles[1] else warthog_menu
			menu.set_open(not menu.opened);get_viewport().set_input_as_handled();return true
		if event.keycode==KEY_C and driving:
			(tank_menu if driving==vehicles[1] else warthog_menu).set_camera_mode(1-int((tank_menu if driving==vehicles[1] else warthog_menu).settings.camera_mode));get_viewport().set_input_as_handled();return true
		if event.keycode==KEY_HOME and driving: driver_look=Vector2.ZERO;return true
	if menu.opened: return true
	if driving and event is InputEventMouseMotion:
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
			driver_look.x=driver_look.x-event.relative.x*.003 if gunning or driving.has_method("fire_cannon") else clampf(driver_look.x-event.relative.x*.003,-1.6,1.6)
			driver_look.y=clampf(driver_look.y-event.relative.y*.003,-PI/6 if gunning else -.7,PI/6 if gunning else .5)
		return true
	return false

func update_vehicle_camera(delta: float) -> void:
	if gunning:
		warthog_turret.update_camera();driver_model.hide();return
	var cfg: Dictionary=(tank_menu if driving==vehicles[1] else warthog_menu).settings
	arena.walker.global_position=driving.to_global(seat_position)
	arena.camera.fov=cfg.camera_fov
	if int(cfg.camera_mode)==1:
		var eye=seat_position+Vector3(0,.68,-.03)
		if driving!=vehicles[0]: eye=Vector3(0,2.8,0)
		arena.camera.global_transform=driving.global_transform*Transform3D(Basis.from_euler(Vector3(driver_look.y,driver_look.x,0)),eye)
		# Hide the body in first person to prevent the head intersecting the lens.
		driver_model.hide()
	else:
		driver_model.visible=driving==vehicles[0]
		var target: Vector3=driving.global_position+Vector3.UP*1.4
		if driving.has_method("fire_cannon"):
			target=driving.to_global(Vector3(0,1.75,1.1))-(driving.global_basis*Basis.from_euler(Vector3(driver_look.y,driver_look.x,0))).z*80
		var wanted: Vector3=driving.global_position+(driving.global_basis*Basis(Vector3.UP,driver_look.x) if driving.has_method("fire_cannon") else driving.global_basis).z*cfg.camera_distance+Vector3.UP*cfg.camera_height
		var ray=PhysicsRayQueryParameters3D.create(driving.global_position+Vector3.UP*1.4,wanted);ray.exclude=[driving.get_rid(),arena.walker.get_rid()]
		var hit=arena.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): wanted=hit.position+hit.normal*.25
		var next: Vector3=arena.camera.global_position.lerp(wanted,1-exp(-cfg.camera_smoothing*delta))
		# Also check the smoothed location: smoothing must not leave the lens behind a wall.
		ray.to=next;hit=arena.get_world_3d().direct_space_state.intersect_ray(ray)
		arena.camera.global_position=hit.position+hit.normal*.25 if not hit.is_empty() else next
		arena.camera.look_at(target)

func imported(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		push_warning("Arena asset missing: "+path);return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: int
	if path.ends_with(".gltf"):
		# Embed source bytes in memory so another project's .import remaps cannot redirect textures.
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		for group in ["buffers","images"]:
			for entry in data.get(group,[]):
				var uri: String=entry.get("uri","")
				if uri.is_empty() or uri.begins_with("data:"): continue
				var bytes=FileAccess.get_file_as_bytes(path.get_base_dir().path_join(uri.uri_decode()))
				if bytes.is_empty(): push_error("Missing GLTF dependency: "+uri);return null
				var mime="application/octet-stream" if group=="buffers" else ("image/jpeg" if uri.to_lower().ends_with(".jpg") or uri.to_lower().ends_with(".jpeg") else "image/png")
				entry["uri"]="data:"+mime+";base64,"+Marshalls.raw_to_base64(bytes)
		err=doc.append_from_buffer(JSON.stringify(data).to_utf8_buffer(),"",state)
	else:
		err=doc.append_from_file(path,state)
	if err!=OK: push_warning("Cannot load arena asset: "+path);return null
	return doc.generate_scene(state) as Node3D

func bounds(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array = [[root,Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array=stack.pop_back()
		var node: Node=entry[0]
		var transform: Transform3D=entry[1]
		if node is Node3D: transform=transform*node.transform
		if node is MeshInstance3D and node.mesh:
			var box: AABB=transform*node.mesh.get_aabb()
			result=result.merge(box) if found else box;found=true
		for child in node.get_children(): stack.append([child,transform])
	return result

func socket(root: Node3D, key: String) -> Vector3:
	var node=root.find_child(key,true,false) as Node3D
	if not node: return Vector3.ZERO
	var point:=Vector3.ZERO
	while node and node!=root:
		point=node.transform*point;node=node.get_parent() as Node3D
	return point

func _ready() -> void:
	arena=get_parent()
	reload_audio=AudioStreamPlayer.new();reload_audio.stream=preload("res://mechanical_audio.gd").make_sound();reload_audio.volume_db=-15;add_child(reload_audio)
	shot_audio=AudioStreamPlayer.new();shot_audio.volume_db=-17;add_child(shot_audio)
	for pair in [["Carbine","plasma_rifle.mp3"],["Railgun","quake railgun sound effect.mp3"]]:
		var stream=AudioStreamMP3.new();stream.data=FileAccess.get_file_as_bytes(GAME+pair[1]);gun_sounds[pair[0]]=stream
	build_viewmodel()
	vehicle("Warthog",GAME+"halo_warthog/scene.gltf",Vector3(-17,1,9),4.8)
	vehicle("Altay",GAME+"altay_main_battle_tank_fbx.glb",Vector3(-29,1,9),9.0)
	build_driver()
	menu=preload("res://vehicle_menu.gd").new();add_child(menu);warthog_menu=menu
	tank_menu=preload("res://vehicle_menu.gd").new();tank_menu.vehicle_index=1;add_child(tank_menu)
	combat_menu=preload("res://combat_menu.gd").new();add_child(combat_menu)
	arena.help.text+="\nF3 plasma speed · F2 vehicle setup · G frag"
	for i in range(3):
		var target=StaticBody3D.new()
		target.position=Vector3(12+i*4,1.25,-18-i*6)
		target.set_meta("target_hits",0)
		var shape=CollisionShape3D.new();var cube=BoxShape3D.new();cube.size=Vector3(1.1,2.5,0.35);shape.shape=cube
		target.add_child(shape);arena.add_child(target)
		arena.box(Vector3.ZERO,cube.size,arena.material(Color(0.5,0.25,0.16)),target)
	var layer=CanvasLayer.new();add_child(layer)
	status=Label.new();status.position=Vector2(20,190);status.text="Q weapon · Left mouse use · E enter/exit nearby vehicle\nH expose suspension · J reset Warthog at test course · F2 vehicle setup · C view";layer.add_child(status)
	var reticle=Label.new();reticle.text="+";reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER);layer.add_child(reticle)
	reticle.position=get_viewport().get_visible_rect().size*.5-Vector2(5,10)
	if arena.shots_running: layer.hide()
	print("KIT_READY: arms=%s weapons=%s vehicles=%d" % [arms!=null,str(names),vehicles.size()])

func build_viewmodel() -> void:
	var layer=CanvasLayer.new();add_child(layer)
	overlay=SubViewportContainer.new();overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.stretch=true;layer.add_child(overlay)
	view=SubViewport.new();view.size=get_viewport().get_visible_rect().size;view.gui_disable_input=true;view.transparent_bg=true;view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;overlay.add_child(view)
	var camera=Camera3D.new();camera.near=0.01;camera.far=10;camera.fov=65;view.add_child(camera)
	var env=WorldEnvironment.new();env.environment=arena.environment.duplicate();env.environment.background_mode=Environment.BG_CLEAR_COLOR;view.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.light_energy=1.1;view.add_child(sun)
	holder=Node3D.new();holder.position=Vector3(0.3,-0.25,-0.5);camera.add_child(holder)
	arms=imported(GAME+"fp_arms/scene.gltf")
	if arms:
		arms.set_script(preload("res://fp_arms_controller.gd"))
		arms.transform=Transform3D(Basis(Vector3(-0.180993,0,0.010583),Vector3(0,0.1813025,0),Vector3(-0.010583,0,-0.180993)),Vector3(-0.29,0.19,0.45))
		holder.add_child(arms)
	var carbine=imported(GAME+"halo_-_carbine/scene.gltf")
	if carbine:
		carbine.transform=Transform3D(Basis(Vector3(.034928,-.001051,-.001979),Vector3(.001057,.034984,.000066),Vector3(-.001976,.000125,-.034944)),Vector3(-.257,.18,.31))
		add_weapon(carbine,"Carbine")
	var railgun=imported(GAME+"halo_railgun_redesigned/scene.gltf")
	if railgun:
		railgun.transform=Transform3D(Basis(Vector3(0,0,.0035),Vector3(0,.0035,0),Vector3(.0035,0,0)),Vector3(-.25,.23,.29))
		add_weapon(railgun,"Railgun")
	for key in ["blade","spear","club","improvised","rock"]:
		var model=imported(WORKSHOP+key+"/model.glb")
		if not model: continue
		# Preserve metres and use the exported grip/tip markers, not the mesh centre.
		var grip_name="ATTACH_GRIP" if key in ["blade","spear"] else ("grip_marker" if key=="rock" else "marker_grip_rear")
		var tip_name="ATTACH_TIP" if key in ["blade","spear"] else ("release_marker" if key=="rock" else "marker_strike")
		var grip=socket(model,grip_name)
		var direction=socket(model,tip_name)-grip
		if direction.length()>0.001:
			var aim=Vector3(-.15,.3,-1).normalized() if key in ["blade","spear"] else Vector3(-.15,.8,-.7).normalized()
			model.basis=Basis(Quaternion(direction.normalized(),aim))
		model.position=Vector3(-.05,-.1,0)-model.basis*grip
		add_weapon(model,key.capitalize())
	select_weapon(0)

func add_weapon(model: Node3D, label: String) -> void:
	holder.add_child(model);weapons.append(model);names.append(label)

func select_weapon(index: int) -> void:
	if reloading: return
	if weapons.is_empty(): return
	selected=posmod(index,weapons.size())
	for i in range(weapons.size()): weapons[i].visible=i==selected
	if arms: arms.set_weapon_pose(names[selected].to_lower())
	if status: status.text=names[selected]+" · Q cycle · Left mouse use · E interact"

func vehicle(label: String, path: String, pos: Vector3, length_m: float) -> void:
	var model=imported(path)
	if not model: return
	var a=bounds(model)
	if a.size.x > a.size.z: model.rotation.y=-PI*0.5
	# These two source models face +Z after axis alignment; movement uses -Z.
	model.rotate_y(PI)
	a=bounds(model)
	model.scale*=length_m/maxf(a.size.z,0.01)
	a=bounds(model);model.position-=Vector3(a.get_center().x,a.position.y,a.get_center().z)
	var body
	if label=="Warthog":
		body=preload("res://wishbone_vehicle.gd").new()
		body.suspension_exclusions.append(arena.walker.get_rid())
		body.name=label;body.position=pos;body.add_child(model)
		# Cover the visible hull and bumpers, leaving clearance for the ray suspension.
		var collision=CollisionShape3D.new();collision.name="ChassisCollision";var shape=BoxShape3D.new();shape.size=Vector3(a.size.x*.82,.76,length_m*.92);collision.shape=shape;collision.position.y=.85;body.add_child(collision)
		preload("res://warthog_finish.gd").finish(model,Callable(self,"bounds"));body.track_extension=.18;body.wheel_mount_raise=.14;arena.add_child(body);body.center_of_mass.y=.48;body.setup(model,Callable(self,"bounds"));body.add_child(preload("res://vehicle_audio.gd").new());body.add_child(preload("res://wheel_dirt.gd").new())
		warthog_turret=preload("res://warthog_turret.gd").new();body.add_child(warthog_turret);warthog_turret.setup(self,body,model)
	else:
		body=preload("res://tank_controller.gd").new();body.name=label;body.position=pos;body.floor_snap_length=1.0;body.floor_max_angle=deg_to_rad(50);body.add_child(model)
		# The chassis itself is a broad physical obstacle. Track probes report
		# traction and attitude; this collider takes ridges, banks and walls.
		var collision=CollisionShape3D.new();collision.name="HullCollision";var shape=BoxShape3D.new();shape.size=Vector3(a.size.x*.82,.9,length_m*.74);collision.shape=shape;collision.position.y=.45;body.add_child(collision)
		arena.add_child(body);body.setup(model,self)
	vehicles.append(body)
	body.collision_mask|=4
	var impacts=preload("res://vehicle_impacts.gd").new();impacts.kit=self;body.add_child(impacts)
	arena.label3(label+(" / E sides: drive / rear: turret" if label=="Warthog" else " / E"),pos+Vector3(0,3.5,0),32)

func toggle_vehicle() -> void:
	if driving:
		# Exit only where the player's capsule fits, with ground beneath it.
		var space=arena.get_world_3d().direct_space_state
		for side in [-1.0,1.0]:
			var p=driving.position+driving.basis.x*side*4.0
			var ray=PhysicsRayQueryParameters3D.create(p+Vector3.UP*8,p-Vector3.UP*12);ray.exclude=[driving.get_rid(),arena.walker.get_rid()]
			var hit=space.intersect_ray(ray)
			if hit.is_empty(): continue
			p=hit.position+Vector3.UP*0.1
			var query=PhysicsShapeQueryParameters3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.34;capsule.height=1.8;query.shape=capsule;query.transform.origin=p+Vector3.UP*.9;query.exclude=[arena.walker.get_rid()]
			if not space.intersect_shape(query).is_empty(): continue
			var exited=driving
			arena.walker.position=p;arena.walker.velocity=Vector3.ZERO;arena.walker.get_child(0).shape.height=1.8;arena.walker.get_child(0).position.y=.9
			arena.walker.force_update_transform();arena.walker.reset_physics_interpolation()
			arena.walker.collision_layer=1;arena.walker.collision_mask=1;arena.set_physics_process(true);driving=null;gunning=false;driver_model.hide();arena.camera.fov=foot_fov;overlay.show();restore_vehicle_collision(exited);return
		status.text="Exit obstructed";return
	for body in vehicles:
		if arena.walker.position.distance_to(body.position)<6:
			body.add_collision_exception_with(arena.walker);arena.walker.add_collision_exception_with(body)
			var local=body.to_local(arena.walker.global_position)
			gunning=body==vehicles[0] and local.z>1.3 and absf(local.x)<1.8
			driving=body;menu=tank_menu if body==vehicles[1] else warthog_menu;driver_look=Vector2.ZERO;foot_fov=arena.camera.fov;driver_model.visible=body==vehicles[0];speed=0;arena.flying=false;arena.set_physics_process(false);arena.walker.collision_layer=2;arena.walker.collision_mask=0;overlay.hide();status.text=body.name+" · WASD drive · Space brake · E exit · F2 setup · C view";return
	status.text="Move closer to a vehicle to enter"

func restore_vehicle_collision(body: PhysicsBody3D) -> void:
	# Allow the teleported capsule's new transform to reach the physics server first.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(body) and driving!=body:
		body.remove_collision_exception_with(arena.walker);arena.walker.remove_collision_exception_with(body)

func _input(event: InputEvent) -> void:
	if arena.shots_running: return
	if menu and menu.opened: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_Q and not driving: select_weapon(selected+1)
		if event.keycode==KEY_J:
			for body in vehicles:
				if body.has_method("set_controls"):
					body.global_transform=Transform3D(Basis.IDENTITY,Vector3(-65,2,4));body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO
					if not driving: arena.walker.position=Vector3(-61,1,4)
		if event.keycode==KEY_H:
			for body in vehicles:
				if body.has_method("toggle_inspection"): body.toggle_inspection()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		if driving and driving.has_method("fire_cannon"): driving.fire_cannon()
		else: use_weapon()

func use_weapon() -> void:
	if cooldown>0 or driving or weapons.is_empty() or reloading: return
	var key=names[selected]
	arena.get_node("PracticeRange").alert_shot(arena.camera.global_position)
	if key in ammo:
		if ammo[key]<=0: status.text=key+" / EMPTY / R RELOAD";return
		ammo[key]-=1;shot_audio.stream=gun_sounds[key];shot_audio.play()
	if key=="Carbine":
		cooldown=.16;recoil=.04;shot_count+=1
		var range_node=arena.get_node("PracticeRange")
		range_node.plasma(arena.camera.global_position,-arena.camera.global_basis.z,25.0,false,arena.walker.get_rid())
		status.text="PLASMA / %d / R reload" % ammo[key]
		return
	var melee=names[selected] not in ["Carbine","Railgun"]
	cooldown=.55 if melee else (.16 if key=="Carbine" else .85);recoil=.04 if key=="Carbine" else .09;shot_count+=1
	var camera=arena.camera
	var reach=3.0 if key=="Spear" else 2.0
	var ray=PhysicsRayQueryParameters3D.create(camera.position,camera.position-camera.global_basis.z*(reach if melee else 250.0));ray.exclude=[arena.walker.get_rid()]
	var hit=arena.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		if hit.collider.has_method("take_hit"):
			var damage=25.0 if key=="Carbine" else (90.0 if key=="Railgun" else (70.0 if key=="Club" else 50.0))
			status.text=key+" / "+hit.collider.take_hit(damage,camera.global_position,hit.position)
		elif hit.collider.has_meta("target_hits"):
			var count=int(hit.collider.get_meta("target_hits"))+1;hit.collider.set_meta("target_hits",count);status.text=names[selected]+" / TARGET HIT "+str(count)
		else: status.text=names[selected]+" / surface hit"
	else: status.text=names[selected]+" / miss"
	if key in ammo: status.text+=" / %d / R reload" % ammo[key]

func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta);recoil=move_toward(recoil,0,delta*.3)
	if holder: holder.position.z=-.5+recoil
	if not names.is_empty() and names[selected]=="Carbine" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not (menu and menu.opened): use_weapon()

func _physics_process(delta: float) -> void:
	if arena.shots_running: return
	for body in vehicles:
		if body.has_method("set_controls"):
			body.controlled=body==driving and not gunning and not menu.opened
			if body==driving and not gunning and not menu.opened: body.driver_controls(Input.is_physical_key_pressed(KEY_W),Input.is_physical_key_pressed(KEY_S),Input.is_physical_key_pressed(KEY_SPACE),float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D)))
			else: body.balanced_braking=false;body.set_controls(0,0,true)
			continue
		var active=body==driving and not menu.opened
		var tracks=Vector2.ZERO
		if active:
			if Input.is_physical_key_pressed(KEY_W): tracks=Vector2(1,1)
			elif Input.is_physical_key_pressed(KEY_S): tracks=Vector2(-1,-1)
			elif Input.is_physical_key_pressed(KEY_A): tracks=Vector2(-1,1)
			elif Input.is_physical_key_pressed(KEY_D): tracks=Vector2(1,-1)
		body.drive_step(delta,tracks.x,tracks.y,not active or Input.is_physical_key_pressed(KEY_SPACE))
		if body==driving: speed=body.velocity.dot(-body.global_basis.z)
	if driving:
		update_vehicle_camera(delta)

