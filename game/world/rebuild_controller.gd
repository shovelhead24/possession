extends Node
# Restore early-build DS4Windows polling: button events are not always delivered.
const Foot=preload("res://world/tree_on_foot.gd")
var arena: Node3D
var device := -1
var source_mode := "auto"
var connections_changed := 0
var device_name := "No controller"
var previous := {}
var move := Vector2.ZERO
var look := Vector2.ZERO
var right_trigger := 0.0
var left_trigger := 0.0
var buttons := {}
var using_controller := false
var fire_armed := false
var scan_clock := 0.0
func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;process_physics_priority=-20;scan_devices()
static func preferred(devices: Array, mode: String="auto", current: int=-1) -> int:
	if mode=="auto":
		for entry in devices:
			if entry.id==current: return current
	if mode=="native":
		for entry in devices:
			var name=str(entry.name).to_lower()
			if "dualsense" in name or "wireless controller" in name or "ps5" in name: return entry.id
		return -1
	for entry in devices:
		var name=str(entry.name).to_lower()
		if "xinput" in name or "xbox" in name: return entry.id
	return devices[0].id if mode=="auto" and not devices.is_empty() else -1
func scan_devices() -> void:
	var devices=[]
	for id in Input.get_connected_joypads(): devices.append({"id":id,"name":Input.get_joy_name(id)})
	var next=preferred(devices,source_mode,device)
	if next==device: return
	if arena.weapons: arena.weapons.trigger_held=false;arena.weapons.aim_assist.reset_tracking()
	connections_changed+=1
	device=next;previous={};fire_armed=false;using_controller=false
	arena.on_foot.aim_device=-1
	device_name=Input.get_joy_name(device) if device>=0 else "No controller"
	print("REBUILD_CONTROLLER: ",device_name," / device ",device," / polling")
func intercept(event: InputEvent) -> bool:
	# Consume both duplicate device streams; gameplay actions come only from polling.
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		# Let focused dialog controls receive pad navigation and confirmation.
		if _ui_has_focus(): return false
		return true
	if event is InputEventMouseMotion and event.relative.length_squared()>0 or event is InputEventMouseButton or event is InputEventKey:
		if using_controller:
			using_controller=false;arena.on_foot.aim_device=-1;arena.weapons.trigger_held=false;arena.weapons.aim_assist.reset_tracking()
	return false
func _physics_process(delta: float) -> void:
	scan_clock-=delta
	if scan_clock<=0: scan_clock=1;scan_devices()
	if device<0: return
	var state={"buttons":{},"move":Foot.deadzone(Vector2(Input.get_joy_axis(device,JOY_AXIS_LEFT_X),Input.get_joy_axis(device,JOY_AXIS_LEFT_Y))),"look":Foot.deadzone(Vector2(Input.get_joy_axis(device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y))),"rt":Input.get_joy_axis(device,JOY_AXIS_TRIGGER_RIGHT),"lt":Input.get_joy_axis(device,JOY_AXIS_TRIGGER_LEFT)}
	for button in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_BACK,JOY_BUTTON_START]: state.buttons[button]=Input.is_joy_button_pressed(device,button)
	step(state,delta,DisplayServer.window_is_focused())
func key(code: int) -> void:
	var event=InputEventKey.new();event.keycode=code;event.pressed=true
	arena.on_foot.handle_input(event)

func _ui_has_focus() -> bool:
	var focused: Control=arena.get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and focused.is_visible_in_tree(): return true
	# Popup dialogs can be visible before their first control has GUI focus.
	for modal in get_tree().get_nodes_in_group("controller_modal_ui"):
		if modal is Window and modal.visible: return true
	return false
func step(state: Dictionary, delta: float, focused: bool=true) -> void:
	var pressed={}
	buttons=state.buttons;move=state.move;look=state.look;right_trigger=state.rt;left_trigger=state.lt
	for button in buttons:
		if buttons[button] and not previous.get(button,false): pressed[button]=true
	var intent=not pressed.is_empty() or (move.length()>.05 and move.distance_to(previous.get("move",Vector2.ZERO))>.02) or (look.length()>.05 and look.distance_to(previous.get("look",Vector2.ZERO))>.02) or (right_trigger>.25 and previous.get("rt",0.0)<=.25) or (left_trigger>.25 and previous.get("lt",0.0)<=.25)
	previous=buttons.duplicate();previous.move=move;previous.look=look;previous.rt=right_trigger;previous.lt=left_trigger
	if not focused or not arena.ready_to_play:
		fire_armed=false
		if using_controller: arena.weapons.trigger_held=false
		using_controller=false;arena.on_foot.aim_device=-1
		return
	if _ui_has_focus():
		# Controller movement must not capture the pointer while a dialog is open.
		fire_armed=false
		if using_controller: arena.weapons.trigger_held=false
		using_controller=false;arena.on_foot.aim_device=-1
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		return
	if not arena.loading.dismissed:
		fire_armed=false
		if pressed.has(JOY_BUTTON_A) and arena.loading.ready_to_enter: arena.loading.close()
		return
	if arena.editor.opened or arena.vehicle_kit.menu.opened:
		fire_armed=false
		if using_controller: arena.weapons.trigger_held=false
		return
	if intent: using_controller=true;arena.on_foot.aim_device=device
	if not using_controller: return
	if pressed.has(JOY_BUTTON_START):
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		arena.weapons.trigger_held=false;fire_armed=false;return
	if pressed.has(JOY_BUTTON_BACK): arena.collision_debug.toggle_hud()
	if pressed.has(JOY_BUTTON_LEFT_SHOULDER):
		arena.throw_grenade()
		return
	if pressed.has(JOY_BUTTON_X):
		if arena.vehicle_kit.driving: key(KEY_E);fire_armed=false;return
		elif not arena.on_foot.active: key(KEY_E);fire_armed=false;return
		var near_car=false
		for car in arena.vehicle_kit.vehicles:
			if is_instance_valid(car) and car.global_position.distance_to(arena.on_foot.global_position)<=6: near_car=true;break
		if near_car: key(KEY_E);fire_armed=false;return
		arena.weapons.start_reload()
	if arena.vehicle_kit.driving:
		if look.length_squared()>.0025: arena.vehicle_kit.register_camera_input()
		var yaw=arena.vehicle_kit.driver_look.x-look.x*delta*2
		arena.vehicle_kit.driver_look.x=wrapf(yaw,-PI,PI) if arena.vehicle_kit.car.has_method("fire_cannon") else clampf(yaw,-1.6,1.6)
		arena.vehicle_kit.driver_look.y=clampf(arena.vehicle_kit.driver_look.y-look.y*delta*1.5,-.7,.5)
		fire_armed=false;return
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		arena.weapons.trigger_held=false;fire_armed=false
		if intent: Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		return
	if right_trigger<.15: fire_armed=true
	arena.weapons.trigger_held=fire_armed and right_trigger>.25
	if pressed.has(JOY_BUTTON_A): arena.on_foot.jump_queued=true
	if pressed.has(JOY_BUTTON_Y) and not arena.weapons.models.is_empty(): arena.weapons.select_weapon((arena.weapons.selected+1)%arena.weapons.models.size())
func drive(car: Node) -> void:
	if not DisplayServer.window_is_focused(): car.set_controls(0,0,true);return
	car.driver_controls(right_trigger>.15,buttons.get(JOY_BUTTON_B,false),left_trigger>.15,-move.x)
	if not car.balanced_braking:
		car.throttle=right_trigger if right_trigger>.15 else (-1.0 if buttons.get(JOY_BUTTON_B,false) and car.reverse_engaged else 0.0)
