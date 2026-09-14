extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var arena=load("res://tactical.tscn").instantiate();root.add_child(arena);await process_frame
	var kit=arena.kit;var range_node=arena.get_node("PracticeRange");var scout=range_node.enemies[0]
	assert(scout.lizard.skeleton.get_bone_count()>=20)
	assert(scout.lizard.clips.size()==4,"All four animation clips must import")
	assert(scout.lizard.skeleton.find_bone("Muzzle")>=0)
	assert(scout.lizard.muzzle_position().distance_to(scout.position)<1.5)
	for enemy in range_node.enemies: enemy.set_physics_process(false)
	kit.set_physics_process(false);arena.set_physics_process(false)
	var target=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,2,.05);shape.shape=box;target.add_child(shape);target.set_meta("target_hits",0);arena.add_child(target);target.position=Vector3(-110,20,20)
	await physics_frame;await physics_frame
	var old_player=kit.combat_menu.player_speed;var old_enemy=kit.combat_menu.enemy_speed
	kit.combat_menu.player_speed=10
	var bolt=range_node.plasma(Vector3(-110,20,30),Vector3.FORWARD,25,false,arena.walker.get_rid());bolt.set_physics_process(false)
	assert(target.get_meta("target_hits")==0,"Plasma cannot damage on trigger press")
	bolt._physics_process(.2);assert(is_equal_approx(bolt.position.z,28));assert(target.get_meta("target_hits")==0)
	bolt._physics_process(.9);assert(target.get_meta("target_hits")==1);bolt._physics_process(1);assert(target.get_meta("target_hits")==1,"A bolt can hit only once")
	var wall=StaticBody3D.new();var wall_shape=CollisionShape3D.new();wall_shape.shape=box;wall.add_child(wall_shape);arena.add_child(wall);wall.position=Vector3(-110,20,25)
	await physics_frame;await physics_frame
	kit.combat_menu.player_speed=150
	bolt=range_node.plasma(Vector3(-110,20,30),Vector3.FORWARD,25,false,arena.walker.get_rid());bolt.set_physics_process(false);bolt._physics_process(.2)
	assert(bolt.spent and target.get_meta("target_hits")==1,"Fast bolts must hit thin cover")
	arena.walker.position=Vector3(-100,19,20);await physics_frame;await physics_frame
	kit.combat_menu.enemy_speed=20;var hp=range_node.health
	bolt=range_node.plasma(Vector3(-100,20,30),Vector3.FORWARD,8,true,scout.get_rid());bolt.set_physics_process(false)
	assert(bolt.velocity.length()==20);bolt._physics_process(.6);assert(range_node.health==hp-8,"Enemy plasma damages on impact")
	kit.combat_menu.player_speed=old_player;kit.combat_menu.enemy_speed=old_enemy
	var saved_path=kit.combat_menu.config_path;kit.combat_menu.config_path="res://test-plasma-settings.cfg"
	kit.combat_menu.controls.player_speed.value=37;kit.combat_menu.controls.enemy_speed.value=18
	var config=ConfigFile.new();assert(config.load(kit.combat_menu.config_path)==OK)
	assert(config.get_value("plasma","player_speed")==37 and config.get_value("plasma","enemy_speed")==18)
	kit.combat_menu.controls.player_speed.value=old_player;kit.combat_menu.controls.enemy_speed.value=old_enemy
	DirAccess.remove_absolute(ProjectSettings.globalize_path(kit.combat_menu.config_path));kit.combat_menu.config_path=saved_path
	var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_F3;kit.handle_vehicle_input(key);assert(kit.combat_menu.opened)
	key.keycode=KEY_ESCAPE;kit.handle_vehicle_input(key);assert(not kit.combat_menu.opened and not kit.warthog_menu.opened)
	if OS.get_cmdline_user_args().has("--pictures"):
		kit.overlay.hide();arena.camera.position=scout.position+Vector3(2,1.4,-3);arena.camera.look_at(scout.position+Vector3.UP*.65)
		scout.lizard.play("Idle");await create_timer(.2).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/lizard-idle.png")
		scout.lizard.play("Run");await create_timer(.25).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/lizard-run.png")
		for enemy_shot in [false,true]:
			var shot=range_node.plasma(scout.position+Vector3(.3 if enemy_shot else -.3,.8,-1.1),Vector3.FORWARD,8,enemy_shot,scout.get_rid());shot.set_physics_process(false)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/plasma-bolts.png")
		kit.menu=kit.combat_menu;kit.menu.set_open(true);await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/plasma-settings.png");kit.menu.set_open(false)
		scout.take_hit(50,scout.position+Vector3.FORWARD,scout.position+Vector3.UP);await create_timer(1.1).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/lizard-death.png")
	range_node.reset();await process_frame;assert(get_nodes_in_group("plasma_bolts").is_empty())
	print("PASS: skinned lizard, four clips, muzzle socket, timed plasma travel, thin cover, single hit, enemy damage, menu keys, reset cleanup")
	quit()
