extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
func _initialize(): run.call_deferred()
func settle(node: Node,camera: Vector3):
	for i in 180:
		node.update_around(camera,1.0/60)
		await process_frame
		if i>60 and node.queue.is_empty(): break
func run():
	root.size=Vector2i(1024,768)
	var image=Image.load_from_file("res://world/cloud_cache/billboards-v1.png")
	assert(image.get_size()==Vector2i(2048,2048))
	var alpha_max=0.0;var edge_max=0.0;var shade_max=0.0
	for y in range(0,2048,4):
		for x in range(0,2048,4):
			var p=image.get_pixel(x,y);alpha_max=maxf(alpha_max,p.a);shade_max=maxf(shade_max,p.r)
			if x%256==0 or y%256==0: edge_max=maxf(edge_max,p.a)
	assert(alpha_max>0.3 and edge_max<0.03 and shade_max>0.6)
	var world=Node3D.new();root.add_child(world)
	var camera=Camera3D.new();camera.near=0.5;camera.far=1200000;world.add_child(camera);camera.current=true
	var cached=preload("res://world/sky_cached_billboards.gd").new();world.add_child(cached)
	var pos=Ring.point(100,100,180);camera.position=pos;camera.look_at(pos+Vector3(0,0.3,1)*100)
	await settle(cached,pos)
	assert(cached.queue.is_empty() and cached.chunks.size()>0)
	var generated=cached.generated;var hits=cached.disk_hits
	await settle(cached,pos)
	assert(cached.generated==generated and cached.disk_hits==hits,"Stationary view rebuilt chunks")
	var first_key=cached.chunks.keys()[0];var identity=cached.chunks[first_key].node.get_instance_id()
	await settle(cached,pos+Vector3(20000,0,0));await settle(cached,pos)
	assert(cached.chunks[first_key].node.get_instance_id()==identity,"Revisit discarded cached batch")
	assert(cached.memory_hits>0)
	var fresh=preload("res://world/sky_cached_billboards.gd").new();world.add_child(fresh)
	await settle(fresh,pos)
	assert(fresh.generated==0 and fresh.disk_hits>0,"Restart did not reuse disk cache")
	print("CACHE_CHECK ",JSON.stringify({"atlas_alpha":alpha_max,"atlas_edge_alpha":edge_max,"atlas_shade":shade_max,"chunks":cached.chunks.size(),"disk_hits":fresh.disk_hits,"memory_hits":cached.memory_hits,"max_chunk_ms":cached.max_build_ms}))
	fresh.free()
	var high=preload("res://world/sky_high_painterly.gd").new();world.add_child(high)
	var vertices=high.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0,vertices.size(),100): assert(absf(Ring.coordinates(vertices[i]).y-6000)<0.2)
	high.set_altitude(8000);assert(high.material_override.get_shader_parameter("altitude")==8000)
	high.set_altitude(6000)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-16/yo/outputs/sky-cache-fixture.png")
	print("PASS atlas boundaries, no stationary regeneration, memory/disk reuse, physical 6km ring layer and altitude control")
	quit()
