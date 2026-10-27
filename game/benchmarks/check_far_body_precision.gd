extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/body-precision-results.json"

func _initialize():run.call_deferred()

func run():
	var rows=[]
	for distant in [false,true]:
		for speed in [0.1,1.0,4.0]:
			var body=RigidBody3D.new();body.gravity_scale=0;body.linear_damp=0;body.can_sleep=false
			body.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
			body.position=Vector3(-472445.28125,536341.625,-8685.9609375) if distant else Vector3.ZERO
			body.collision_layer=0;body.collision_mask=0
			var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();body.add_child(shape);root.add_child(body)
			await physics_frame
			body.linear_velocity=Vector3(0,speed,0)
			await physics_frame
			var first=body.position;var elapsed=0.0;var steps=[];var previous=first
			for i in 120:
				await physics_frame
				elapsed+=1.0/Engine.physics_ticks_per_second
				var delta=body.position.y-previous.y
				if not steps.has(delta):steps.append(delta)
				previous=body.position
			var row={"distant":distant,"speed":speed,"expected_distance":speed*elapsed,"actual_distance":body.position.y-first.y,"position_steps":steps,"reported_velocity":body.linear_velocity.y}
			rows.append(row);print("BODY_PRECISION ",JSON.stringify(row))
			body.queue_free();await physics_frame
	var file=FileAccess.open(OUT,FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close();quit()
