extends Node
## Restored workshop weapons, independent of the old arena/possession controller.
const CAPACITY := [30,5,100,80,100]
const INTERVAL := [.18,1.0,.12,.14,.12]
const DAMAGE := [25.0,120.0,14.0,18.0,14.0]
const REACH := [250.0,600.0,200.0,200.0,200.0]
const NAMES := ["Carbine","Railgun","Plasma Rifle","Doom Plasma Gun","Halo CE Plasma Rifle"]
const COLORS := [Color(.4,1,.5),Color(.5,.8,1),Color(.15,.7,1),Color(.15,.7,1),Color(.15,.7,1)]
var arena: Node3D
var initialized := false
var models: Array[Node3D]=[]
var arms: Node3D
var arms_rest_transform := Transform3D.IDENTITY
var holder: Node3D
var view: SubViewport
var container: SubViewportContainer
var ammo_label: Label
var crosshair: Control
var aim_assist=preload("res://world/weapon_aim.gd").new()
var aim_state: Dictionary={}
var aim_clock := 0.0
const BASE_SPREAD=[.08,.02,.35,.5,.3]
const MAX_SPREAD=[.35,.02,1.6,2.0,1.5]
var bloom=[0.0,0.0,0.0,0.0,0.0]
var spread_rng=RandomNumberGenerator.new()
var last_shot_aim := {}
var audio: AudioStreamPlayer
var sounds: Array[AudioStream]=[]
var selected := 0
var ammo := [30,5,100,80,100]
var cooldown := 0.0
var reload_time := 0.0
var trigger_held := false
var recoil := 0.0
var bob_phase := 0.0
var bob_amount := 0.0
var shots := 0
var last_hit := {}
var notice := ""
var notice_time := 0.0
var view_active := false
var redraw_frames := 0
var view_redraws := 0
var effects: Array=[]
var tracer: MeshInstance3D
var impacts: MultiMeshInstance3D
var presentation_enabled := true
var plasma: Node3D
var trace_usec := 0
var trace_count := 0

func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;process_priority=60;aim_assist.load_settings()
	build_overlay()
	var importer := preload("res://world/content_gallery.gd").new()
	arena.loading.log_event("Importing first-person arms")
	await get_tree().process_frame
	arms=importer.import_source(ProjectSettings.globalize_path("res://../assets/fp_arms.zip").simplify_path())
	if arms:
		stop_animations(arms);arms.set_script(preload("res://fp_arms_controller.gd"))
		arms.transform=Transform3D(Basis(Vector3(-.180993,0,.010583),Vector3(0,.1813025,0),Vector3(-.010583,0,-.180993)),Vector3(-.29,.19,.45));holder.add_child(arms)
		arms_rest_transform=arms.transform
	else: push_warning("Weapon arms archive unavailable")
	for index in NAMES.size():
		arena.loading.log_event("Importing "+NAMES[index]+" and preparing its firing sound")
		await get_tree().process_frame
		var name: String=["halo_-_carbine.zip","halo_railgun_redesigned.zip","halo_-_plasma_rifle.glb","doom-plasma.glb","halo-ce-plasma.glb"][index]
		var model: Node3D=importer.import_source(ProjectSettings.globalize_path("res://../assets/"+name).simplify_path())
		if not model:
			push_error("Weapon archive unavailable: "+name);importer.contact_debug.free();importer.free();get_tree().quit(1);return
		stop_animations(model)
		if index==0:
			model.transform=Transform3D(Basis(Vector3(.034928,-.001051,-.001979),Vector3(.001057,.034984,.000066),Vector3(-.001976,.000125,-.034944)),Vector3(-.257,.18,.31))
		elif index==1:
			model.transform=Transform3D(Basis(Vector3(0,0,.0035),Vector3(0,.0035,0),Vector3(.0035,0,0)),Vector3(-.25,.23,.29))
		elif index==2:
			model.rotation.y=PI;model.scale=Vector3.ONE*.065;model.position=Vector3(-.08,-.01,-.01)
		else:
			model.rotation.y=PI if index==3 else PI*.5
			var bounds: AABB=importer.model_bounds(model)
			model.scale=Vector3.ONE*(.60/maxf(bounds.size.z,.001))
			bounds=importer.model_bounds(model)
			model.position=Vector3(-.06,-.04,-.08)-bounds.get_center()
		if index==4: strip_ce_markers(model)
		holder.add_child(model);models.append(model)
	importer.contact_debug.free();importer.free()
	sounds=[load("res://plasma_rifle.mp3"),load("res://quake railgun sound effect.mp3"),AudioStreamWAV.load_from_file("res://effects/plasma/terminator-single.wav")]
	sounds.append(sounds[2]);sounds.append(sounds[2])
	audio=AudioStreamPlayer.new();audio.volume_db=-18;audio.max_polyphony=4;add_child(audio)
	build_effects()
	plasma=preload("res://world/plasma_billboards.gd").new();arena.add_child(plasma);plasma.setup(self)
	select_weapon(0);await plasma.warmup();initialized=true
	arena.loading.log_event("Weapons ready: Carbine / Railgun / Plasma Rifle / Doom / Halo CE · fire, switch, reload · editor-safe")

static func strip_ce_markers(root: Node3D) -> void:
	# The CE source includes blue attachment spheres and white direction cones.
	# Keep the textured weapon surfaces; leave the original imported asset intact.
	for instance in root.find_children("*","MeshInstance3D",true,false):
		var mesh := ArrayMesh.new()
		for surface in instance.mesh.get_surface_count():
			var material: Material=instance.get_active_material(surface)
			if material and material.resource_name.begins_with("wire_"): continue
			mesh.add_surface_from_arrays(instance.mesh.surface_get_primitive_type(surface),instance.mesh.surface_get_arrays(surface))
			mesh.surface_set_material(mesh.get_surface_count()-1,material)
		if mesh.get_surface_count()>0: instance.mesh=mesh

static func stop_animations(root: Node3D) -> void:
	for player in root.find_children("*","AnimationPlayer",true,false): player.stop()
	for mesh in root.find_children("*","GeometryInstance3D",true,false): mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_overlay() -> void:
	var layer := CanvasLayer.new();layer.layer=3;add_child(layer)
	container=SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(container)
	view=SubViewport.new();view.size=Vector2i(get_viewport().get_visible_rect().size);view.transparent_bg=true;view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_DISABLED;container.add_child(view)
	get_viewport().size_changed.connect(func(): redraw_frames=3)
	var camera := Camera3D.new();camera.near=.01;camera.far=10;camera.fov=65;view.add_child(camera);camera.make_current()
	var environment := WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.7;view.add_child(environment)
	var light := DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-35,0);light.shadow_enabled=false;view.add_child(light)
	holder=Node3D.new();holder.position=Vector3(.3,-.25,-.5);camera.add_child(holder)
	ammo_label=Label.new();ammo_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;ammo_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;layer.add_child(ammo_label)
	ammo_label.add_theme_font_size_override("font_size",20)
	crosshair=preload("res://world/weapon_reticle.gd").new();crosshair.modulate=Color(.15,.65,1);layer.add_child(crosshair)
	for label in [ammo_label]:
		label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",1)
	container.hide();ammo_label.hide();crosshair.hide()

func available() -> bool:
	if arena.get("aliens") and arena.aliens.defeated: return false
	return initialized and arena.ready_to_play and arena.on_foot and arena.on_foot.active and not arena.editor.opened and arena.loading.dismissed and not arena.vehicle_kit.menu.opened and arena.streamer.ready_at(arena.on_foot.global_position)

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: trigger_held=false
	if not available(): trigger_held=false;return false
	if event is InputEventJoypadMotion and event.axis==JOY_AXIS_TRIGGER_RIGHT:
		if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: trigger_held=false;return false
		if arena.on_foot.get("aim_device")!=null: arena.on_foot.aim_device=event.device
		trigger_held=event.axis_value>.25;return true
	if event is InputEventJoypadButton and event.pressed and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		if event.button_index==JOY_BUTTON_X: start_reload();return true
		if event.button_index==JOY_BUTTON_Y and not models.is_empty(): select_weapon((selected+1)%models.size());return true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE,KEY_F1,KEY_F2,KEY_E,KEY_F5: trigger_held=false;return false
			KEY_Q: select_weapon((selected+1)%models.size());return true
			KEY_1: select_weapon(0);return true
			KEY_2: select_weapon(1);return true
			KEY_3: select_weapon(2);return true
			KEY_4: select_weapon(3);return true
			KEY_5: select_weapon(4);return true
			KEY_R: start_reload();return true
			KEY_BRACKETLEFT,KEY_BRACKETRIGHT:
				var change=1 if event.keycode==KEY_BRACKETRIGHT else -1
				if event.ctrl_pressed: aim_assist.friction=clampf(aim_assist.friction+change*.1,0,1)
				elif event.alt_pressed: aim_assist.adhesion=clampf(aim_assist.adhesion+change*.1,0,1)
				elif event.shift_pressed: aim_assist.angle_degrees=clampf(aim_assist.angle_degrees+change,1,10)
				else: aim_assist.strength=clampf(aim_assist.strength+change*.1,0,1)
				aim_clock=0;notice="Aim assistance saved" if aim_assist.save_settings()==OK else "Aim adjusted (could not save settings)";notice_time=2;return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		# A click that recaptures the cursor must never also discharge the weapon.
		if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: trigger_held=false;return false
		trigger_held=event.pressed;return true
	return false

func select_weapon(index: int) -> void:
	if reload_time>0 or models.is_empty(): return
	aim_state={};aim_clock=0
	selected=clampi(index,0,models.size()-1);trigger_held=false;recoil=0
	for i in models.size(): models[i].visible=i==selected
	if arms:
		arms.transform=arms_rest_transform
		arms.set_weapon_pose("railgun" if selected==1 else ("plasma" if selected==2 or selected==4 else "carbine"))
		if selected==4: arms.align_grip(Vector3(.006,-.085,-.085),3.0)
	redraw_frames=3

func start_reload() -> bool:
	if not available() or reload_time>0 or ammo[selected]>=CAPACITY[selected]: return false
	reload_time=1.5;trigger_held=false;redraw_frames=3;return true

func fire() -> bool:
	if not available() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or cooldown>0 or reload_time>0 or ammo[selected]<=0: return false
	if selected>=2 and (not plasma or plasma.bolts.size()>=plasma.LIMIT): return false
	ammo[selected]-=1;cooldown=INTERVAL[selected];recoil=.07;shots+=1
	# Camera-space aim works in every ring orientation. Exclude only our capsule.
	aim_state=aim_assist.solve(self)
	var origin: Vector3=arena.camera.global_position;var direction: Vector3=spread_direction(aim_state.direction)
	last_shot_aim={"red":aim_state.on_enemy,"spread_degrees":BASE_SPREAD[selected]+bloom[selected],"correction_degrees":rad_to_deg((-arena.camera.global_basis.z).angle_to(aim_state.direction))}
	bloom[selected]=minf(MAX_SPREAD[selected]-BASE_SPREAD[selected],bloom[selected]+.18)
	var shot_hit=trace_segment(origin,origin+direction*REACH[selected])
	var visual_origin: Vector3=origin+arena.camera.global_basis.x*.22-arena.camera.global_basis.y*.18+direction*.6
	if selected>=2:
		last_hit={}
		# Aim ray only chooses direction; it never applies damage or fixes a future hit.
		var aim: Dictionary=shot_hit
		var aim_point: Vector3=aim.position if not aim.is_empty() else origin+direction*REACH[selected]
		plasma.launch(visual_origin,(aim_point-visual_origin).normalized(),REACH[selected],DAMAGE[selected],origin)
	else:
		last_hit=shot_hit
		var end: Vector3=last_hit.position if not last_hit.is_empty() else origin+direction*REACH[selected]
		apply_hit(last_hit,DAMAGE[selected],origin)
		effects.append({"from":visual_origin,"to":end,"hit":not last_hit.is_empty(),"color":COLORS[selected],"ttl":.085})
		if effects.size()>8: effects.pop_front()
		update_effects()
	if arena.get("aliens"): arena.aliens.alert_shot(arena.camera.global_position)
	if audio and sounds[selected]: audio.stream=sounds[selected];audio.play()
	return true

func spread_direction(direction: Vector3) -> Vector3:
	var radius=tan(deg_to_rad(BASE_SPREAD[selected]+bloom[selected]))*sqrt(spread_rng.randf())
	var angle=spread_rng.randf()*TAU;var basis=Basis.looking_at(direction,arena.camera.global_basis.y)
	return (direction+basis.x*cos(angle)*radius+basis.y*sin(angle)*radius).normalized()
func controller_aim(move: Vector2, look: Vector2, delta: float) -> Dictionary:
	if not available() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		aim_assist.reset_tracking();return {"scale":1.0,"rotation":Vector2.ZERO}
	return aim_assist.controller_filter(self,move,look,delta)
func trace_segment(start: Vector3, end: Vector3) -> Dictionary:
	var began := Time.get_ticks_usec()
	var query := PhysicsRayQueryParameters3D.create(start,end,7)
	query.exclude=[arena.on_foot.get_rid()];query.hit_from_inside=true
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
	var stop: Vector3=hit.position if not hit.is_empty() else end
	var static_hit := preload("res://world/weapon_obstruction.gd").cast(arena,start,stop)
	trace_usec+=Time.get_ticks_usec()-began;trace_count+=1
	return static_hit if not static_hit.is_empty() else hit

func apply_hit(hit: Dictionary, damage: float, origin: Vector3) -> void:
	if hit.is_empty(): return
	last_hit=hit
	var target: Node=hit.collider
	while is_instance_valid(target) and target!=arena:
		if target.has_method("take_hit"):
			var result: Variant=target.take_hit(damage,origin,hit.position)
			notice=str(result) if result!=null else "Hit";notice_time=1;return
		target=target.get_parent()

func build_effects() -> void:
	var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true
	tracer=MeshInstance3D.new();tracer.mesh=ImmediateMesh.new();tracer.material_override=material;tracer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;arena.add_child(tracer)
	impacts=MultiMeshInstance3D.new();impacts.multimesh=MultiMesh.new();impacts.multimesh.transform_format=MultiMesh.TRANSFORM_3D;impacts.multimesh.use_colors=true
	var sphere := SphereMesh.new();sphere.radius=.065;sphere.height=.13;sphere.radial_segments=8;sphere.rings=4;impacts.multimesh.mesh=sphere
	impacts.material_override=material;impacts.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;arena.add_child(impacts)
	tracer.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;impacts.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF

func update_effects() -> void:
	if not tracer: return
	var mesh: ImmediateMesh=tracer.mesh;mesh.clear_surfaces()
	var hits := []
	if not effects.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for effect in effects:
			mesh.surface_set_color(effect.color);mesh.surface_add_vertex(effect.from);mesh.surface_add_vertex(effect.to)
			if effect.hit: hits.append(effect)
		mesh.surface_end()
	impacts.multimesh.instance_count=hits.size()
	for i in hits.size():
		impacts.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,hits[i].to));impacts.multimesh.set_instance_color(i,hits[i].color)

func _physics_process(delta: float) -> void:
	if not initialized: return
	for i in bloom.size(): bloom[i]=maxf(0,bloom[i]-delta*.65)
	cooldown=maxf(0,cooldown-delta);notice_time=maxf(0,notice_time-delta)
	var old_count := effects.size()
	for effect in effects: effect.ttl-=delta
	effects=effects.filter(func(effect): return effect.ttl>0)
	if effects.size()!=old_count: update_effects()
	if not available():
		trigger_held=false;reload_time=0;recoil=0;aim_state={};aim_clock=0;aim_assist.reset_tracking();return
	if Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED: trigger_held=false
	else:
		aim_clock-=delta
		if aim_clock<=0: aim_state=aim_assist.solve(self);aim_clock=.05
	if reload_time>0:
		reload_time=maxf(0,reload_time-delta)
		if reload_time==0: ammo[selected]=CAPACITY[selected]
	if arena.on_foot.get("aim_device")!=null and arena.on_foot.aim_device>=0 and not Input.get_connected_joypads().has(arena.on_foot.aim_device): trigger_held=false;arena.on_foot.aim_device=-1
	if trigger_held: fire()

func _process(delta: float) -> void:
	if not initialized: return
	var active := available() and presentation_enabled
	if active!=view_active:
		view_active=active;container.visible=active;ammo_label.visible=active;redraw_frames=3
		if not active: view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	var hud_hidden=arena.get("collision_debug") and arena.collision_debug.hud_hidden
	crosshair.visible=active and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED
	ammo_label.visible=active and not hud_hidden
	if not active: return
	recoil=move_toward(recoil,0,delta*.6)
	# Move the cached viewmodel image for recoil/reload instead of reskinning and
	# rendering the arms and weapon every frame of automatic fire.
	var foot: CharacterBody3D=arena.on_foot
	var speed := foot.velocity.slide(foot.up_direction).length()
	var move_blend := clampf(speed/8.5,0.0,1.0)*(1.0 if foot.is_on_floor() else .2)
	bob_amount=move_toward(bob_amount,move_blend,delta*5.0)
	bob_phase=fmod(bob_phase+delta*lerpf(5.0,10.0,clampf(speed/8.5,0.0,1.0)),TAU)
	var bob := Vector2(sin(bob_phase*.5)*2.0,absf(sin(bob_phase))*3.0)*bob_amount
	var reload_offset := 90*sin(PI*reload_time/1.5) if reload_time>0 else 0.0
	container.position=Vector2(bob.x,recoil*120.0+reload_offset+bob.y)
	if redraw_frames>0:
		view.render_target_update_mode=SubViewport.UPDATE_ONCE;view_redraws+=1;redraw_frames=maxi(0,redraw_frames-1)
	var size := get_viewport().get_visible_rect().size
	crosshair.configure(selected,BASE_SPREAD[selected]+bloom[selected])
	crosshair.position=size*.5-crosshair.size*.5
	crosshair.modulate=Color(1,.12,.12) if aim_state.get("on_enemy",false) else Color(.15,.65,1)
	ammo_label.text="%s   %d / %d\n%s" % [NAMES[selected],ammo[selected],CAPACITY[selected],"Reloading…" if reload_time>0 else ("R reload · unlimited reserve" if ammo[selected]==0 else "LMB fire · Q / 1–5 switch · R reload")]
	ammo_label.text+="\nAuto-aim %d%% | %.1f deg / %.0f m | [ ] strength, Shift+[ ] cone" % [roundi(aim_assist.strength*100),aim_assist.cone(selected),aim_assist.RANGES[selected]]
	ammo_label.text+="\nController friction %d%% / tracking %d%% | Ctrl+[ ] / Alt+[ ]" % [roundi(aim_assist.friction*100),roundi(aim_assist.adhesion*100)]
	if notice_time>0: ammo_label.text+="\n"+notice
	ammo_label.reset_size()
	ammo_label.position=Vector2(size.x-ammo_label.size.x-20,size.y-ammo_label.size.y-20)

func _exit_tree() -> void:
	if is_instance_valid(plasma): plasma.queue_free()
	if is_instance_valid(tracer): tracer.queue_free()
	if is_instance_valid(impacts): impacts.queue_free()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: trigger_held=false
