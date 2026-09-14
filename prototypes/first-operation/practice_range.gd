extends Node3D
var active := false
var health := 100
var arena: Node3D
var enemies: Array=[]
func _ready() -> void:
	arena=get_parent();name="PracticeRange"
	arena.box(Vector3(10,.7,-10),Vector3(1,1.4,1),arena.material(Color(.15,.25,.3)))
	arena.label3("E / RESET PRACTICE\nScout · Guard · Heavy",Vector3(10,2,-10),24)
	reset()

func reset() -> void:
	for bolt in get_tree().get_nodes_in_group("plasma_bolts"): bolt.queue_free()
	for enemy in enemies: enemy.queue_free()
	enemies.clear();health=100;active=false
	for i in range(3):
		var enemy=preload("res://practice_enemy.gd").new();enemy.kind=i;enemy.arena=arena;enemy.manager=self;enemy.position=Vector3(30+i*8,arena.height_at(30+i*8,-65),-65);add_child(enemy);enemies.append(enemy)

func hurt(amount: int) -> void:
	health-=amount;arena.kit.status.text="PRACTICE / %d HEALTH / MOVE WHEN EYES FLASH" % maxi(health,0)
	if health<=0:
		active=false;arena.viewpoint(1);health=100;arena.kit.status.text="PRACTICE DEFEAT / E at range console to reset"

func tracer(a: Vector3,b: Vector3) -> void:
	var mesh=CylinderMesh.new();mesh.top_radius=.025;mesh.bottom_radius=.025;mesh.height=a.distance_to(b)
	var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=arena.material(Color(1,.3,.08),0,.5,true);add_child(node);node.position=(a+b)*.5;node.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	get_tree().create_timer(.12).timeout.connect(node.queue_free)

func plasma(start: Vector3,direction: Vector3,damage: float,enemy_shot: bool,owner_rid: RID) -> Node3D:
	var bolt=preload("res://plasma_bolt.gd").new()
	bolt.position=start;bolt.source=start;bolt.damage=damage;bolt.enemy_shot=enemy_shot;bolt.manager=self;bolt.excluded.append(owner_rid)
	bolt.velocity=direction.normalized()*(arena.kit.combat_menu.enemy_speed if enemy_shot else arena.kit.combat_menu.player_speed)
	arena.add_child(bolt)
	return bolt
