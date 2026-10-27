extends Node
## Camera-only tour: preserve the playable scene while inspecting distant scenery.
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var review: Node
var picker: OptionButton
var status: Label
var entries: Array=[]
var active=false
var camera: Camera3D
var original: Camera3D
var saved: Dictionary={}
var suspended: Array=[]
var bodies: Array=[]
var player_start: Node

func setup(owner_arena: Node3D, owner_review: Node, column: VBoxContainer):
	arena=owner_arena;review=owner_review
	picker=OptionButton.new();column.add_child(picker)
	entries=[{"name":"Local landscape / 250 m", "kind":"local", "height":250.0}, {"name":"Above the mist / 80 m", "kind":"local", "height":80.0}, {"name":"Trial pool overview", "kind":"water"}]
	for i in arena.backdrop._patch_names.size():
		entries.append({"name":str(arena.backdrop._patch_names[i]).replace("_"," ").capitalize()+" / aerial", "kind":"patch", "index":i})
	entries.append({"name":"Distant flat vehicle test pad / 600 m", "kind":"test_pad"})
	for entry in entries:picker.add_item(entry.name)
	var row=HBoxContainer.new();column.add_child(row)
	for caption in ["Previous", "Visit viewpoint", "Next", "Return to player"]:
		var button=Button.new();button.text=caption;row.add_child(button)
		match caption:
			"Previous":button.pressed.connect(func():visit(posmod(picker.selected-1,entries.size())))
			"Next":button.pressed.connect(func():visit((picker.selected+1)%entries.size()))
			"Visit viewpoint":button.pressed.connect(func():visit(picker.selected))
			"Return to player":button.pressed.connect(finish)
	status=Label.new();status.text="Choose a view to start the camera tour.";column.add_child(status)
	var note=Label.new();note.text="Right mouse: hold to look around. Ctrl+F4: viewpoints menu.\nBackspace: return to your player or vehicle.\nUse the spawn controls to land on terrain anywhere around the ring.";column.add_child(note)
	player_start=preload("res://world/performance_player_start.gd").new();add_child(player_start);player_start.setup(arena,self,column)
	var coordinates=HBoxContainer.new();column.add_child(coordinates)
	var arc=SpinBox.new();arc.min_value=-1500000;arc.max_value=1500000;arc.step=1;arc.prefix="Arc m";arc.custom_minimum_size.x=180;coordinates.add_child(arc)
	var lateral=SpinBox.new();lateral.min_value=-24900;lateral.max_value=24900;lateral.step=1;lateral.prefix="Lateral m";lateral.custom_minimum_size.x=180;coordinates.add_child(lateral)
	var jump=Button.new();jump.text="View coordinates";coordinates.add_child(jump)
	jump.pressed.connect(func():visit_coordinates(arc.value,lateral.value))
	var drive_pad=Button.new();drive_pad.text="Drive Warthog on distant flat test pad";column.add_child(drive_pad);drive_pad.pressed.connect(drive_test_pad)

func drive_test_pad():
	if active:finish()
	if arena.editor.opened:arena.editor.toggle()
	var point: Vector3=arena.ring_landing.test_pad()
	await get_tree().physics_frame
	point=arena.ring_landing.test_pads[false]
	arena.on_foot.deactivate();arena.vehicle_kit.select_vehicle(arena.vehicle_kit.original_car)
	var car=arena.vehicle_kit.car
	car.global_transform=Transform3D(Ring.tangent_basis(point,0),point+Ring.up_at(point)*1.5)
	car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO;car.reset_physics_interpolation()
	car.stream_velocity=Vector3.ZERO;car.stream_angular=Vector3.ZERO;car.set_stream_ready(true)
	arena.vehicle_kit.driving=true;arena.vehicle_kit.driver_look=Vector2.ZERO
	review.dialog.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func visit_coordinates(arc: float, lateral: float):
	begin()
	var height: float=arena.backdrop._far_terrain_h(arc,lateral)
	var target=Ring.point(arc,height,lateral)
	camera.global_position=Ring.point(arc,height+5000.0,lateral)
	camera.look_at(target,Ring.spinward_at(target))
	status.text="View: arc %.0f m / lateral %.0f m" % [arc,lateral]
	review.dialog.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func fly_from_view():
	var view=arena.camera.global_transform
	finish()
	if not arena.editor.opened:arena.editor.toggle()
	arena.camera.global_transform=view
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func begin():
	if active:return
	original=arena.camera
	saved={"diagnostic":arena.diagnostic,"driving":arena.vehicle_kit.driving,"mouse":Input.mouse_mode,"backdrop_camera":arena.backdrop._cam}
	saved.editor_layer_visible=arena.editor.layer.visible
	arena.editor.finish_paint();arena.editor.finish_stroke();arena.editor.looking=false
	arena.editor.layer.hide();arena.editor.cursor.hide();arena.editor.guide.hide()
	for key in ["on_foot","controller","weapons","aliens","actors","streamer","editor","forge","vehicle_kit"]:
		var node=arena.get(key)
		if node is Node:
			suspended.append([node,node.process_mode]);node.process_mode=Node.PROCESS_MODE_DISABLED
	freeze_bodies(arena)
	camera=Camera3D.new();camera.fov=original.fov;camera.near=original.near;camera.far=original.far;camera.cull_mask=original.cull_mask
	arena.add_child(camera);camera.global_transform=original.global_transform
	arena.camera=camera;arena.backdrop._cam=camera;camera.make_current()
	review.valley_mist.reparent(camera,false)
	arena.diagnostic=true;arena.vehicle_kit.driving=false;active=true

func freeze_bodies(node: Node):
	if (node is RigidBody3D or node is CharacterBody3D) and node.process_mode!=Node.PROCESS_MODE_DISABLED:
		suspended.append([node,node.process_mode]);node.process_mode=Node.PROCESS_MODE_DISABLED
	if node is RigidBody3D:
		bodies.append([node,node.freeze,node.linear_velocity,node.angular_velocity]);node.freeze=true
	for child in node.get_children():freeze_bodies(child)

func visit(index: int):
	if index<0 or index>=entries.size():return
	begin();picker.select(index)
	await arena.ring_landing.initialize()
	if not active:return
	var entry: Dictionary=entries[index]
	var at=Ring.coordinates(original.global_position)
	var target: Vector3
	var position: Vector3
	match entry.kind:
		"showcase":
			var view=arena.showcases.viewpoint(entry.index)
			target=view.target;position=view.eye
		"test_pad":
			target=arena.ring_landing.test_pad()
			position=target+Ring.up_at(target)*100.0-Ring.spinward_at(target)*80.0
		"local":
			var ground=landscape_height(at.x,at.z,at.y)
			target=Ring.point(at.x,ground,at.z)
			var eye_ground=landscape_height(at.x-120.0,at.z+100.0,ground)
			position=Ring.point(at.x-120.0,maxf(ground,eye_ground)+entry.height,at.z+100.0)
		"water":
			var lake=review.water
			target=Ring.point(lake.centre.x,lake.base_level,lake.centre.y)
			position=Ring.point(lake.centre.x-160.0,lake.base_level+150.0,lake.centre.y+100.0)
		"patch":
			var rect: Vector4=arena.backdrop._patch_rects[entry.index]
			var ground: float=arena.backdrop._patch_height(entry.index,rect.x,rect.y)
			target=Ring.point(rect.x,ground,rect.y)
			position=Ring.point(rect.x-rect.z*.35,ground+maxf(3000.0,rect.z*.5),rect.y+rect.w*.25)
	if not position.is_finite() or not target.is_finite():
		status.text="View unavailable: terrain height could not be resolved."
		finish();review.open_review();return
	camera.global_position=position;camera.look_at(target,Ring.up_at(position))
	status.text="Viewing: "+entry.name
	review.dialog.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	print("VIEWPOINT_APPLIED ",entry.name," ",JSON.stringify(arena.ring_position_data()))

func landscape_height(arc: float, lateral: float, fallback: float) -> float:
	# The authored home heightfield returns NAN outside its footprint.
	# Nearby views must work from every region, including after an origin shift.
	var height: float
	if arena.streamer.world_bounds.has_point(Vector2(arc,lateral)):
		height=arena.source.surface_height(Vector2(arc,lateral))
	else:
		height=arena.backdrop._far_terrain_h(arc,lateral)
	if not is_finite(height):height=fallback if is_finite(fallback) else 0.0
	if arena.ring_landing.initialized:
		# The distant rendered triangles and local SDF edits may differ from the
		# sampled DEM. Keep the camera above the actual visible/pickable surface.
		var ray=PhysicsRayQueryParameters3D.create(Ring.point(arc,height+20000.0,lateral),Ring.point(arc,height-20000.0,lateral),129)
		ray.exclude=[arena.on_foot.get_rid()]
		var hit=arena.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():height=maxf(height,Ring.coordinates(hit.position).y)
	return height

func finish():
	player_start.operation=""
	arena.on_foot.notice=""
	if not active:return
	review.valley_mist.reparent(original,false)
	arena.camera=original;arena.backdrop._cam=saved.backdrop_camera;original.make_current()
	arena.diagnostic=saved.diagnostic;arena.vehicle_kit.driving=saved.driving
	arena.editor.layer.visible=saved.editor_layer_visible
	for record in bodies:
		if is_instance_valid(record[0]):
			record[0].freeze=record[1];record[0].linear_velocity=record[2];record[0].angular_velocity=record[3]
	for record in suspended:
		if is_instance_valid(record[0]):record[0].process_mode=record[1]
	bodies.clear();suspended.clear();camera.queue_free();active=false
	status.text="Returned to player.";review.dialog.hide();Input.mouse_mode=saved.mouse

func handle_input(event: InputEvent) -> bool:
	if player_start.handle_input(event):return true
	if event is InputEventKey and event.pressed and not event.echo:
		if active and event.keycode==KEY_F1:
			fly_from_view()
			return true
		if event.keycode==KEY_F4 and event.ctrl_pressed:
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;review.open_review();review.tabs.current_tab=4;return true
		if active and event.keycode==KEY_BACKSPACE:finish();return true
		if active and event.keycode==KEY_ESCAPE:
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;review.open_review();review.tabs.current_tab=4;return true
	if not active or review.dialog.visible:return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		camera.global_basis=Basis(Ring.up_at(camera.global_position),-event.relative.x*.003)*camera.global_basis
		var pitch=-event.relative.y*.003
		var elevation=asin(clampf((-camera.global_basis.z).dot(Ring.up_at(camera.global_position)),-1,1))
		camera.rotate_object_local(Vector3.RIGHT,clampf(elevation+pitch,-1.5,1.5)-elevation)
	return true
