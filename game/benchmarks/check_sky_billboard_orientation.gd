extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
func _initialize(): run.call_deferred()
func run():
	var facing=preload("res://world/sky_billboard_facing.gd")
	var previous=Vector3.ZERO
	for step in 801:
		var front=Vector3(lerpf(-0.2,0.2,step/800.0),-1,0).normalized()
		var next=facing.right_axis(front,Vector3.UP,previous,1.0/60.0)
		assert(absf(next.dot(front))<0.0001)
		if previous!=Vector3.ZERO: assert(previous.dot(next)>0.995,"Zenith orientation jumped")
		previous=next
	for front in [Vector3(1,-0.1,0).normalized(),Vector3(-1,-0.1,0).normalized(),Vector3(0,-0.1,1).normalized()]:
		var right=facing.right_axis(front,Vector3.UP,Vector3.ZERO,0)
		assert(absf(right.y)<0.0001,"Horizon cloud width is tilted")
	print("PASS continuous zenith crossing and horizontal cloud width in both ring directions")
	root.size=Vector2i(512,512)
	var world=Node3D.new();root.add_child(world)
	var camera=Camera3D.new();world.add_child(camera);camera.current=true
	var card=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(12,6);card.mesh=quad
	world.add_child(card);card.position=Vector3(0,20,0);card.basis=Ring.tangent_basis(card.position,0)
	card.custom_aabb=AABB(Vector3(-8,-8,-8),Vector3(16,16,16))
	var mat=ShaderMaterial.new();var shader=Shader.new()
	var code=FileAccess.get_file_as_string("res://world/sky_billboard.gdshader")
	# Keep the production vertex shader; solid colour measures projected card area.
	shader.code=code.substr(0,code.find("void fragment()"))+"void fragment(){ALBEDO=vec3(1,0,1);ALPHA=1.0;}"
	mat.shader=shader;card.material_override=mat
	for eye in [Vector3.ZERO,Vector3(0.01,0,0),Vector3(-0.01,0,0),Vector3(0,0,0.01),Vector3(18,10,0),Vector3(-18,10,0)]:
		camera.position=eye
		var direction=(card.position-eye).normalized()
		var up=Vector3.FORWARD if absf(direction.dot(Vector3.UP))>0.95 else Vector3.UP
		camera.look_at(card.position,up)
		var reference_area=0
		for roll in [0,90,180,270]:
			camera.look_at(card.position,up);camera.rotate_object_local(Vector3.FORWARD,deg_to_rad(roll))
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			var frame=root.get_texture().get_image();var pixels=0
			for y in range(0,512,2):
				for x in range(0,512,2):
					var color=frame.get_pixel(x,y)
					if color.r>0.8 and color.b>0.8 and color.g<0.2: pixels+=1
			assert(pixels>3000,"Card became edge-on or was culled")
			if roll==0: reference_area=pixels
			else: assert(absf(float(pixels-reference_area))/reference_area<0.04,"Card changed area when camera rotated")
	print("PASS production billboard vertex shader: overhead, either side of zenith, lateral viewpoints and four camera rolls retain area")
	card.free()
	var horizon=preload("res://world/sky_billboard_horizon.gd").new();world.add_child(horizon)
	for arc in [0.0,100000.0,-100000.0]:
		horizon.update_around(Ring.point(arc,5,0))
		assert(horizon.batches.size()==2)
		assert(horizon.signed_counts.x>50 and horizon.signed_counts.y>50)
		var far_negative=false;var far_positive=false
		for batch in horizon.batches:
			for i in batch.multimesh.instance_count:
				var t=batch.multimesh.get_instance_transform(i)
				var c=Ring.coordinates(t.origin)
				assert(c.y>800 and c.y<1600)
				if c.x-arc < -90000: far_negative=true
				if c.x-arc > 90000: far_positive=true
		assert(far_negative and far_positive,"Missing distant clouds in a ring direction")
	print("PASS horizon extends beyond 90 km in both ring directions at three positions, two batches, correct altitude")
	quit()
