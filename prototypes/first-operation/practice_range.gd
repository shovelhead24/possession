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
	if is_instance_valid(trex): trex.queue_free()
	for squad in squads: squad.queue_free()
	squads.clear();grenade_cooldown=0
	enemies.clear();health=100;active=false;defeated=false
	trex=preload("res://trex.gd").new();trex.arena=arena;trex.manager=self;add_child(trex)
	for home in [Vector3(48,0,-95),Vector3(112,0,-180),Vector3(-118,0,-230),Vector3(145,0,-370)]:
		var squad=preload("res://reptile_squad.gd").new();squad.manager=self;squad.home=home;squad.home.y=arena.height_at(home.x,home.z);squad.last_known=squad.home;add_child(squad);squads.append(squad)
		for i in range(5):
			var enemy=preload("res://squad_enemy.gd").new();enemy.elite=i==0;enemy.arena=arena;enemy.manager=self;enemy.squad=squad
			var spawn=home+(Vector3.ZERO if i==0 else Vector3((i-2.5)*3.5,0,6+float(i%2)*2))
			var cell=navigation.open_cell(spawn);enemy.position=Vector3(cell.x*4,arena.height_at(cell.x*4,cell.y*4),cell.y*4);add_child(enemy);enemies.append(enemy);squad.members.append(enemy)
			if i==0: squad.captain=enemy
		squad.issue_orders()

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
