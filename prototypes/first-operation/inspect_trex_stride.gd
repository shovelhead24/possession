extends "res://test_trex_behavior.gd"

func run() -> void:
	var arena=TestArena.new();arena.kit=TestKit.new();arena.add_child(arena.kit);root.add_child(arena)
	arena.walker=CharacterBody3D.new();arena.add_child(arena.walker)
	var manager=TestRange.new();root.add_child(manager)
	var rex=preload("res://trex.gd").new();rex.arena=arena;rex.manager=manager;arena.add_child(rex)
	rex.set_physics_process(false);rex.grounding.active=false
	rex.animator.play("CINEMA_4D_Main")
	var bones=["jt_Foot_R_041","jt_Foot_L_053","jt_Knee_R_040","jt_Knee_L_051","jt_Ankle_R_00","jt_Ankle_L_052"]
	var poses={}
	for frame in range(270,419):
		rex.skeleton.reset_bone_poses();rex.animator.seek(frame/30.0,true)
		var points=[]
		for bone in bones: points.append(rex.skeleton.to_global(rex.skeleton.get_bone_global_pose(rex.skeleton.find_bone(bone)).origin))
		poses[frame]=points
	var candidates=[]
	for first in range(270,330):
		for last in range(first+60,418):
			var error=0.0
			for i in bones.size(): error+=poses[first][i].distance_squared_to(poses[last][i])
			candidates.append([error,first,last])
	candidates.sort_custom(func(a,b): return a[0]<b[0])
	print("BEST SAME-LEG SEAMS ",candidates.slice(0,15))
	for frame in range(270,418,6): print("FEET ",frame," ",poses[frame][0]," ",poses[frame][1])
	quit()
