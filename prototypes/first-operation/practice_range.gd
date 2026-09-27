extends Node3D
var active := false
var health := 100
var arena: Node3D
var enemies: Array=[]
var squads: Array=[]
var cover: Node
var navigation: RefCounted
var grenade_cooldown := 0.0
var trex: Node3D
var tyrants: Array[Node3D]=[]
var garrisons: Array[Dictionary]=[]
var stream_timer := 0.0
var defeated := false
func _ready() -> void:
	arena=get_parent();name="PracticeRange"
	arena.box(Vector3(10,.7,-10),Vector3(1,1.4,1),arena.material(Color(.15,.25,.3)))
	arena.label3("E / RESET SQUADS\nG / FRAG GRENADE",Vector3(10,2,-10),24)
	cover=preload("res://arena_cover.gd").new();arena.add_child(cover)
	navigation=preload("res://squad_navigation.gd").new();navigation.setup(arena,cover)
	reset()

func reset() -> void:
	for bolt in get_tree().get_nodes_in_group("plasma_bolts"): bolt.queue_free()
	for grenade in get_tree().get_nodes_in_group("frag_grenades"): grenade.queue_free()
	for enemy in enemies: enemy.queue_free()
	for actor in tyrants:
		if is_instance_valid(actor): actor.remove_from_group("tyrants");actor.set_physics_process(false);actor.queue_free()
	tyrants.clear();garrisons.clear()
	for squad in squads: squad.queue_free()
	squads.clear();grenade_cooldown=0
	enemies.clear();health=100;active=false;defeated=false
	for index in (4 if arena.get("world_data") else 1):
		var actor=preload("res://trex.gd").new();actor.arena=arena;actor.manager=self;actor.name="Rexy_%d" % (index+1)
		if arena.get("world_data"): actor.patrol=preload("res://arena_bake_data.gd").patrol_route(index)
		add_child(actor);tyrants.append(actor)
		if arena.get("world_data"): actor.waypoint=1 # Head for the common centre immediately.
	trex=tyrants[0]
	if arena.get("world_data"):
		for home in arena.world_data.homes: garrisons.append({"home":home,"squad":null,"snapshot":{},"cleared":false})
		stream_squads();return
	for home in [Vector3(48,0,-95),Vector3(112,0,-180),Vector3(-118,0,-230),Vector3(145,0,-370)]:
		var squad=preload("res://reptile_squad.gd").new();squad.manager=self;squad.home=home;squad.home.y=arena.height_at(home.x,home.z);squad.last_known=squad.home;add_child(squad);squads.append(squad)
		for i in range(5):
			var enemy=preload("res://squad_enemy.gd").new();enemy.elite=i==0;enemy.arena=arena;enemy.manager=self;enemy.squad=squad
			var spawn=home+(Vector3.ZERO if i==0 else Vector3((i-2.5)*3.5,0,6+float(i%2)*2))
			var cell=navigation.open_cell(spawn);enemy.position=Vector3(cell.x*4,arena.height_at(cell.x*4,cell.y*4),cell.y*4);add_child(enemy);enemies.append(enemy);squad.members.append(enemy)
			if i==0: squad.captain=enemy
		squad.issue_orders()

func near_garrison(home: Vector3,player_radius: float,rex_radius: float) -> bool:
	if arena.walker.global_position.distance_squared_to(home)<player_radius*player_radius: return true
	for actor in tyrants:
		if is_instance_valid(actor) and actor.global_position.distance_squared_to(home)<rex_radius*rex_radius: return true
	return false

func stream_squads() -> void:
	for entry in garrisons:
		if entry.cleared: continue
		if not is_instance_valid(entry.squad):
			if not near_garrison(entry.home,220,90): continue
			var squad=preload("res://reptile_squad.gd").new();squad.manager=self;squad.home=entry.home;squad.last_known=entry.home;add_child(squad);squads.append(squad);entry.squad=squad
			for i in 5:
				var saved=entry.snapshot.get(i,{})
				if saved.get("dead",false): continue
				var unit=preload("res://squad_enemy.gd").new();unit.elite=i==0;unit.arena=arena;unit.manager=self;unit.squad=squad;unit.set_meta("garrison_slot",i)
				var spawn=saved.get("position",entry.home+Vector3((i-2)*3,0,float(i%2)*4))
				unit.position=ground_spawn(spawn)
				if unit.position==Vector3.INF: unit.free();continue
				add_child(unit);unit.health=saved.get("health",unit.health);enemies.append(unit);squad.members.append(unit)
				if i==0: squad.captain=unit
			squad.issue_orders()
		elif not near_garrison(entry.home,310,160):
			var squad=entry.squad;var alive=0
			# Persist casualties, damage and positions across streaming boundaries.
			var engaged=false
			for unit in squad.members:
				if unit.has_meta("trex_held") or near_garrison(unit.global_position,280,130): engaged=true;break
			if engaged: continue
			for unit in squad.members:
				entry.snapshot[unit.get_meta("garrison_slot")]={"dead":unit.dead,"health":unit.health,"position":unit.position}
				if not unit.dead: alive+=1
				enemies.erase(unit);unit.queue_free()
			entry.cleared=alive==0;squads.erase(squad);squad.queue_free();entry.squad=null

func ground_spawn(wanted: Vector3) -> Vector3:
	# Navigation cells are route waypoints, not shared actor spawn sockets.
	# Preserve formation offsets and reserve actual body-sized clearances.
	var cell=navigation.open_cell(wanted)
	var center=wanted if not navigation.is_blocked(wanted) else Vector3(cell.x*navigation.cell_size,0,cell.y*navigation.cell_size)
	for ring in 18:
		for spoke in (1 if ring==0 else 16):
			var angle=spoke*TAU/16.0
			var p=center+Vector3(cos(angle),0,sin(angle))*ring*2.0
			if navigation.is_blocked(p): continue
			var blocked=false
			for other in enemies:
				if is_instance_valid(other) and not other.dead and Vector2(p.x-other.position.x,p.z-other.position.z).length()<2.1: blocked=true;break
			if blocked: continue
			for rock in cover.rocks:
				if Vector2(p.x-rock.position.x,p.z-rock.position.z).length()<rock.radius+1: blocked=true;break
			if blocked: continue
			p.y=arena.height_at(p.x,p.z)+.05
			return p
	push_warning("No safe squad spawn found; skipped an obstructed slot instead of overlapping actors")
	return Vector3.INF

func hurt(amount: int,source: String="PLASMA") -> void:
	if defeated: return
	var before=health;health-=amount
	var file=FileAccess.open("user://damage-events.log",FileAccess.READ_WRITE if FileAccess.file_exists("user://damage-events.log") else FileAccess.WRITE_READ)
	if file:
		file.seek_end();file.store_line("%.3f source=%s amount=%d health=%d->%d" % [Time.get_ticks_msec()*.001,source,amount,before,health])
	arena.kit.status.text="%d HEALTH / %s" % [maxi(health,0),source]
	if health<=0:
		defeated=true
		if arena.kit.driving:
			arena.kit.restore_vehicle_collision(arena.kit.driving)
			arena.kit.driving=null;arena.kit.gunning=false;arena.kit.driver_model.hide();arena.kit.overlay.show();arena.set_physics_process(true)
			arena.walker.collision_layer=1;arena.walker.collision_mask=1;arena.walker.get_child(0).shape.height=1.8;arena.walker.get_child(0).position.y=.9;arena.camera.fov=arena.kit.foot_fov
		active=false;arena.set_physics_process(false);arena.kit.status.text="PRACTICE DEFEAT: "+source
		await get_tree().create_timer(1.4).timeout
		arena.viewpoint(1);reset();arena.kit.status.text="RESPAWNED AT FOB / RANGE RESET";arena.set_physics_process(true)

func tracer(a: Vector3,b: Vector3) -> void:
	var mesh=CylinderMesh.new();mesh.top_radius=.025;mesh.bottom_radius=.025;mesh.height=a.distance_to(b)
	var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=arena.material(Color(1,.3,.08),0,.5,true);add_child(node);node.position=(a+b)*.5;node.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	get_tree().create_timer(.12).timeout.connect(node.queue_free)

func plasma(start: Vector3,direction: Vector3,damage: float,enemy_shot: bool,owner_rid: RID,tint: Color=Color.TRANSPARENT) -> Node3D:
	var bolt=preload("res://plasma_bolt.gd").new()
	bolt.position=start;bolt.source=start;bolt.damage=damage;bolt.enemy_shot=enemy_shot;bolt.manager=self;bolt.excluded.append(owner_rid);bolt.tint=tint
	bolt.velocity=direction.normalized()*(arena.kit.combat_menu.enemy_speed if enemy_shot else arena.kit.combat_menu.player_speed)
	arena.add_child(bolt)
	return bolt
func alert_shot(point: Vector3) -> void:
	for squad in squads:
		for unit in squad.members:
			if not unit.dead and unit.position.distance_to(point)<75: squad.report_contact(point);break
func _physics_process(delta: float) -> void:
	grenade_cooldown=maxf(0,grenade_cooldown-delta)
	stream_timer-=delta
	if stream_timer<=0 and not garrisons.is_empty(): stream_timer=1.0;stream_squads()
	if not is_instance_valid(trex):
		for actor in tyrants:
			if is_instance_valid(actor): trex=actor;break
func throw_grenade() -> void:
	if grenade_cooldown>0 or arena.kit.driving or arena.kit.menu.opened: return
	grenade_cooldown=.8
	var camera=arena.camera;var direction=-camera.global_basis.z;var start=camera.global_position+direction*.5
	var ray=PhysicsRayQueryParameters3D.create(camera.global_position,start);ray.exclude=[arena.walker.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): start=camera.global_position
	var grenade=preload("res://frag_grenade.gd").new();grenade.manager=self;arena.add_child(grenade);grenade.global_position=start;grenade.linear_velocity=direction*16+Vector3.UP*3;grenade.angular_velocity=Vector3(2,3,1)
	grenade.add_collision_exception_with(arena.walker)
	get_tree().create_timer(.3).timeout.connect(func():
		if is_instance_valid(grenade): grenade.remove_collision_exception_with(arena.walker))
	arena.kit.status.text="FRAG / detonates after two seconds after stopping"
