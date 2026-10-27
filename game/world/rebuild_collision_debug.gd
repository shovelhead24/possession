extends Node3D
## Live Shape3D wireframes; never infer collision from visible render meshes.
var arena: Node3D
var enabled := false
var hud_hidden := false
var overlays := {}
var queued: Array=[]
var queued_ids := {}
var buttons: Array[CheckBox]=[]
var hud_items: Array[CanvasItem]=[]
var clock := 0.0
var fps_clock := 0.0
var fps_label: Label
var materials: Array[StandardMaterial3D]=[]
func fps_text() -> String:
	return "%d FPS" % Engine.get_frames_per_second()+(" | "+arena.ring_position_text() if arena.has_method("ring_position_text") else "")
func setup(owner_arena: Node3D) -> void:
	arena=owner_arena
	for color in [Color(.15,.9,1,.8),Color(1,.72,.12,.9),Color(1,.25,.65,.9)]:
		var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=color;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.no_depth_test=true
		materials.append(material)
	var layer := CanvasLayer.new();layer.layer=4;add_child(layer)
	fps_label=Label.new();fps_label.position=Vector2(16,16);fps_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fps_label.add_theme_font_size_override("font_size",18);fps_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	fps_label.add_theme_constant_override("shadow_offset_x",1);fps_label.add_theme_constant_override("shadow_offset_y",1)
	layer.add_child(fps_label);fps_label.hide()
	set_process(false)
func add_toggle(parent: Control) -> CheckBox:
	var toggle := CheckBox.new();toggle.text="Loaded collision wireframe";toggle.focus_mode=Control.FOCUS_NONE
	toggle.tooltip_text="Actual loaded physics shapes: cyan terrain, gold scenery, pink dynamic bodies. Updates as collision streams. Diagnostic display can reduce FPS."
	parent.add_child(toggle);toggle.button_pressed=enabled;toggle.toggled.connect(set_enabled);buttons.append(toggle);return toggle
func set_enabled(value: bool) -> void:
	enabled=value
	for button in buttons: button.set_pressed_no_signal(value)
	set_process(value or hud_hidden);clock=0
	if not value:
		for entry in overlays.values(): entry.visual.free()
		overlays.clear();queued.clear();queued_ids.clear()
func toggle_hud() -> void:
	hud_hidden=not hud_hidden;set_process(enabled or hud_hidden);fps_clock=0
	fps_label.visible=hud_hidden;fps_label.text=fps_text()
	if hud_items.is_empty():
		hud_items.append(arena.hud)
		if arena.weapons:
			hud_items.append(arena.weapons.ammo_label)
		# Floating editor instructions are HUD; controls inside menus remain readable.
		for item in arena.editor.layer.get_child(0).get_children():
			if item is Label: hud_items.append(item)
	for item in hud_items:
		if is_instance_valid(item): item.self_modulate.a=0.0 if hud_hidden else 1.0
	if arena.get("aliens"):
		for unit in arena.aliens.enemies: unit.label.visible=not hud_hidden and not unit.dead
func scan() -> void:
	var live := {}
	for node in arena.find_children("*","CollisionShape3D",true,false):
		var body := node.get_parent() as CollisionObject3D
		if not body or body is Area3D or body.collision_layer==0 or node.disabled or not node.shape or node.is_queued_for_deletion() or body.is_queued_for_deletion(): continue
		var id: int=node.get_instance_id();live[id]=true
		if overlays.has(id) and overlays[id].shape!=node.shape:
			overlays[id].visual.free();overlays.erase(id)
		if not overlays.has(id) and not queued_ids.has(id): queued.append(node);queued_ids[id]=true
	for id in overlays.keys():
		if not live.has(id): overlays[id].visual.free();overlays.erase(id)
static func wire_mesh(shape: Shape3D) -> ArrayMesh:
	var source := shape.get_debug_mesh();var mesh := ArrayMesh.new()
	# Godot includes filled triangle surfaces as well as diagnostic lines.
	for surface in source.get_surface_count():
		if source.surface_get_primitive_type(surface)==Mesh.PRIMITIVE_LINES:
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,source.surface_get_arrays(surface))
	return mesh
func build_pending() -> void:
	var began := Time.get_ticks_usec()
	for i in mini(4,queued.size()):
		var node: Variant=queued.pop_front()
		if not is_instance_valid(node): continue
		var id: int=node.get_instance_id();queued_ids.erase(id)
		var body := node.get_parent() as CollisionObject3D
		if not body or node.disabled or not node.shape or body.collision_layer==0 or body.is_queued_for_deletion(): continue
		var visual := MeshInstance3D.new();visual.mesh=wire_mesh(node.shape);visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		visual.material_override=materials[2 if body is RigidBody3D or body is CharacterBody3D else (0 if body.collision_layer&1 else 1)]
		add_child(visual);overlays[id]={"source":node,"shape":node.shape,"visual":visual}
		if Time.get_ticks_usec()-began>4000: break
func _process(delta: float) -> void:
	fps_clock-=delta
	if fps_clock<=0:
		fps_clock=.25;fps_label.text=fps_text();fps_label.visible=hud_hidden and arena.loading.dismissed
	if not enabled: return
	clock-=delta
	if clock<=0: clock=.25;scan()
	build_pending()
	for entry in overlays.values():
		var source: Variant=entry.source
		if not is_instance_valid(source): entry.visual.hide();continue
		var body := source.get_parent() as CollisionObject3D
		entry.visual.visible=not source.disabled and body!=null and body.collision_layer!=0 and not source.is_queued_for_deletion() and not body.is_queued_for_deletion()
		entry.visual.global_transform=source.get_global_transform_interpolated()
