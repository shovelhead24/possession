extends SceneTree
const Bridge=preload("res://world/rebuild_controller.gd")
class Foot extends Node3D:
	var aim_device=-1
	var active=true
	var jump_queued=false
	var keys=[]
	func handle_input(event): keys.append(event.keycode)
class Aim extends RefCounted:
	func reset_tracking(): pass
class Weapons extends Node:
	var trigger_held=false
	var aim_assist=Aim.new()
	var models=[1,2]
	var selected=0
	var reloads=0
	var ammo_label=Label.new()
	var crosshair=Control.new()
	func start_reload(): reloads+=1
	func select_weapon(value): selected=value
class Loading extends RefCounted:
	var dismissed=true
	var ready_to_enter=true
	func close(): dismissed=true
class Aliens extends RefCounted:
	var enemies=[]
	var grenades=0
	func handle_input(_event): grenades+=1
class Arena extends Node3D:
	var ready_to_play=true
	var on_foot=Foot.new()
	var weapons=Weapons.new()
	var loading=Loading.new()
	var editor={"opened":false,"layer":CanvasLayer.new()}
	var vehicle_kit={"driving":false,"menu":{"opened":false},"vehicles":[],"driver_look":Vector2.ZERO}
	var aliens=Aliens.new()
	var collision_debug: Node
	var hud=Label.new()
func _initialize():
	create_timer(12).timeout.connect(func(): quit(1))
	run.call_deferred()
func run():
	var arena=Arena.new();root.add_child(arena);arena.add_child(arena.on_foot);arena.add_child(arena.weapons);arena.add_child(arena.hud)
	arena.add_child(arena.editor.layer);arena.editor.layer.add_child(Control.new())
	arena.weapons.add_child(arena.weapons.ammo_label);arena.weapons.add_child(arena.weapons.crosshair)
	arena.collision_debug=preload("res://world/rebuild_collision_debug.gd").new();arena.add_child(arena.collision_debug);arena.collision_debug.setup(arena)
	var bridge=Bridge.new();arena.add_child(bridge);bridge.arena=arena;bridge.set_physics_process(false);bridge.device=1
	assert(Bridge.preferred([{"id":0,"name":"DualSense Wireless Controller"},{"id":1,"name":"XInput Controller"}])==1,"Prefer virtual DS4 endpoint")
	assert(Bridge.preferred([{"id":3,"name":"DualSense Wireless Controller"}])==3,"Native fallback")
	var endpoints=[{"id":0,"name":"DualSense Wireless Controller"},{"id":1,"name":"XInput Controller"}]
	assert(Bridge.preferred(endpoints,"native")==0 and Bridge.preferred(endpoints,"virtual")==1,"Explicit source selection")
	assert(Bridge.preferred(endpoints,"auto",0)==0,"Stable connected endpoint is not replaced when virtual reappears")
	assert(Bridge.preferred([endpoints[0]],"virtual")==-1,"Explicit virtual does not fail over to native")
	var state={"buttons":{},"move":Vector2.ZERO,"look":Vector2.ZERO,"rt":0.0,"lt":0.0}
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	bridge.step(state,.016);state.buttons[JOY_BUTTON_A]=true;bridge.step(state,.016)
	assert(arena.on_foot.jump_queued and arena.on_foot.aim_device==1,"Polling activates controller and Cross")
	arena.on_foot.jump_queued=false;bridge.step(state,.016);assert(not arena.on_foot.jump_queued,"Held button does not repeat")
	state.buttons={};state.rt=.8;bridge.step(state,.016);assert(arena.weapons.trigger_held,"R2 level fires")
	bridge.step(state,.016,false);assert(not arena.weapons.trigger_held and arena.on_foot.aim_device==-1,"Focus loss releases trigger and movement")
	state.rt=0;bridge.step(state,.016);state.rt=.8;bridge.step(state,.016);assert(not arena.weapons.trigger_held,"Reactivation requires released trigger to arm")
	state.rt=0;bridge.step(state,.016);state.rt=.8;bridge.step(state,.016);assert(arena.weapons.trigger_held)
	state.rt=0;state.buttons[JOY_BUTTON_X]=true;bridge.step(state,.016);assert(arena.weapons.reloads==1)
	state.buttons={};bridge.step(state,.016);arena.vehicle_kit.driving=true;state.buttons[JOY_BUTTON_X]=true;bridge.step(state,.016);assert(arena.on_foot.keys[-1]==KEY_E,"Square exits vehicle")
	arena.vehicle_kit.driving=false;state.buttons={};bridge.step(state,.016);state.buttons[JOY_BUTTON_BACK]=true;bridge.step(state,.016)
	assert(arena.collision_debug.hud_hidden and arena.weapons.ammo_label.self_modulate.a==0 and arena.weapons.crosshair.self_modulate.a==1,"Create/Tab hides info, preserves reticle alpha")
	var duplicate=InputEventJoypadButton.new();duplicate.device=0;duplicate.button_index=JOY_BUTTON_A;duplicate.pressed=true
	assert(bridge.intercept(duplicate) and not arena.on_foot.jump_queued,"Duplicate native event does not dispatch gameplay")
	var mouse=InputEventMouseMotion.new();mouse.relative=Vector2(3,0);bridge.intercept(mouse);assert(not bridge.using_controller and arena.on_foot.aim_device==-1,"Mouse takeover")
	print("REBUILD_CONTROLLER_PASS: virtual selection, native fallback, polling, one-shot buttons, R2 release/focus/rearm, Square reload/exit, Create/Tab preserves reticle, duplicate suppression, mouse takeover")
	quit()
