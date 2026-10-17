extends "res://benchmarks/check_rebuild_rex_impacts.gd"
class Capture extends RefCounted:
	var rows=[]
	func write_event(kind, data): rows.append({"event":kind,"data":data.duplicate(true)})
class DebugArena extends Arena:
	var actors: Node3D
	var ai_debug: CanvasLayer
	var jitter_trace=Capture.new()
func _initialize():
	create_timer(25).timeout.connect(func(): push_error("AI/crate test timeout");quit(1))
	run.call_deferred()
func run():
	var arena=DebugArena.new();root.add_child(arena);arena.add_child(arena.painted_trees)
	arena.on_foot=Foot.new();arena.add_child(arena.on_foot);arena.on_foot.position=Vector3(0,0,200);arena.on_foot.active=false
	arena.vehicle_kit.car=preload("res://world/wishbone_vehicle.gd").new();arena.add_child(arena.vehicle_kit.car);arena.vehicle_kit.car.position=Vector3(0,0,200);arena.vehicle_kit.car.freeze=true;arena.vehicle_kit.car.set_physics_process(false)
	arena.camera=Camera3D.new();arena.add_child(arena.camera);arena.camera.position=Vector3(10,8,26);arena.camera.look_at(Vector3(0,1,0));arena.camera.current=true
	var floor_body=StaticBody3D.new();floor_body.collision_layer=1;arena.add_child(floor_body);floor_body.position.y=-.5
	var floor_shape=CollisionShape3D.new();floor_shape.shape=BoxShape3D.new();floor_shape.shape.size=Vector3(1000,1,1000);floor_body.add_child(floor_shape)
	var mesh=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.mesh.size=Vector3(1000,1,1000);floor_body.add_child(mesh)
	var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);arena.add_child(light)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.6;arena.add_child(env)
	arena.forge=preload("res://world/forge_world.gd").new();arena.add_child(arena.forge);arena.forge.set_physics_process(false)
	arena.aliens=preload("res://world/aliens/manager.gd").new();arena.add_child(arena.aliens)
	await physics_frame;await arena.aliens.setup(arena)
	var manager=arena.aliens;manager.stream_enabled=false;manager.rex_enabled=false;manager.set_physics_process(false)
	manager.garrisons.resize(1);manager.garrisons[0].home=Vector3(0,0,-5);manager.stream_squads()
	var squad=manager.squads[0];squad.set_physics_process(false)
	for unit in manager.enemies: unit.set_physics_process(false);unit.order(unit.position+Vector3(20,0,0),1.25,"Walk")
	for i in 300: manager.navigation.step()
	arena.actors=preload("res://world/actor_world.gd").new();arena.add_child(arena.actors);arena.actors.arena=arena;arena.actors.set_physics_process(false)
	var record=arena.actors.store.make("crate",Vector3(0,0,5));arena.actors.store.records.append(record);arena.actors.applied[record.id]=record.duplicate(true)
	assert(arena.actors.spawn_actor(record));var crate=arena.actors.live[record.id]
	var second=arena.actors.store.make("crate",Vector3(5,0,5));arena.actors.store.records.append(second);arena.actors.applied[second.id]=second.duplicate(true);assert(arena.actors.spawn_actor(second))
	arena.ai_debug=preload("res://world/ai_diagnostics.gd").new();arena.add_child(arena.ai_debug);arena.ai_debug.setup(arena);arena.ai_debug.set_process(false)
	for i in 12: arena.ai_debug.refresh(.25)
	assert(arena.ai_debug.samples[0].stalled_seconds>=2,"Blocked requested motion gets a suspected stall")
	assert(arena.ai_debug.samples[0].grid_cells==1089 and arena.ai_debug.samples[0].has("path_points"),"Path/grid diagnostics")
	var unit=manager.enemies[0];unit.position.x+=1;arena.ai_debug.refresh(.25)
	assert(arena.ai_debug.samples[0].motion=="MOVING","Motion clears stall")
	unit.pace=0
	for i in 12: arena.ai_debug.refresh(.25)
	assert(arena.ai_debug.samples[0].stalled_seconds==0,"Intentional idle is not stalled")
	arena.ai_debug._process(0);await process_frame
	var label=arena.ai_debug.labels[arena.ai_debug.identify(unit)].label;var size=label.size
	arena.camera.position=Vector3(18,12,52);arena.camera.look_at(Vector3(0,1,0));arena.ai_debug._process(0)
	assert(label.size==size and label.get_theme_font_size("font_size")==16,"Labels remain screen-sized across distance")
	assert(arena.ai_debug.preroll.size()==20 and arena.jitter_trace.rows.any(func(row): return row.event=="ai_transition") and arena.jitter_trace.rows.any(func(row): return row.event=="ai_snapshot"),"Bounded pre-roll and recording events")
	arena.camera.position=Vector3(10,8,26);arena.camera.look_at(Vector3(0,1,0));arena.ai_debug._process(0)
	await screenshot("ai-labels-crates.png")
	squad.report_contact(Vector3(0,0,40));squad.issue_orders();arena.ai_debug.refresh(.25);arena.ai_debug._process(0)
	assert(arena.ai_debug.samples.any(func(s): return s.get("tactical_role","")=="PAIR COVER" and not s.partner.is_empty()),"Pair roles and partners are recorded")
	await screenshot("dynamic-assault-pairs.png")

	await create_timer(1).timeout
	assert(crate.mass==160 and not crate.freeze,"Heavy crate rests as a dynamic body")
	var start=crate.position;var blast_origin=start+Vector3(-3,-.7,0)
	var wall=StaticBody3D.new();wall.collision_layer=2;arena.add_child(wall);wall.position=start+Vector3(-1.5,0,0)
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(.2,5,6);wall.add_child(shape)
	await physics_frame;await physics_frame
	preload("res://world/prop_blast.gd").apply(arena,blast_origin);assert(crate.last_blast==0,"Wall shields grenade impulse")
	wall.queue_free();await physics_frame;await physics_frame
	var grenade=preload("res://world/aliens/frag.gd").new();grenade.manager=manager;arena.add_child(grenade);grenade.global_position=blast_origin
	await physics_frame;grenade.detonate()
	assert(crate.last_blast>0,"Unblocked grenade imparts impulse")
	await create_timer(.5).timeout;assert(crate.position.distance_to(start)>.5,"Blast moves heavy box")
	arena.editor.opened=true;await physics_frame;await physics_frame;var paused=crate.position
	await create_timer(.2).timeout;assert(crate.freeze and crate.position.distance_to(paused)<.01,"Editor pauses crate physics")
	arena.editor.opened=false;await physics_frame;await physics_frame;assert(not crate.freeze,"Resume restores crate physics")
	# An 800 kg Warthog chassis contact must move a 160 kg crate.
	crate.freeze=true;crate.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,1,20));crate.linear_velocity=Vector3.ZERO;crate.angular_velocity=Vector3.ZERO
	await physics_frame;crate.freeze=false
	var chassis=preload("res://world/wishbone_vehicle.gd").new();arena.add_child(chassis);chassis.position=Vector3(-6,1,20);chassis.linear_velocity=Vector3(12,0,0)
	var body_shape=CollisionShape3D.new();body_shape.shape=BoxShape3D.new();body_shape.shape.size=Vector3(2,1.5,4);chassis.add_child(body_shape)
	await create_timer(.8).timeout;assert(crate.position.x>.5,"Vehicle collision pushes heavy crate")
	print("AI_CRATES_PASS: screen-size labels, live states, stall/idle distinction, path data, transition events, 5s pre-roll, crate spawn, blast shielding, grenade movement, pause/resume and Warthog chassis impact")
	arena.free();quit()
