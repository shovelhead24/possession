extends Node3D
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var enemies: Array=[]
var squads: Array=[]
var garrisons: Array=[]
var corpses: Array=[]
var navigation: RefCounted
var cover: RefCounted
var bolts: Node3D
var gun_sound: AudioStream
var health := 100.0
var defeated := false
var active := false
var trex: Node3D
var rex_enabled := false
var rex_defeated := false
var clock := 0.0
var cover_clock := 0.0
var render_clock := 0.0
var grenade_cooldown := 0.0
var respawn_clock := 0.0
var spawn := Vector3.ZERO
var physics_usec := 0
var stream_enabled := true
var initialized := false
var authoring: Node
func setup(owner_arena: Node3D) -> void:
	arena=owner_arena;gun_sound=AudioStreamWAV.load_from_file("res://effects/plasma/terminator-single.wav")
	navigation=preload("res://world/aliens/navigation.gd").new();navigation.manager=self
	cover=preload("res://world/aliens/cover.gd").new();cover.manager=self
	bolts=preload("res://world/aliens/bolts.gd").new();bolts.manager=self;add_child(bolts)
	for elite in [false,true]:
		arena.loading.log_event("Preparing tactical "+("captain" if elite else "grunt")+" rig and 14 animation clips")
		var visual=preload("res://world/aliens/lizard_actor.gd").new();visual.elite=elite;visual.scale=Vector3.ONE*(1.5 if elite else 1.0);add_child(visual)
		visual.global_position=arena.camera.global_position-arena.camera.global_basis.z*4
		if visual.player: visual.player.advance(.05)
		await RenderingServer.frame_post_draw
		visual.free()
	spawn=arena.vehicle_kit.car.global_position
	if arena.vehicle_kit.car.has_signal("actor_impact"):
		arena.vehicle_kit.car.actor_impact.connect(on_vehicle_impact)
	rex_enabled=not OS.get_cmdline_user_args().has("--no-rebuild-rex")
	reset();initialized=true
	if rex_enabled:
		arena.loading.log_event("Restoring Tyrant: original walking, hill footing, bites and throws")
		spawn_rex()
		await RenderingServer.frame_post_draw
func paused() -> bool:
	return not initialized or not arena.ready_to_play or not arena.loading.dismissed or arena.editor.opened or arena.vehicle_kit.menu.opened or defeated
func target() -> Node3D:
	if arena.on_foot.active: return arena.on_foot
	if arena.vehicle_kit.driving: return arena.vehicle_kit.car
	return null
func is_target(body: Node) -> bool: return is_instance_valid(body) and body==target()
func resident(point: Vector3) -> bool:
	# Edits retain the old collision until an atomic physics-tick swap. Only
	# genuinely missing streamed terrain requires actors and props to suspend.
	return arena.streamer.ready_at(point)
func all_rids() -> Array[RID]:
	var ids: Array[RID]=[arena.on_foot.get_rid(),arena.vehicle_kit.car.get_rid()]
	for unit in enemies:
		if is_instance_valid(unit): ids.append(unit.get_rid())
	return ids
func ground(point: Vector3) -> Dictionary:
	if not arena.streamer.ready_at(point): return {}
	var up=Ring.up_at(point);var query=PhysicsRayQueryParameters3D.create(point+up*160,point-up*260,1)
	var hit=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.dot(up)<cos(deg_to_rad(46)): return {}
	hit.position+=up*.06;return hit
func clear_body(feet: Vector3, height: float) -> bool:
	var query=PhysicsShapeQueryParameters3D.new();var shape=CapsuleShape3D.new();shape.radius=.43;shape.height=height
	query.shape=shape;query.transform=Transform3D(Ring.tangent_basis(feet,0),feet+Ring.up_at(feet)*(height*.5+.03));query.collision_mask=7;query.exclude=all_rids()
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func reset() -> void:
	if is_instance_valid(trex): trex.release_hold();trex.queue_free();trex=null
	rex_defeated=false
	for unit in enemies: unit.queue_free()
	for squad in squads: squad.queue_free()
	for grenade in get_tree().get_nodes_in_group("rebuild_frags"): grenade.queue_free()
	enemies.clear();squads.clear();garrisons.clear();corpses.clear();navigation.invalidate();bolts.bolts.clear();bolts.batch.multimesh.visible_instance_count=0
	health=100;defeated=false;active=false;clock=0;cover_clock=0
	var c=Ring.coordinates(spawn)
	if is_instance_valid(authoring):
		authoring.reset_encounters();return
	for offset in [Vector2(45,60),Vector2(100,90),Vector2(-120,180),Vector2(220,260)]:
		garrisons.append({"home":Ring.point(c.x+offset.x,c.y,c.z+offset.y),"squad":null,"snapshot":{},"quiet":300.0,"last_known":Vector3.ZERO,"retired_at":0.0})
func stream_squads() -> void:
	var ordered=garrisons.duplicate();var camera=arena.camera.global_position
	ordered.sort_custom(func(a,b): return a.home.distance_squared_to(camera)<b.home.distance_squared_to(camera))
	var wanted=[];var slots=0
	for entry in ordered:
		if is_instance_valid(entry.squad) and entry.squad.members.all(func(unit): return unit.dead): continue
		if not entry.snapshot.is_empty() and entry.snapshot.values().filter(func(value): return value.get("dead",false)).size()==int(entry.get("count",5)): continue
		var cost=int(entry.get("count",5))
		if slots+cost<=10: wanted.append(entry);slots+=cost
	for entry in garrisons:
		if is_instance_valid(entry.squad) and (entry.home.distance_to(camera)>240 or (entry not in wanted and entry.home.distance_to(camera)>140)):
			var near=false
			for unit in entry.squad.members:
				if unit.has_meta("trex_held") or (not unit.dead and unit.global_position.distance_to(camera)<140): near=true;break
			if near: continue
			var squad=entry.squad
			if squad.authored:
				entry.route_state=squad.route.snapshot()
				for unit in squad.members:
					if not unit.dead: entry.home=unit.global_position;break
			entry.quiet=squad.quiet;entry.last_known=squad.last_known;entry.retired_at=Time.get_ticks_msec()/1000.0
			for unit in squad.members:
				entry.snapshot[unit.get_meta("slot")]={"position":unit.global_position,"health":unit.health,"dead":unit.dead};enemies.erase(unit);unit.queue_free()
			squads.erase(squad);squad.queue_free();entry.squad=null
	for entry in wanted:
		var used=0
		for s in squads: used+=s.members.filter(func(unit): return not unit.dead).size()
		if used+int(entry.get("count",5))>10: continue
		if is_instance_valid(entry.squad) or entry.home.distance_to(camera)>180 or not resident(entry.home): continue
		var casualties=0
		for saved in entry.snapshot.values():
			if saved.get("dead",false): casualties+=1
		if casualties==int(entry.get("count",5)): continue
		var home=ground(entry.home)
		if home.is_empty(): continue
		entry.home=home.position
		var squad=preload("res://world/aliens/reptile_squad.gd").new();squad.manager=self;squad.home=entry.home;squad.last_known=entry.last_known
		add_child(squad);squads.append(squad);entry.squad=squad
		if entry.has("record"):
			squad.configure_authored(entry.record);squad.route.restore(entry.get("route_state",{}));squad.route_target=squad.route.points[squad.route.index]
		for i in int(entry.get("count",5)):
			var saved=entry.snapshot.get(i,{})
			if saved.get("dead",false): continue
			var wanted_point=saved.get("position",entry.home+Ring.tangent_basis(entry.home,0)*(Vector3.ZERO if entry.get("count",5)==1 else Vector3((i-2)*3.5,0,(i%2)*3.5)))
			var feet=safe_spawn(wanted_point)
			if feet==Vector3.INF: continue
			var unit=preload("res://world/aliens/squad_enemy.gd").new();unit.elite=i==0 and entry.get("elite",true);unit.manager=self;unit.arena=arena;unit.squad=squad;unit.position=feet;unit.basis=Ring.tangent_basis(feet,deg_to_rad(float(entry.get("yaw",0))));unit.set_meta("slot",i);unit.set_meta("actor_id",entry.get("actor_id",0))
			add_child(unit);unit.health=saved.get("health",unit.health);squad.members.append(unit);enemies.append(unit)
			if i==0: squad.captain=unit
		if squad.members.is_empty(): squads.erase(squad);squad.queue_free();entry.squad=null;continue
		squad.quiet=entry.quiet
		if entry.retired_at>0: squad.advance_memory(Time.get_ticks_msec()/1000.0-entry.retired_at,false)
		squad.issue_orders()
func safe_spawn(wanted: Vector3) -> Vector3:
	for index in 25:
		var angle=index*2.4;var offset=Ring.tangent_basis(wanted,0)*Vector3(cos(angle),0,sin(angle))*sqrt(index)*1.5
		var hit=ground(wanted+offset)
		if hit.is_empty() or not clear_body(hit.position,1.95): continue
		var clear=true
		for other in enemies:
			if other.global_position.distance_to(hit.position)<2.1: clear=false;break
		if clear: return hit.position
	return Vector3.INF
func alert_shot(point: Vector3) -> void:
	for squad in squads:
		if squad.home.distance_to(point)<80: squad.report_contact(point)
func fire_bolt(unit: Node, point: Vector3, direction: Vector3, damage: float, color: Color) -> bool:
	return bolts.launch(unit,point,direction,damage,color)
func hurt(amount: float) -> void:
	if paused(): return
	health=maxf(0,health-amount)
	if health<=0: defeated=true;respawn_clock=3;arena.weapons.trigger_held=false
func register_corpse(unit: Node) -> void:
	corpses.append({"unit":unit,"age":0.0})
	var live=[]
	for entry in corpses:
		if is_instance_valid(entry.unit) and is_instance_valid(entry.unit.lizard.ragdoll): live.append(entry)
	while live.size()>3: live.pop_front().unit.lizard.settle_ragdoll()
func _physics_process(delta: float) -> void:
	if not initialized: return
	if defeated and arena.loading.dismissed and not arena.editor.opened:
		respawn_clock-=delta
		if respawn_clock<=0:
			var feet=safe_spawn(spawn+Ring.tangent_basis(spawn,0)*Vector3(4,0,0))
			if feet!=Vector3.INF: health=100;defeated=false;arena.on_foot.activate_at(feet)
	if paused(): return
	var began=Time.get_ticks_usec();clock-=delta;cover_clock-=delta;grenade_cooldown=maxf(0,grenade_cooldown-delta)
	if clock<=0:
		clock=.5
		if stream_enabled: stream_squads()
		if rex_enabled and not rex_defeated and not is_instance_valid(trex): spawn_rex()
	if cover_clock<=0: cover_clock=3;cover.refresh()
	navigation.step()
	for entry in corpses:
		if not is_instance_valid(entry.unit): continue
		entry.age+=delta
		if entry.age>=4: entry.unit.lizard.settle_ragdoll()
		if entry.age>=30: entry.unit.hide()
	corpses=corpses.filter(func(e): return is_instance_valid(e.unit))
	physics_usec=Time.get_ticks_usec()-began
func handle_input(event: InputEvent) -> bool:
	if paused() or not event is InputEventKey or not event.pressed or event.echo: return false
	if event.keycode==KEY_F7: reset();return true
	if event.keycode==KEY_G and arena.on_foot.active and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and grenade_cooldown<=0:
		if get_tree().get_nodes_in_group("rebuild_frags").size()>=4: return true
		var grenade=preload("res://world/aliens/frag.gd").new();grenade.manager=self;grenade.position=arena.camera.global_position-arena.camera.global_basis.z*.7;add_child(grenade)
		grenade.add_collision_exception_with(arena.on_foot);grenade.linear_velocity=-arena.camera.global_basis.z*16+Ring.up_at(grenade.position)*5;grenade_cooldown=.8;return true
	return false
func status() -> String:
	return "Tactical squads %d / HP %d | G frag | F7 reset encounters%s%s" % [squads.size(),health," / RESPAWNING" if defeated else "",(" | Tyrant %d HP / %.0f m" % [trex.health,trex.global_position.distance_to(arena.camera.global_position)]) if is_instance_valid(trex) else ""]

func telemetry() -> Dictionary:
	var motion_usec=0;var path_usec=0;var sense_usec=0;var capsule_changes=0
	var actor_usec=0;var actor_ticks=0;var animation_usec=0;var animation_updates=0;var casters=0
	for unit in enemies:
		motion_usec+=unit.motion_usec;path_usec+=unit.path_usec;sense_usec+=unit.sense_usec;capsule_changes+=unit.capsule_changes
		actor_usec+=unit.physics_usec;actor_ticks+=unit.physics_ticks
		animation_usec+=unit.lizard.animation_usec;animation_updates+=unit.lizard.animation_updates
		if unit.lizard.shadow_enabled and unit.is_visible_in_tree(): casters+=1
	return {"motion_usec_total":motion_usec,"path_usec_total":path_usec,"sense_usec_total":sense_usec,"capsule_changes_total":capsule_changes,"actor_usec_total":actor_usec,"actor_ticks_total":actor_ticks,"animation_usec_total":animation_usec,"animation_updates_total":animation_updates,"shadow_casters":casters}

func _process(delta: float) -> void:
	if not initialized: return
	render_clock-=delta
	if render_clock>0: return
	render_clock=.25
	# Render visibility still follows the editor camera while gameplay is paused.
	for unit in enemies:
		unit.label.visible=not unit.dead and not arena.collision_debug.hud_hidden and not (arena.get("ai_debug") and arena.ai_debug.enabled)
		unit.lizard.update_shadow(arena.camera.global_position)

func on_vehicle_impact(body: Node, point: Vector3, relative: Vector3, normal: Vector3) -> void:
	if is_instance_valid(body) and body.has_method("vehicle_impact"):
		body.vehicle_impact(arena.vehicle_kit.original_car if arena.vehicle_kit.get("original_car") else arena.vehicle_kit.car,point,relative,normal)

func spawn_rex() -> void:
	if is_instance_valid(trex) or rex_defeated: return
	var c=Ring.coordinates(spawn)
	var home=Ring.point(c.x+150,c.y,c.z+110)
	if not resident(home): return
	var hit=ground(home)
	if hit.is_empty(): return
	trex=preload("res://world/aliens/trex.gd").new();trex.name="Tyrant";trex.manager=self;trex.arena=arena
	trex.patrol=[]
	for offset in [Vector2(150,110),Vector2(195,130),Vector2(185,205),Vector2(125,180)]:
		trex.patrol.append(Ring.point(c.x+offset.x,Ring.coordinates(hit.position).y,c.z+offset.y))
	trex.position=hit.position;add_child(trex)

func enemy_target(unit: Node3D) -> Node3D:
	var player=target()
	for rex in get_tree().get_nodes_in_group("tyrants"):
		if rex.health>0 and rex.global_position.distance_to(unit.global_position)<90:
			if not is_instance_valid(player) or rex.global_position.distance_squared_to(unit.global_position)<player.global_position.distance_squared_to(unit.global_position): player=rex
	return player
