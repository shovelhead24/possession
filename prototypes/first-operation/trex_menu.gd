extends CanvasLayer

var arena: Node3D
var opened := false
var controlled := false
var panel: PanelContainer
var hud: Label
var animation: OptionButton
var behavior: OptionButton
var takeover: Button
var diamond: Node3D
var distance := 18.0
var height := 8.0
var fov := 75.0
var orbit := 0.0
var pitch := .2
var saved_camera := Transform3D.IDENTITY
var saved_fov := 65.0
var saved_mode := 0
var saved_overlay := true
var saved_kit_physics := true
var simulation_time := 0.0
var controlled_actor: Node
var indicators_visible := false
var indicators_button: Button
var hud_visible := false
var damage_visible := false
var hud_button: Button
var damage_button: Button
var selected_rex := 0

func rex() -> Node:
	var manager=arena.get_node_or_null("PracticeRange")
	if manager and manager.get("tyrants"):
		var alive=[]
		for actor in manager.tyrants:
			if is_instance_valid(actor): alive.append(actor)
		if not alive.is_empty(): return alive[mini(selected_rex,alive.size()-1)]
	return manager.trex if manager and is_instance_valid(manager.trex) else null

func blocks_player() -> bool: return opened or controlled

func _ready() -> void:
	arena=get_parent();layer=30;process_mode=Node.PROCESS_MODE_ALWAYS
	panel=PanelContainer.new();panel.position=Vector2(24,24);panel.custom_minimum_size=Vector2(480,480);add_child(panel)
	var style=StyleBoxFlat.new();style.bg_color=Color(.045,.055,.065,.98)
	style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=14;style.content_margin_bottom=14;panel.add_theme_stylebox_override("panel",style)
	var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(460,600);panel.add_child(scroll)
	var box=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",6);scroll.add_child(box)
	var title=Label.new();title.text="REXY / CONTROLS · 6";title.add_theme_font_size_override("font_size",24);box.add_child(title)
	var hint=Label.new();hint.text="6 or Esc closes · Available everywhere\nWASD move · Mouse orbit · Left click / Space bite\nBites keep the up → left → right → finisher cycle";box.add_child(hint)
	var selector=OptionButton.new();box.add_child(selector)
	for i in 4: selector.add_item("Rexy %d" % (i+1))
	selector.item_selected.connect(func(index):
		if controlled: set_control(false)
		selected_rex=index)
	animation=OptionButton.new();box.add_child(animation)
	for label in ["Live behaviour animation","Full imported take","Walk excerpt","Rest / feet planted","Toss up — preview","Toss left — preview","Toss right — preview","Slam / stomp / eat — preview"]: animation.add_item(label)
	animation.item_selected.connect(func(index):
		var actor=rex()
		if actor: actor.set_preview(index))
	behavior=OptionButton.new();box.add_child(behavior)
	for label in ["Automatic: patrol + hunt","Patrol only","Hunt: hold if no target","Hold position"]: behavior.add_item(label)
	behavior.item_selected.connect(func(index):
		if controlled: set_control(false)
		var actor=rex()
		if actor: actor.set_preview(0);actor.behavior_mode=index;animation.select(0))
	takeover=Button.new();takeover.text="Take control of Rexy";box.add_child(takeover);takeover.pressed.connect(func(): set_control(not controlled))
	indicators_button=Button.new();indicators_button.text="Hide combat indicators";box.add_child(indicators_button)
	indicators_button.pressed.connect(func(): set_indicators(not indicators_visible))
	get_tree().node_added.connect(func(node):
		if node.is_in_group("combat_viewcones"): node.set_deferred("visible",indicators_visible)
		if node is Label or node is Label3D: register_text.call_deferred(node))
	hud_button=Button.new();hud_button.text="Show HUD / world text";box.add_child(hud_button)
	hud_button.pressed.connect(func(): hud_visible=not hud_visible;hud_button.text="Hide HUD / world text" if hud_visible else "Show HUD / world text";apply_text_visibility())
	damage_button=Button.new();damage_button.text="Show enemy damage / health";box.add_child(damage_button)
	damage_button.pressed.connect(func(): damage_visible=not damage_visible;damage_button.text="Hide enemy damage / health" if damage_visible else "Show enemy damage / health";apply_text_visibility())
	add_slider(box,"Camera distance",6,40,.5,distance,func(v): distance=v)
	add_slider(box,"Camera height",2,18,.25,height,func(v): height=v)
	add_slider(box,"Field of view",50,100,1,fov,func(v): fov=v)
	var close=Button.new();close.text="Return to game";box.add_child(close);close.pressed.connect(func(): set_open(false))
	panel.hide()
	hud=Label.new();hud.position=Vector2(24,650);hud.add_theme_color_override("font_shadow_color",Color.BLACK);hud.add_theme_constant_override("shadow_offset_x",2);hud.add_theme_constant_override("shadow_offset_y",2);add_child(hud)
	diamond=Node3D.new();arena.add_child(diamond)
	for sign in [-1,1]:
		var mesh=MeshInstance3D.new();var cone=CylinderMesh.new();cone.radial_segments=4;cone.top_radius=0;cone.bottom_radius=.35;cone.height=.6;mesh.mesh=cone;mesh.position.y=sign*.3
		if sign<0: mesh.rotation.z=PI
		var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(.25,1,.35);mesh.material_override=mat;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;diamond.add_child(mesh)
	diamond.hide()
	for label in arena.find_children("*","Label",true,false)+arena.find_children("*","Label3D",true,false): register_text(label)
	set_indicators(false);apply_text_visibility()

func register_text(node: Node) -> void:
	if not is_instance_valid(node): return
	# Keep actual menu controls legible. Everything else is opt-in overlay text.
	var ancestor=node.get_parent()
	while ancestor and ancestor!=arena:
		if ancestor is PanelContainer or ancestor is Panel: return
		ancestor=ancestor.get_parent()
	var damage=node is Label3D and (node.get_parent().get("health_label")==node or node.get_parent().get("label")==node)
	node.add_to_group("enemy_damage_text" if damage else "optional_hud_text")
	node.visible=damage_visible if damage else hud_visible

func apply_text_visibility() -> void:
	for label in get_tree().get_nodes_in_group("optional_hud_text"): label.visible=hud_visible
	for label in get_tree().get_nodes_in_group("enemy_damage_text"):
		label.visible=damage_visible and label.get_parent().get("dead")!=true

func toggle_pause() -> void:
	get_tree().paused=not get_tree().paused
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if get_tree().paused or opened else Input.MOUSE_MODE_CAPTURED

func set_indicators(value: bool) -> void:
	indicators_visible=value
	indicators_button.text="Hide combat indicators / patrol paths" if value else "Show combat indicators / patrol paths"
	for cone in get_tree().get_nodes_in_group("combat_viewcones"): cone.visible=value
	for actor in get_tree().get_nodes_in_group("tyrants"): actor.debug_indicators=value;actor.bite_debug.visible=value and actor.bite_time>0
	if not value: diamond.hide()

func _input(event: InputEvent) -> void:
	if handle_input(event): get_viewport().set_input_as_handled()

func add_slider(box: VBoxContainer,label: String,low: float,high: float,step: float,value: float,change: Callable) -> void:
	var text=Label.new();text.text=label+" · "+str(value);box.add_child(text)
	var slider=HSlider.new();slider.min_value=low;slider.max_value=high;slider.step=step;slider.value=value;slider.custom_minimum_size=Vector2(440,24);box.add_child(slider)
	slider.value_changed.connect(func(v): text.text=label+" · "+str(v);change.call(v))

func set_open(value: bool) -> void:
	opened=value;panel.visible=value
	if value and arena.kit and arena.kit.menu: arena.kit.menu.set_open(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value or get_tree().paused else Input.MOUSE_MODE_CAPTURED

func set_control(value: bool) -> void:
	var actor=rex()
	if value and not actor: return
	if value==controlled: return
	controlled=value
	if value:
		controlled_actor=actor
		saved_camera=arena.camera.global_transform;saved_fov=arena.camera.fov;saved_mode=actor.behavior_mode
		actor.set_preview(0);animation.select(0);actor.behavior_mode=4;actor.cached_prey=null
		orbit=actor.rotation.y;pitch=.2
		if arena.kit:
			saved_overlay=arena.kit.overlay.visible;saved_kit_physics=arena.kit.is_physics_processing();arena.kit.overlay.hide();arena.kit.set_physics_process(false)
			for car in arena.kit.vehicles: car.controlled=false;car.set_controls(0,0,true)
		set_open(false)
	else:
		controlled_actor=null
		if actor: actor.set_preview(0);actor.behavior_mode=saved_mode;actor.manual_move=Vector3.ZERO;actor.manual_bite=false
		arena.camera.global_transform=saved_camera;arena.camera.fov=saved_fov
		if arena.kit: arena.kit.overlay.visible=saved_overlay;arena.kit.set_physics_process(saved_kit_physics)
	takeover.text="Release Rexy control" if controlled else "Take control of Rexy"

func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_P: toggle_pause();return true
		if event.keycode in [KEY_6,KEY_KP_6]: set_open(not opened);return true
		if event.keycode==KEY_ESCAPE and opened: set_open(false);return true
	if opened or get_tree().paused: return false
	if not controlled: return false
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		orbit-=event.relative.x*.003;pitch=clampf(pitch-event.relative.y*.003,-.25,1.0)
	if (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE):
		var actor=rex()
		if actor: actor.manual_bite=true
	return true

func _physics_process(_delta: float) -> void:
	if not controlled: return
	var actor=rex()
	if not actor or actor!=controlled_actor: set_control(false);return
	var input=Vector3.ZERO
	if not opened and actor.preview_mode==0:
		var forward=-arena.camera.global_basis.z;forward.y=0;forward=forward.normalized()
		var right=arena.camera.global_basis.x;right.y=0;right=right.normalized()
		input=forward*(float(Input.is_physical_key_pressed(KEY_W))-float(Input.is_physical_key_pressed(KEY_S)))+right*(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)))
	actor.manual_move=input.limit_length(1.0)
	if opened: actor.manual_bite=false

func _process(delta: float) -> void:
	apply_text_visibility()
	for predator in get_tree().get_nodes_in_group("tyrants"):
		predator.debug_indicators=indicators_visible
		if not indicators_visible: predator.bite_debug.hide()
	if not get_tree().paused: simulation_time+=delta
	var clock_text="SIM %02d:%05.2f %s · P pause/resume" % [int(simulation_time/60),fmod(simulation_time,60.0),"PAUSED" if get_tree().paused else "RUNNING"]
	var actor=rex()
	hud.position.y=maxf(24,get_viewport().get_visible_rect().size.y-85)
	if not actor: hud.text=clock_text+"\nREXY unavailable / respawning · 6 controls";diamond.hide();return
	var selected=actor.bite_target if is_instance_valid(actor.bite_target) else actor.cached_prey
	actor.debug_indicators=indicators_visible
	if not indicators_visible: actor.bite_debug.hide()
	var target_label="none"
	if is_instance_valid(selected):
		target_label="Player" if selected==arena.walker else str(selected.name)
		if selected.get("elite")!=null: target_label="Elite" if selected.elite else "Grunt"
	hud.text=clock_text+"\nREXY · %s · frame %d\n%s · target: %s · 6 controls" % [actor.diagnostic_animation(),actor.diagnostic_frame(),"MANUAL" if controlled else ["AUTO","PATROL","HUNT","HOLD","MANUAL"][actor.behavior_mode],target_label]
	diamond.visible=indicators_visible and is_instance_valid(selected)
	if diamond.visible: diamond.global_position=selected.global_position+Vector3.UP*3.2;diamond.rotate_y(delta)
	if controlled:
		var focus=actor.global_position+Vector3.UP*4
		var desired=focus+Basis(Vector3.UP,orbit)*Vector3(0,height+sin(pitch)*distance,cos(pitch)*distance)
		var ray=PhysicsRayQueryParameters3D.create(focus,desired);ray.exclude=[actor.get_rid(),arena.walker.get_rid()]
		var hit=arena.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): desired=hit.position+hit.normal*.5
		arena.camera.global_position=arena.camera.global_position.lerp(desired,1.0-exp(-delta*8))
		arena.camera.look_at(focus);arena.camera.fov=fov
