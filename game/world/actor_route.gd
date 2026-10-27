extends RefCounted
## Shared arrival/wait semantics. Empty routes hold at the authored spawn.
var points: Array=[]
func origin_shifted(delta: Vector3):
	for i in points.size():points[i]-=delta
var index := 0
var wait := 0.0
var remaining := 0.0
var loop := true
var arrived := false
var finished := false
func configure(record: Dictionary) -> void:
	points=[]
	for p in record.route: points.append(preload("res://world/actor_store.gd").point(p))
	if points.is_empty(): points.append(preload("res://world/actor_store.gd").point(record.p))
	wait=record.wait;loop=record.loop;index=0;remaining=0;arrived=false;finished=false
func step(position: Vector3, delta: float, radius: float) -> Vector3:
	var target: Vector3=points[index]
	var up=preload("res://world/terrain_drive_ring.gd").up_at(position)
	if not arrived and (target-position).slide(up).length()<=radius: arrived=true;remaining=wait
	if arrived:
		remaining=maxf(0,remaining-delta)
		if remaining<=0 and not finished:
			if index+1<points.size(): index+=1;arrived=false
			elif loop and points.size()>1: index=0;arrived=false
			else: finished=true
	return points[index]
func holding() -> bool: return arrived or finished

func snapshot() -> Dictionary:
	return {"index":index,"remaining":remaining,"arrived":arrived,"finished":finished}
func restore(state: Dictionary) -> void:
	index=clampi(int(state.get("index",0)),0,points.size()-1)
	remaining=float(state.get("remaining",0));arrived=state.get("arrived",false);finished=state.get("finished",false)
