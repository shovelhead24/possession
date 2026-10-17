extends SceneTree
const Forest=preload("res://world/aliens/forest_sight.gd")
class Menu extends CanvasLayer:
	var opened=false
	var settings={"camera_fov":73.0,"camera_mode":0,"camera_distance":6.0,"camera_height":3.6,"camera_smoothing":5.5}
class Arena extends Node3D:
	var camera: Camera3D
class Trees extends Node:
	var enabled=true
	var weapon_max_height=10.0
	var names=["test"]
	var variants={}
	var items=[]
	func weapon_candidates(_a,_b,_margin=0.0): return items
class Rex extends "res://world/aliens/trex.gd":
	func _ready():
		animator=AnimationPlayer.new();add_child(animator);floor_max_angle=deg_to_rad(48)
	func _physics_process(_delta): pass
	func _process(_delta): pass
	func ensure_walk(): pass
	func ground_sample(point: Vector3, allow_steep: bool=false) -> Dictionary:
		var normal=Vector3(-3,1,0).normalized() if point.x>0 else Vector3.UP
		if not allow_steep and normal.y<cos(floor_max_angle): return {}
		return {"position":Vector3(point.x,maxf(0,point.x)*3.0,point.z),"normal":normal}
func _initialize():
	create_timer(30).timeout.connect(func(): quit(1))
	run.call_deferred()
func run():
	var arena=Arena.new();root.add_child(arena)
	arena.camera=Camera3D.new();arena.add_child(arena.camera)
	var kit=preload("res://world/terrain_drive_vehicle.gd").new();arena.add_child(kit);kit.set_physics_process(false)
	kit.arena=arena;kit.initialized=true;kit.menu=Menu.new();kit.add_child(kit.menu)
	kit.car=RigidBody3D.new();arena.add_child(kit.car);kit.car.freeze=true
	kit.driver_look=Vector2(1,.4);kit.camera_forward_time=2.01;kit.camera_input_idle=1.99;kit.recenter_camera(1.0,10.0)
	assert(kit.driver_look==Vector2(1,.4),"Two-second camera input grace")
	kit.camera_input_idle=2.01;kit.recenter_camera(1.0,0.0)
	assert(kit.driver_look==Vector2(1,.4),"Stopped vehicle must not recenter")
	kit.recenter_camera(1.0,-10.0)
	assert(kit.driver_look==Vector2(1,.4),"Reverse must not recenter")
	kit.recenter_camera(1.0,10.0);assert(kit.driver_look.length()<.1,"Forward travel recenters")
	kit.register_camera_input();assert(kit.camera_input_idle==0)
	var wall=StaticBody3D.new();arena.add_child(wall);wall.position=Vector3(0,2,1.2);wall.collision_layer=4
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(5,5,.2);wall.add_child(shape)
	await physics_frame;await physics_frame
	arena.camera.position=Vector3(0,3,6);kit.driver_look=Vector2.ZERO;kit.update_camera(1.0/60)
	assert(kit.camera_close_view,"Tight wall triggers driver view")
	assert(arena.camera.position.z<.9,"Camera remains on car side of wall")
	wall.queue_free();await physics_frame;await physics_frame
	kit.update_camera(1.0/60);assert(not kit.camera_close_view,"Clearance restores chase view")
	assert(kit.menu.settings.camera_mode==0,"Fallback preserves selected chase mode")
	var trees=Trees.new();arena.add_child(trees)
	var mesh=BoxMesh.new();mesh.size=Vector3.ONE;trees.variants={"test":[mesh]}
	assert(Forest.depth(trees,Vector3(0,5,10),Vector3(0,5,-10))==0)
	trees.items=[{"valid":true,"height":10.0,"variant":0,"transform":Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*10),Vector3(0,5,0))}]
	var one=Forest.depth(trees,Vector3(0,5,10),Vector3(0,5,-10));assert(one>1.0)
	assert(Forest.depth(trees,Vector3(0,1,10),Vector3(0,1,-10))==0,"Clear space below crown")
	trees.items.append({"valid":true,"height":10.0,"variant":0,"transform":Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*10),Vector3(0,5,5))})
	assert(Forest.depth(trees,Vector3(0,5,10),Vector3(0,5,-10))>one,"Overlapping crowns compound cover")
	var rex=Rex.new();arena.add_child(rex);rex.position=Vector3(.5,1.55,0)
	for i in 90:
		var previous=rex.position;rex.move_walk(Vector3.RIGHT,1.0/60)
		assert(rex.position.distance_to(previous)<.6,"Recovery cannot teleport")
	assert(rex.position.x<0,"Rex escapes steep slope instead of stalling on it")
	assert(rex.recovery_count>0,"Recovery chooses and retains a detour")
	print("PASS camera recenter/input gate/reverse/obstruction recovery; forest crown cover/open gaps; Rex steep-slope escape without teleport")
	quit()

