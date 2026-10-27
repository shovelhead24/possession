extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/"
var materials=[]
var scene: Node3D
var camera: Camera3D
var billboard: MultiMeshInstance3D
var original_billboard: Mesh
func mesh_stats(mesh: Mesh) -> Vector2:
	var area=0.0;var triangles=0
	for surface in mesh.get_surface_count():
		var arrays=mesh.surface_get_arrays(surface);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
		var count=indices.size() if indices!=null and not indices.is_empty() else vertices.size()
		triangles+=count/3
		for i in range(0,count,3):
			var p=[]
			for j in 3:p.append(vertices[indices[i+j] if indices!=null and not indices.is_empty() else i+j])
			area+=(p[1]-p[0]).cross(p[2]-p[0]).length()*.5
	return Vector2(area,triangles)
func _initialize():run.call_deferred()
func capture(label: String) -> Image:
	for frame in 8:await process_frame
	await RenderingServer.frame_post_draw
	var image=root.get_texture().get_image();image.save_png(OUT+label+".png");return image
func changed(a: Image,b: Image) -> int:
	var first=a.get_data();var second=b.get_data();var count=0
	for i in first.size():
		if absi(int(first[i])-int(second[i]))>3:count+=1
	return count
func clock(value: float):
	for material in materials:material.set_shader_parameter("wind_time",value)
func preset(index: int):
	for material in materials:
		material.set_shader_parameter("wind_strength",[0.0,.55,1.0][index]);material.set_shader_parameter("wind_gust",[0.0,.25,.85][index])
func run():
	root.size=Vector2i(1000,700);Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.global_shader_parameter_set("ring_origin_offset",Vector3.ZERO)
	scene=Node3D.new();root.add_child(scene);scene.position=Vector3(1000,0,2000)
	var env=WorldEnvironment.new();var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.2,.26,.32);environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.55;env.environment=environment;scene.add_child(env)
	var light=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-45,-30,0)
	camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(17,11,29);camera.look_at(scene.global_position+Vector3(0,6,0));camera.current=true
	var assets=preload("res://world/tree_patch_assets.gd").new().load_meshes()
	var names=assets.keys();names.sort()
	for name in names:
		var source=assets[name][3];var split=preload("res://world/showcase_wind_assets.gd").prepare(source,3)
		var before=mesh_stats(source);var after=mesh_stats(split)
		assert(absf(before.x-after.x)<before.x*.0001,"Subdivision must preserve card area")
		assert(after.y>before.y and after.y<=160,"Billboard subdivision budget")
		assert(source.get_aabb().position.distance_to(split.get_aabb().position)<.0001 and source.get_aabb().size.distance_to(split.get_aabb().size)<.0001)
		print("BILLBOARD_CURVE_GEOMETRY ",name," triangles=",before.y," -> ",after.y)
	for level in [2,3]:
		var mesh=preload("res://world/showcase_wind_assets.gd").prepare(assets[names[0]][level],level)
		for surface in mesh.get_surface_count():
			var source=mesh.surface_get_material(surface)
			if source is ShaderMaterial:
				materials.append(source)
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=1;mm.set_instance_transform(0,Transform3D(Basis(Vector3.UP,level*.7).scaled(Vector3.ONE*12),Vector3((level-2.5)*10,0,0)))
		var visual=MultiMeshInstance3D.new();visual.multimesh=mm;visual.extra_cull_margin=12.0;scene.add_child(visual)
		if level==3:
			billboard=visual;original_billboard=assets[names[0]][3].duplicate()
			for surface in mesh.get_surface_count():original_billboard.surface_set_material(surface,mesh.surface_get_material(surface))
	var grass=load("res://assets/showcases/grass.res") as ArrayMesh
	materials.append(grass.surface_get_material(0))
	var grass_mm=MultiMesh.new();grass_mm.transform_format=MultiMesh.TRANSFORM_3D;grass_mm.mesh=grass;grass_mm.instance_count=100
	for i in 100:grass_mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,i*.7),Vector3((i%10)-5,0,3+(i/10)*.6)))
	var grass_node=MultiMeshInstance3D.new();grass_node.multimesh=grass_mm;grass_node.extra_cull_margin=.5;scene.add_child(grass_node)
	var field=(load("res://assets/showcases/terrain.res") as ShaderMaterial).get_shader_parameter("ground_breakup")
	assert(field!=null)
	for material in materials:
		material.set_shader_parameter("wind_direction",Vector2(.8,.6));material.set_shader_parameter("wind_field",field)
	preset(0);clock(0);var calm_a=await capture("wind-calm")
	var subdivided=billboard.multimesh.mesh;billboard.multimesh.mesh=original_billboard
	var original_calm=await capture("wind-billboard-original-calm")
	assert(changed(calm_a,original_calm)<calm_a.get_data().size()*.001,"Subdivision must preserve calm appearance and atlas UVs")
	billboard.multimesh.mesh=subdivided
	clock(3);var calm_b=await capture("wind-calm-later")
	assert(changed(calm_a,calm_b)==0,"Calm must not move")
	preset(2);clock(0);var gust_a=await capture("wind-gust-a")
	clock(3);var gust_b=await capture("wind-gust-b")
	assert(changed(gust_a,gust_b)>100,"Gusts must visibly move foliage")
	var shift=Vector3(512,128,512);scene.position-=shift;RenderingServer.global_shader_parameter_set("ring_origin_offset",shift)
	var shifted=await capture("wind-gust-rebased")
	var diff=changed(gust_b,shifted);assert(diff<gust_b.get_data().size()*.005,"Rebase must preserve wind pose")
	print("WIND_POSE_PASS calm=",changed(calm_a,calm_b)," gust=",changed(gust_a,gust_b)," rebase=",diff)
	for material in materials:material.set_shader_parameter("tree_bend_gain",3.0)
	clock(0);var strong_a=await capture("wind-whole-tree-strong-a")
	clock(3);var strong_b=await capture("wind-whole-tree-strong-b")
	assert(changed(strong_a,strong_b)>changed(gust_a,gust_b),"Exaggerated bend should increase visible motion")
	for material in materials:material.set_shader_parameter("tree_bend_gain",1.0)
	for index in [0,1,2,0]:
		preset(index);clock(-1)
		await create_timer(.5).timeout
		var frames=[];var last=Time.get_ticks_usec();var begin=last
		while Time.get_ticks_usec()-begin<3000000:
			await process_frame
			var now=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
		var total=0.0
		for value in frames:total+=value
		frames.sort();print("WIND_FRAME_SAMPLE preset=",index," mean_ms=",total/frames.size()," p95_ms=",frames[int(frames.size()*.95)])
	print("WIND_REVIEW_PASS LOD2 and billboard, grass, calm/gust, rebase");quit()
