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
var vehicles: Array[CharacterBody3D] = []
var driving: CharacterBody3D
var speed := 0.0
var status: Label
var shot_count := 0

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
	build_viewmodel()
	vehicle("Warthog",GAME+"halo_warthog/scene.gltf",Vector3(-17,1,9),6.0)
	vehicle("Altay",GAME+"altay_main_battle_tank_fbx.glb",Vector3(-29,1,9),9.0)
	for i in range(3):
		var target=StaticBody3D.new()
		target.position=Vector3(12+i*4,1.25,-18-i*6)
		target.set_meta("target_hits",0)
		var shape=CollisionShape3D.new();var cube=BoxShape3D.new();cube.size=Vector3(1.1,2.5,0.35);shape.shape=cube
		target.add_child(shape);arena.add_child(target)
		arena.box(Vector3.ZERO,cube.size,arena.material(Color(0.5,0.25,0.16)),target)
	var layer=CanvasLayer.new();add_child(layer)
	status=Label.new();status.position=Vector2(20,160);status.text="C weapon · Left mouse use · E enter/exit nearby vehicle\nRange targets stand to the right of the FOB";layer.add_child(status)
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
	if weapons.is_empty(): return
	selected=posmod(index,weapons.size())
	for i in range(weapons.size()): weapons[i].visible=i==selected
	if arms: arms.set_weapon_pose(names[selected].to_lower())
	if status: status.text=names[selected]+" · C cycle · Left mouse use · E interact"

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
	var body=CharacterBody3D.new();body.name=label;body.position=pos;body.floor_snap_length=1.0;body.floor_max_angle=deg_to_rad(50);body.add_child(model)
	var collision=CollisionShape3D.new();var shape=CapsuleShape3D.new();shape.radius=1.0;shape.height=maxf(2.1,length_m*.75);collision.shape=shape;collision.rotation.x=PI*.5;collision.position.y=1.0;body.add_child(collision)
	arena.add_child(body);vehicles.append(body)
	arena.label3(label+" / E",pos+Vector3(0,3.5,0),32)

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
			arena.walker.position=p;arena.walker.velocity=Vector3.ZERO;arena.walker.collision_layer=1;arena.walker.collision_mask=1;arena.set_physics_process(true);driving=null;overlay.show();return
		status.text="Exit obstructed";return
	for body in vehicles:
		if arena.walker.position.distance_to(body.position)<6:
			driving=body;speed=0;arena.flying=false;arena.set_physics_process(false);arena.walker.collision_layer=0;arena.walker.collision_mask=0;overlay.hide();status.text=body.name+" · WASD drive · Space brake · E exit";return
	status.text="Move closer to a vehicle to enter"

func _input(event: InputEvent) -> void:
	if arena.shots_running: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_C: select_weapon(selected+1)
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		use_weapon()

func use_weapon() -> void:
	if cooldown>0 or driving or weapons.is_empty(): return
	var melee=names[selected] not in ["Carbine","Railgun"]
	cooldown=.5 if melee else .2;recoil=.06;shot_count+=1
	var camera=arena.camera
	var ray=PhysicsRayQueryParameters3D.create(camera.position,camera.position-camera.global_basis.z*(2.2 if melee else 250.0));ray.exclude=[arena.walker.get_rid()]
	var hit=arena.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		if hit.collider.has_meta("target_hits"):
			var count=int(hit.collider.get_meta("target_hits"))+1;hit.collider.set_meta("target_hits",count);status.text=names[selected]+" / TARGET HIT "+str(count)
		else: status.text=names[selected]+" / surface hit"
	else: status.text=names[selected]+" / miss"

func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta);recoil=move_toward(recoil,0,delta*.3)
	if holder: holder.position.z=-.5+recoil

func _physics_process(delta: float) -> void:
	if arena.shots_running: return
	for body in vehicles:
		if body==driving:
			var throttle=float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S))
			speed=move_toward(speed,throttle*(16 if throttle>=0 else 7),delta*(16 if Input.is_physical_key_pressed(KEY_SPACE) else 5))
			if Input.is_physical_key_pressed(KEY_SPACE): speed=move_toward(speed,0,delta*35)
			var steer=float(Input.is_physical_key_pressed(KEY_A))-float(Input.is_physical_key_pressed(KEY_D))
			body.rotate_y(steer*delta*clampf(speed/6,-1,1))
			body.velocity.x=-body.basis.z.x*speed;body.velocity.z=-body.basis.z.z*speed
		else: body.velocity.x=0;body.velocity.z=0
		body.velocity.y-=22*delta;body.move_and_slide()
		if body.position.y < -35: body.position=Vector3(-17,1,9);body.velocity=Vector3.ZERO;speed=0
	if driving:
		arena.camera.position=driving.position+driving.basis.z*8+Vector3.UP*4
		arena.camera.look_at(driving.position+Vector3.UP*1.4)
