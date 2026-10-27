extends SceneTree
const OUT="C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/"
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var results=[]
func _initialize():
	create_timer(360).timeout.connect(func():push_error("WEATHER_TIMEOUT");quit(1))
	run.call_deferred()
func lock_input(node: Node):
	node.set_process_input(false);node.set_process_unhandled_input(false);node.set_process_unhandled_key_input(false)
	for child in node.get_children():lock_input(child)
func capture(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func sample(label: String):
	await create_timer(1).timeout
	var frames=[];var start=Time.get_ticks_usec();var last=start
	while Time.get_ticks_usec()-start<4000000:
		await process_frame
		var now=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
	frames.sort();var total=0.0
	for v in frames:total+=v
	var row={"case":label,"mean_ms":total/frames.size(),"p95_ms":frames[int(frames.size()*.95)],"frames":frames.size()}
	results.append(row);print("WEATHER_CASE ",JSON.stringify(row))
func run():
	root.size=Vector2i(1366,768)
	arena=load("res://world/performance_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter:await process_frame
	assert("sky-test" in arena.forge.store.path and "sky-test" in arena.actors.store.path and "sky-test" in arena.destruction.save_path)
	await capture("weather-briefing")
	if "--ring-day-review" in OS.get_cmdline_user_args():
		await review_ring_day()
		return
	arena.loading.close();lock_input(arena);arena.controller.set_physics_process(false);Engine.max_fps=0
	arena.on_foot.deactivate();var kit=arena.vehicle_kit;kit.driving=true;kit.test_controls=true;kit.test_throttle=0;kit.test_brake=true
	assert(await kit.place(Vector2(120,145),atan2(-124.0,107.0)))
	for i in 180:await process_frame
	kit.driving=false;arena.diagnostic=true
	var ground=arena.on_foot.find_ground(kit.car.global_position+kit.car.global_basis.x*4)
	assert(not ground.is_empty());arena.on_foot.activate_at(ground.feet);arena.on_foot.test_controls=true;arena.on_foot.set_process(false)
	arena.camera.global_transform=Transform3D(Ring.tangent_basis(kit.car.global_position,atan2(-124.0,107.0)),kit.car.global_position+Ring.up_at(kit.car.global_position)*2.5)
	arena.camera.rotate_object_local(Vector3.RIGHT,-.15)
	if not arena.collision_debug.hud_hidden:arena.collision_debug.toggle_hud()
	arena.camera.rotate_object_local(Vector3.RIGHT,.45)
	var review=arena.cloud_review
	if "--showcase-review" in OS.get_cmdline_user_args():
		assert(arena.showcases.sites.size()==4)
		assert(arena.weapons.selected==4)
		assert(arena.showcases.wind_preset==2)
		for material in arena.showcases.wind_materials:assert(is_equal_approx(material.get_shader_parameter("tree_bend_gain"),3.0))
		assert(arena.showcases.wind_variants.size()==arena.trees.names.size())
		for preset in [0,1,2]:
			arena.showcases.set_wind_preset(preset)
			for material in arena.showcases.wind_materials:assert(is_equal_approx(material.get_shader_parameter("wind_strength"),[0.0,.55,1.0][preset]))
		arena.showcases.set_wind_preset(2)
		if "--wind-ui-review" in OS.get_cmdline_user_args():
			review.dialog.popup_centered();review.tabs.current_tab=review.tabs.get_tab_count()-1
			await capture("showcase-wind-controls");review.dialog.hide()
			arena.showcases.create_wind_grove()
			assert(arena.showcases.wind_grove.get_child_count()==3,"Three test trees need clear ground")
			arena.showcases.set_wind_preset(2);arena.showcases.set_tree_bend(3)
			var car=kit.car
			arena.camera.global_position=car.global_position-car.global_basis.x*12+car.global_basis.z*22+Ring.up_at(car.global_position)*6
			arena.camera.look_at(car.global_position+car.global_basis.x*12+Ring.up_at(car.global_position)*5,Ring.up_at(car.global_position))
			arena.showcases.set_wind_time(0);await capture("wind-warthog-grove-a")
			arena.showcases.set_wind_time(3);await capture("wind-warthog-grove-b")
			arena.showcases.set_wind_time(-1);arena.showcases.set_tree_bend(3);arena.showcases.set_wind_preset(2);arena.showcases.clear_wind_grove()
		for index in (1 if "--autumn-only" in OS.get_cmdline_user_args() else 4):
			var site=arena.showcases.sites[index]
			var entry_index=-1
			for i in review.viewpoints.entries.size():
				var entry=review.viewpoints.entries[i]
				if entry.kind=="showcase" and entry.index==index:entry_index=i
			assert(entry_index>=0)
			await review.viewpoints.visit(entry_index)
			await create_timer(1).timeout
			assert(arena.camera.global_transform.is_finite())
			await capture("showcase-"+site.id+"-vista")
			if index==0 and "--character-review" in OS.get_cmdline_user_args():
				var saved_view=arena.camera.global_transform
				var basis=Ring.tangent_basis(arena.camera.global_position,0)
				for side in [-1,1]:
					arena.camera.look_at(arena.camera.global_position-basis.x*side*1200-basis.y*220,basis.y)
					await create_timer(.5).timeout
					await capture("landscape-"+("west" if side<0 else "east"))
				arena.camera.global_transform=saved_view
			review.viewpoints.finish()
			var feet=Ring.point(site.arc+site.landing[0],site.base+site.landing[1],site.lateral+site.landing[2])
			await arena.ring_landing.prepare(feet)
			var landing=arena.on_foot.find_ground(feet,5,30)
			assert(not landing.is_empty(),"Showcase landing must have collision")
			review.viewpoints.player_start.place_player(landing.feet,0)
			arena.on_foot.set_process(true)
			for frame in 90:await physics_frame
			assert(arena.on_foot.is_on_floor(),"Showcase player must stand on ground")
			await capture("showcase-"+site.id+"-ground")
			if index==0 and "--grass-paint-review" in OS.get_cmdline_user_args():
				var painter=arena.painted_grass
				assert("sky-test" in painter.store.path)
				painter.store.records=[];painter.reindex()
				var options={"radius":6.0,"density":400.0,"height":1.0,"species":-1,"erase":false}
				while arena.destruction.busy():await physics_frame
				assert(painter.begin_paint(landing.feet,options));painter.release()
				while painter.busy():await physics_frame
				var count=painter.store.records.size();assert(count>100)
				var low=5.0;var high=0.0
				for r in painter.store.records:low=minf(low,r.height);high=maxf(high,r.height)
				assert(low<.65 and high>1.35)
				assert(painter.height_spread(10)<painter.height_spread(400))
				arena.editor.select_tool("grass");arena.editor.undo()
				await process_frame;await process_frame;assert(painter.store.records.is_empty())
				arena.editor.redo();await process_frame;await process_frame;assert(painter.store.records.size()==count)
				options.erase=true
				while arena.destruction.busy():await physics_frame
				while arena.destruction.busy():await physics_frame
				assert(painter.begin_paint(landing.feet,options));painter.release()
				while painter.busy():await physics_frame
				assert(painter.store.records.is_empty());painter.undo_paint();assert(painter.store.records.size()==count)
				assert(painter.store.save());var signature=painter.store.signature()
				painter.store.records=[];assert(painter.store.load_saved(painter.names));painter.reindex()
				assert(signature==painter.store.signature())
				await create_timer(1).timeout;assert(not painter.batches.is_empty())
				arena.editor.toggle();arena.editor.select_tool("grass")
				assert(arena.editor.grass_rows.visible)
				var up=Ring.up_at(landing.feet);var basis=Ring.tangent_basis(landing.feet,0)
				arena.camera.global_position=landing.feet+up*4+basis.z*9
				arena.camera.look_at(landing.feet+up*.5,up)
				await capture("grass-paint-editor")
				arena.editor.toggle()
				print("GRASS_PAINT_PASS paint, erase, editor undo/redo, save/load, dense height range=",low,"..",high," count=",count)
			if "--foliage-weapon-review" in OS.get_cmdline_user_args():
				Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
				arena.weapons.cooldown=0
				assert(arena.weapons.fire(),"Remote showcase rifle must fire")
				var plasma=arena.weapons.plasma
				assert(not plasma.bolts.is_empty())
				var before: Vector3=plasma.bolts[0].point
				var shift=Vector3(64,0,64)
				arena.floating_origin.rebase(shift)
				assert(plasma.bolts[0].point.is_equal_approx(before-shift))
				assert(plasma.batch.global_position.is_zero_approx())
				plasma._process(0)
				assert(plasma.batch.multimesh.visible_instance_count>=4)
				await capture("showcase-"+site.id+"-plasma")
				print("REMOTE_PLASMA_PASS ",site.id)
				landing.feet-=shift
				await create_timer(.3).timeout
			print("SHOWCASE_REVIEW_SITE ",site.id," ",JSON.stringify(arena.ring_position_data()))
			arena.on_foot.deactivate()
			var car=kit.car;car.freeze=true
			await physics_frame
			var car_point=landing.feet
			# Landing was resolved before rebasing; reconstruct from stable ring coordinates.
			car_point=Ring.point(site.arc+site.landing[0],site.base+site.landing[1]+1.0,site.lateral+site.landing[2])
			car.global_transform=Transform3D(Ring.tangent_basis(car_point,0),car_point)
			car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO
			car.stream_velocity=Vector3.ZERO;car.stream_angular=Vector3.ZERO;car.reset_physics_interpolation();car.freeze=false
			kit.driving=true;kit.test_brake=true;kit.test_throttle=0
			for frame in 120:await physics_frame
			assert(not car.streaming_suspended,"Showcase vehicle needs ready terrain")
			var drive_start=Ring.coordinates(car.global_position)
			kit.test_brake=false;kit.test_throttle=.5
			for frame in 180:await physics_frame
			var drive_end=Ring.coordinates(car.global_position)
			assert(car.global_transform.is_finite() and car.linear_velocity.is_finite())
			assert(Vector2(drive_end.x-drive_start.x,drive_end.z-drive_start.z).length()>1.0,"Showcase drive must move")
			await capture("showcase-"+site.id+"-drive")
			print("SHOWCASE_DRIVE_PASS ",site.id," metres=",drive_start.distance_to(drive_end))
			kit.test_brake=true;kit.test_throttle=0;kit.driving=false
			if index==0 and "--grass-scale-review" in OS.get_cmdline_user_args():
				car.freeze=true
				arena.camera.global_position=car.global_position+car.global_basis.x*5.5+car.global_basis.z*3.0+Ring.up_at(car.global_position)*2.5
				arena.camera.look_at(car.global_position+Ring.up_at(car.global_position)*.2,Ring.up_at(car.global_position))
				for sample_id in [1,2]:
					arena.showcases.set_grass_sample(sample_id)
					for metres in [1.0,2.0,4.0]:
						arena.showcases.set_grass_scale(metres)
						await create_timer(.25).timeout
						await capture("grass-scale-"+str(sample_id)+"-"+str(int(metres))+"m")
				arena.showcases.set_grass_scale(1.0);arena.showcases.set_grass_sample(0);car.freeze=false
			if index==0 and "--landscape-detail-review" in OS.get_cmdline_user_args():
				var track_point=Ring.point(site.arc+6.0,site.base+site.landing[1],site.lateral-835.0)
				var track_ground=arena.on_foot.find_ground(track_point,200,400)
				assert(not track_ground.is_empty())
				var up=Ring.up_at(track_ground.feet)
				var basis=Ring.tangent_basis(track_ground.feet,0)
				arena.camera.global_position=track_ground.feet+up*6.0+basis.x*7.0+basis.z*5.0
				arena.camera.look_at(track_ground.feet,up)
				await create_timer(.5).timeout
				await capture("showcase-track-study")
		await create_timer(2).timeout
		print("SHOWCASE_REVIEW_PASS visited vistas, grounded landings, drives, floating origin");quit();return
	if "--nearby-view-review" in OS.get_cmdline_user_args():
		for distant in [false,true]:
			for index in [0,1]:
				var arc=-892752.375 if distant else 111.213
				var lat=-2664.333 if distant else 161.917
				var ground_height=review.viewpoints.landscape_height(arc,lat,0)
				arena.camera.global_position=Ring.point(arc,ground_height+2,lat)
				var prior_mode=arena.on_foot.process_mode
				await review.viewpoints.visit(index)
				for i in 12:await physics_frame
				assert(arena.camera.global_transform.is_finite(),"Nearby viewpoint produced nonfinite camera")
				var coord=Ring.coordinates(arena.camera.global_position)
				assert(absf(coord.x-(arc-120))<1.0 and absf(coord.z-(lat+100))<1.0)
				assert(coord.y>=ground_height+79.0)
				assert(coord.y>=review.viewpoints.landscape_height(coord.x,coord.z,0)+79.0,"View must clear rendered terrain")
				await capture("nearby-view-"+str(distant)+"-"+str(index))
				review.viewpoints.finish()
				assert(not review.viewpoints.active and arena.on_foot.process_mode==prior_mode)
				assert(arena.camera.global_transform.is_finite())
		var spawn=review.viewpoints.player_start
		spawn.load_start();await spawn.apply_saved_start()
		arena.on_foot.set_process(true)
		for i in 90:await physics_frame
		assert(arena.on_foot.is_on_floor())
		assert(absf(Ring.coordinates(arena.on_foot.global_position).x-111.213)<2)
		await capture("nearby-view-return-home")
		print("NEARBY_VIEW_PASS home and remote, both entries, return and saved start");quit();return
	if "--local-grass-review" in OS.get_cmdline_user_args():
		var spawn=review.viewpoints.player_start
		spawn.load_start();await spawn.apply_saved_start()
		arena.on_foot.set_process(true)
		for i in 90:await physics_frame
		assert(arena.on_foot.is_on_floor(),"Restored home spawn needs ground")
		assert(absf(Ring.coordinates(arena.on_foot.global_position).x-111.213)<2.0)
		arena.on_foot.set_process(false)
		arena.camera.rotate_object_local(Vector3.RIGHT,-.45)
		await capture("local-grass-ground")
		await review.viewpoints.visit(0)
		await create_timer(1).timeout
		await capture("local-grass-distance")
		await review.viewpoints.visit(1)
		await create_timer(1).timeout
		await capture("local-grass-middle")
		assert(arena.material.shader.resource_path.ends_with("performance_grass.gdshader"))
		review.viewpoints.finish()
		await create_timer(2).timeout
		print("LOCAL_GRASS_PASS spawn=",JSON.stringify(spawn.start));quit();return
	if "--regional-satellite-review" in OS.get_cmdline_user_args():
		await review_regional_satellite();quit();return
	if "--floating-visual-review" in OS.get_cmdline_user_args():
		arena.floating_origin.enabled=false
		review.weather.set_preset(0);review.water.set_enabled(true)
		review.viewpoints.visit(2)
		await create_timer(1).timeout
		await capture("floating-water-before")
		arena.floating_origin.rebase(Vector3(512,128,-256))
		await capture("floating-water-after")
		for preset in [3,4,9]:
			arena.sky_comparison.apply_preset(preset)
			await create_timer(1).timeout
			await capture("floating-sky-"+str(preset))
		print("FLOATING_VISUAL_PASS water and cloud modes");quit();return
	if "--floating-full-review" in OS.get_cmdline_user_args():
		await review_floating_features();await review_floating_car();quit();return
	if "--floating-features-review" in OS.get_cmdline_user_args():
		await review_floating_features();quit();return
	if "--floating-car-review" in OS.get_cmdline_user_args():
		await review_floating_car();quit();return
	if "--car-frame-review" in OS.get_cmdline_user_args():
		await review_car_frames();quit();return
	if "--flat-car-review" in OS.get_cmdline_user_args():
		await review_flat_car();quit();return
	if "--ring-spawn-review" in OS.get_cmdline_user_args():
		await review_ring_spawn(review);quit();return
	if "--spawn-review" in OS.get_cmdline_user_args():
		await review_spawn(review);quit();return
	if "--viewpoints-review" in OS.get_cmdline_user_args():
		await review_viewpoints(review);quit();return
	while not review.cached.queue.is_empty():await process_frame
	await create_timer(4).timeout

	var weather=review.weather;var day=review.day_cycle
	var env: Environment=arena.daylight.environment
	var baseline={"fog":env.fog_enabled,"density":env.fog_density,"horizon":arena.backdrop.horizon_color,"sun":arena.daylight.sun.light_energy}
	if "--mist-review" in OS.get_cmdline_user_args():
		await review_mist(review);quit();return
	if "--water-review" in OS.get_cmdline_user_args():
		await review_water(review);quit();return
	review.set_mode(1)
	for index in range(10):
		weather.set_preset(index);await create_timer(1.5).timeout
		await capture("weather-preset-"+str(index))
	for index in [3,6,9]:
		weather.set_preset(index)
		for mode in [1,2,3]:
			review.set_mode(mode);await sample("weather_"+str(index)+"_mode_"+str(mode))
	weather.set_preset(5);weather.set_visibility(0)
	for amount in [0.0,0.58,0.58,0.0]:
		weather.set_rain(amount);await sample("rain_particles_"+str(amount))
	weather.set_rain(0.58)
	await create_timer(1.5).timeout
	assert(review.rain.enabled and not review.rain.sheltered,"Open-ground rain must emit")
	await capture("weather-rain-clear-view")
	var up=Ring.up_at(arena.camera.global_position)
	var roof=StaticBody3D.new();roof.collision_layer=2;root.add_child(roof)
	roof.global_transform=Transform3D(Ring.tangent_basis(arena.camera.global_position,0),arena.camera.global_position+up*3.0)
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(18,.5,18);shape.shape=box;roof.add_child(shape)
	await create_timer(.6).timeout
	assert(review.rain.sheltered and not review.rain.particles.visible,"Roof must suppress rain")
	roof.queue_free();await create_timer(.6).timeout
	assert(not review.rain.sheltered and review.rain.particles.emitting,"Rain must resume outside")
	weather.set_preset(7)
	var start_rain=weather.current_profile().rain
	weather.elapsed=40;weather.emit_profile(true);assert(weather.current_profile().rain>start_rain+.5)
	await create_timer(.4).timeout
	weather.elapsed=41;weather.emit_profile(true)
	assert(review.rain.particles.visible,"Changing shower intensity must not hide existing rain")
	weather.set_preset(2)
	arena.camera.look_at(arena.camera.global_position+arena.daylight.sun.global_basis.z*1000,up)
	for enabled in [false,true,true,false]:
		review.light_shafts.enabled=enabled;await sample("sun_shafts_"+str(enabled))
		if enabled:assert(review.light_shafts.strength>0.01 and review.light_shafts.shafts.visible,"Sun shafts must actually render in the cost comparison")
		await capture("weather-sun-shafts-"+str(enabled))
	review.light_shafts.enabled=true
	var blocker=StaticBody3D.new();blocker.collision_layer=2;root.add_child(blocker)
	blocker.position=arena.camera.global_position+arena.daylight.sun.global_basis.z*10
	shape=CollisionShape3D.new();var sphere=SphereShape3D.new();sphere.radius=3;shape.shape=sphere;blocker.add_child(shape)
	await create_timer(1).timeout
	assert(review.light_shafts.occluded and review.light_shafts.strength<.001,"Blocked sun must suppress shafts")
	blocker.queue_free();review.light_shafts.enabled=false
	weather.set_preset(5);day.set_hour(17.7)
	for i in 90:
		await RenderingServer.frame_post_draw
		for key in day.backdrop_materials():
			assert(arena.backdrop.get(key).get_shader_parameter("sky_color").is_equal_approx(arena.backdrop.horizon_color),"Weather must not reintroduce haze strobing")
	await capture("weather-rain-sunset")
	day.reset();weather.reset();review.set_mode(0)
	assert(env.fog_enabled==baseline.fog and is_equal_approx(env.fog_density,baseline.density))
	assert(arena.backdrop.horizon_color.is_equal_approx(baseline.horizon))
	assert(is_equal_approx(arena.daylight.sun.light_energy,baseline.sun))
	assert(not review.rain.enabled and not review.experimental_shaders)
	assert(review.cached.chunks.size()<=64)
	# Each preview can be enabled and reset in either order.
	for day_first in [false,true]:
		for reset_day_first in [false,true]:
			if day_first:day.set_hour(17.7);weather.set_preset(5)
			else:weather.set_preset(5);day.set_hour(17.7)
			if reset_day_first:day.reset();weather.reset()
			else:weather.reset();day.reset()
			await process_frame
			assert(arena.backdrop.horizon_color.is_equal_approx(baseline.horizon),"Reset order must restore original haze")
			assert(is_equal_approx(arena.daylight.sun.light_energy,baseline.sun),"Reset order must restore original sunlight")
	review.open_review();review.tabs.current_tab=1;await create_timer(.2).timeout
	assert(review.dialog.size.y<root.size.y-30)
	await capture("weather-controls")
	FileAccess.open(OUT+"weather-review-timings.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("WEATHER_PASS: presets, rain shelter/resume, showers, shafts occlusion, sunset haze, reset, UI");quit()

func review_mist(review):
	var original=arena.camera.global_transform
	var up=Ring.up_at(original.origin)
	var forward=-original.basis.z
	forward=(forward-up*forward.dot(up)).normalized()
	review.weather.set_preset(8)
	assert(review.valley_mist.visible and not arena.daylight.environment.fog_enabled)
	print("MIST_ALTITUDES camera=",Ring.coordinates(original.origin).y," ceiling=",review.valley_mist.ceiling)
	for height in [0,25,70,150]:
		arena.camera.global_position=original.origin+up*height
		arena.camera.look_at(original.origin+forward*500.0,up)
		await create_timer(.7).timeout
		await capture("valley-mist-height-"+str(height))
	for active in [false,true,true,false]:
		review.valley_mist.visible=active
		await sample("valley_mist_"+str(active))
	review.weather.set_preset(9)
	assert(not review.valley_mist.visible and arena.daylight.environment.fog_enabled)
	review.weather.reset()
	assert(not review.valley_mist.visible)
	FileAccess.open(OUT+"valley-mist-timings.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("MIST_PASS: valley and elevated views, thick fog separation, reset")

func review_water(review):
	var water=review.water
	assert(not water.visible)
	water.set_enabled(true)
	assert(water.mesh.get_surface_count()==1)
	water.set_diameter(80);assert(water.radius==40 and water.floor_heights.size()==1681)
	water.set_diameter(300);assert(water.radius==150 and water.mesh.get_surface_count()==1)
	water.set_diameter(170)
	water.set_highlights(0);assert(water.material.get_shader_parameter("specular_intensity")==0.0)
	water.set_highlights(1)
	print("WATER_LOCATION ",water.centre," level=",water.base_level)
	var centre=Ring.point(water.centre.x,water.base_level,water.centre.y)
	var up=Ring.up_at(centre)
	arena.camera.global_position=centre+Vector3(95,35,110)
	arena.camera.look_at(centre,up)
	await create_timer(3).timeout
	await capture("water-overview")
	water.set_palette(1);water.set_highlights(.3)
	await create_timer(.3).timeout;await capture("water-atlantic-subtle")
	water.set_palette(0);water.set_highlights(1)
	var overview=arena.camera.global_transform
	arena.camera.global_position=centre+Vector3(0,5,55)
	arena.camera.look_at(centre+Vector3(0,0,-35),up)
	await create_timer(1).timeout;await capture("water-shore-detail")
	arena.camera.global_transform=overview
	for active in [false,true,true,false]:
		water.set_enabled(active);await sample("lake_"+str(active))
	water.set_enabled(true)
	water.level_offset=2;water.if_mesh_rebuild();await create_timer(.5).timeout
	await capture("water-level-raised")
	water.level_offset=0;water.if_mesh_rebuild()
	review.day_cycle.set_hour(17.5);await create_timer(.5).timeout;await capture("water-sunset")
	review.day_cycle.reset();review.weather.set_preset(8)
	await create_timer(.5).timeout;await capture("water-mist")
	review.weather.reset()
	await review_far_water(review)
	review.open_review();review.tabs.current_tab=3;await create_timer(.3).timeout;await capture("water-controls")
	assert(review.dialog.size.y<root.size.y-30)
	water.set_enabled(false);assert(not water.is_processing())
	FileAccess.open(OUT+"water-timings.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("WATER_PASS: mesh, level, sunset, mist, controls, disabled processing")

func review_far_water(review):
	var water=review.water;var backdrop=arena.backdrop
	var original=arena.camera.global_transform
	var selected=-1;var pixel=Vector2.ZERO
	for i in backdrop._patch_fields.size():
		if selected>=0:break
		var field: PackedFloat32Array=backdrop._patch_fields[i]
		for y in range(128,385,32):
			if selected>=0:break
			for x in range(128,385,32):
				var h=(field[y*512+x]+backdrop._patch_offset[i])*backdrop.dem_scale
				if h<.1:selected=i;pixel=Vector2(x,y);break
	assert(selected>=0,"Need a real distant coastal patch for palette verification")
	var rect: Vector4=backdrop._patch_rects[selected]
	var arc=rect.x+(pixel.x/512.0-.5)*rect.z*2
	var lat=rect.y+(.5-pixel.y/512.0)*rect.w*2
	var target=Ring.point(arc,0,lat)
	arena.camera.global_position=Ring.point(arc-7000,6000,lat+7000)
	arena.camera.look_at(target,Ring.up_at(target))
	print("WATER_COAST_TEST ",backdrop._patch_names[selected])
	var haze=backdrop._mat.get_shader_parameter("haze_density")
	var sky=backdrop._mat.get_shader_parameter("sky_color")
	for index in [1,2]:
		water.set_palette(index)
		assert(backdrop._mat.get_shader_parameter("water_shallow_palette")==water.shallow)
		assert(backdrop._mat.get_shader_parameter("haze_density")==haze)
		assert(backdrop._mat.get_shader_parameter("sky_color")==sky)
		await create_timer(.5).timeout;await capture("water-distant-palette-"+str(index))
	review.day_cycle.set_hour(17.5)
	for frame in 30:
		await RenderingServer.frame_post_draw
		assert(backdrop._mat.get_shader_parameter("sky_color").is_equal_approx(backdrop.horizon_color))
	await capture("water-distant-sunset")
	review.day_cycle.reset();water.set_palette(0)
	water.match_distant=false;water.apply_palette();assert(not backdrop._mat.get_shader_parameter("water_palette_enabled"))
	water.match_distant=true;water.apply_palette()
	arena.camera.global_transform=original

func review_viewpoints(review):
	var tour=review.viewpoints
	var original=arena.camera
	var original_transform=original.global_transform
	var player_position=arena.on_foot.global_position
	var car_position=arena.vehicle_kit.car.global_position
	var original_mode=arena.on_foot.process_mode
	var original_stream=arena.streamer.process_mode
	assert(tour.entries.size()>3)
	for index in [0,1,2,3,tour.entries.size()-1]:
		tour.visit(index)
		var view=arena.camera.global_transform
		await create_timer(1).timeout
		assert(arena.camera==tour.camera and tour.camera.is_current())
		assert(arena.camera.global_transform.is_equal_approx(view),"Tour camera must stay put")
		assert(arena.on_foot.global_position.is_equal_approx(player_position))
		assert(arena.vehicle_kit.car.global_position.is_equal_approx(car_position))
		assert(review.valley_mist.get_parent()==tour.camera)
		await capture("viewpoint-"+str(index))
		tour.finish()
		assert(arena.camera==original and original.is_current())
		assert(original.global_transform.is_equal_approx(original_transform))
		assert(arena.on_foot.process_mode==original_mode and arena.streamer.process_mode==original_stream)
		assert(review.valley_mist.get_parent()==original)
	arena.on_foot.deactivate();arena.vehicle_kit.driving=true
	tour.visit(0);await create_timer(1).timeout;tour.finish()
	assert(arena.vehicle_kit.driving,"Vehicle mode must be restored")
	assert(arena.camera==original)
	review.open_review();review.tabs.current_tab=4
	await capture("viewpoints-menu")
	print("VIEWPOINTS_PASS entries=",tour.entries.size()," stable_views=5 player_and_vehicle_return=true")

func review_spawn(review):
	var tour=review.viewpoints
	var spawn=tour.player_start
	assert("sky-test" in spawn.path)
	spawn.path=spawn.path+".spawn-review"
	spawn.start={};spawn.startup_checked=true
	var before=arena.on_foot.global_position
	var ground={}
	for offset in [Vector3(12,0,0),Vector3(-12,0,0),Vector3(0,0,12),Vector3(0,0,-12)]:
		ground=arena.on_foot.find_ground(before+offset)
		if not ground.is_empty():break
	assert(not ground.is_empty())
	tour.visit(0)
	spawn.arm("save")
	await process_frame
	var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	click.position=arena.camera.unproject_position(ground.feet)
	assert(spawn.handle_input(click))
	assert(not spawn.start.is_empty(),"Cursor click must save a clear ground point")
	assert(arena.on_foot.global_position.is_equal_approx(before),"Saving start must not teleport")
	var saved=spawn.start.duplicate();var saved_text=FileAccess.get_file_as_string(spawn.path)
	spawn.start={};spawn.load_start()
	assert(not spawn.start.is_empty() and absf(spawn.start.arc_m-saved.arc_m)<.001 and absf(spawn.start.lateral_m-saved.lateral_m)<.001,"Saved start round trip")
	assert(Ring.point(saved.arc_m,saved.height_m,saved.lateral_m).distance_to(ground.feet)<.5,"Cursor target must match selected ground")
	review.dialog.hide();spawn.arm("spawn")
	click.position=arena.camera.unproject_position(before)
	spawn.handle_input(click)
	assert(not tour.active and arena.on_foot.active and not arena.vehicle_kit.driving)
	assert(FileAccess.get_file_as_string(spawn.path)==saved_text,"Spawn now must not change saved start")
	assert(not spawn.apply_ground(Vector3(0,100000,0),"save"),"Invalid ground must be rejected")
	await spawn.apply_saved_start()
	var coord=Ring.coordinates(arena.on_foot.global_position)
	assert(absf(coord.x-saved.arc_m)<.1 and absf(coord.z-saved.lateral_m)<.1,"Saved start must restore")
	var log_data=arena.jitter_trace.frame_context().ring_position
	assert(log_data.has("arc_m") and log_data.has("lateral_m"))
	await create_timer(.4).timeout
	assert("arc" in arena.collision_debug.fps_label.text and "lateral" in arena.collision_debug.fps_label.text)
	review.open_review();review.tabs.current_tab=4
	await capture("spawn-controls")
	spawn.arm("reset");assert(spawn.start.is_empty() and not FileAccess.file_exists(spawn.path))
	# Reproduce the user's F1 flight -> placement path, including failure/cancel.
	arena.editor.toggle();assert(arena.editor.opened)
	var editor_view=Transform3D(Ring.tangent_basis(ground.feet,0),ground.feet+Ring.up_at(ground.feet)*80)
	arena.camera.global_transform=editor_view;arena.camera.look_at(ground.feet,Vector3.FORWARD)
	spawn.arm("save")
	assert(not arena.editor.layer.visible and arena.streamer.process_mode!=Node.PROCESS_MODE_DISABLED)
	await process_frame
	click.position=arena.camera.unproject_position(ground.feet)
	arena.streamer.force_starvation=true;spawn.handle_input(click);arena.streamer.force_starvation=false
	assert(not tour.active and arena.editor.opened and arena.editor.layer.visible,"Rejected placement must restore F1 editor")
	assert("loading" in spawn.label.text)
	spawn.arm("save");await process_frame;spawn.handle_input(click)
	assert(not tour.active and arena.editor.opened and arena.editor.process_mode!=Node.PROCESS_MODE_DISABLED)
	spawn.arm("spawn");await process_frame;spawn.handle_input(click)
	assert(not arena.editor.opened and not tour.active and arena.on_foot.active,"Spawn must leave F1 mode")
	arena.editor.toggle();spawn.arm("save")
	var key=InputEventKey.new();key.pressed=true;key.keycode=KEY_F1
	assert(tour.handle_input(key) and not tour.active and arena.editor.opened,"F1 must escape placement back to editor")
	spawn.arm("save");key.keycode=KEY_ESCAPE;spawn.handle_input(key)
	assert(not tour.active and arena.editor.opened and arena.editor.layer.visible,"Escape must restore editor")
	spawn.arm("reset");review.open_review();review.tabs.current_tab=4
	await capture("spawn-editor-fix")
	print("SPAWN_EDITOR_PASS loading_rejection_restores_editor=true save_returns_to_editor=true spawn_exits_editor=true f1_escape=true cancel=true")
	print("SPAWN_REVIEW_PASS cursor_save=true save_without_move=true spawn_without_save=true reload=true invalid_ground=true coordinates_and_trace=true")

func review_ring_spawn(review):
	var tour=review.viewpoints;var spawn=tour.player_start
	spawn.path+=".ring-review";spawn.start={};spawn.startup_checked=true
	for index in [0,3,18,37,-1]:
		if index<0:tour.visit_coordinates(700000,500)
		else:tour.visit(index)
		await process_frame
		var before=arena.on_foot.global_position
		await spawn.below_view("save")
		assert(not spawn.start.is_empty(),"View must save: "+str(index)+" / "+spawn.label.text)
		assert(arena.on_foot.global_position.is_equal_approx(before),"Saving must not move player")
		var stored=spawn.start.duplicate()
		await spawn.below_view("spawn")
		assert(not tour.active,"View must land: "+str(index)+" / "+spawn.label.text)
		assert(arena.on_foot.active and arena.streamer.ready_at(arena.on_foot.global_position))
		arena.on_foot.set_physics_process(true);arena.on_foot.test_move=Vector2.ZERO
		await create_timer(1).timeout
		print("RING_GROUND_CHECK index=",index," floor=",arena.on_foot.is_on_floor()," velocity=",arena.on_foot.velocity," coords=",Ring.coordinates(arena.on_foot.global_position))
		assert(arena.on_foot.is_on_floor(),"Remote spawn must stand on real collision")
		assert(absf(Ring.coordinates(arena.on_foot.global_position).y-stored.height_m)<1.0)
		print("RING_VIEW_LANDED index=",index," coords=",JSON.stringify(arena.ring_position_data()))
		await capture("ring-spawn-"+str(index))
		spawn.start={};spawn.load_start();await spawn.apply_saved_start()
		assert(absf(Ring.coordinates(arena.on_foot.global_position).x-stored.arc_m)<1.0,"Remote saved start restore")
	# F1 camera at a remote location: aim and click visible terrain, not preloaded home ground.
	tour.visit_coordinates(700000,500)
	var aerial=arena.camera.global_transform
	var flight_key=InputEventKey.new();flight_key.pressed=true;flight_key.keycode=KEY_F1
	tour.handle_input(flight_key)
	assert(arena.editor.opened and not tour.active and arena.camera.global_transform.is_equal_approx(aerial),"F1 must keep distant aerial view")
	var here=arena.on_foot.global_position
	arena.camera.global_position=here+Ring.up_at(here)*100
	arena.camera.look_at(here,Ring.spinward_at(here));spawn.arm("spawn");await process_frame
	await spawn.pick_destination(arena.camera.unproject_position(here))
	assert(not tour.active and not arena.editor.opened and arena.on_foot.active,"Remote F1 cursor spawn")
	spawn.arm("reset");review.open_review();review.tabs.current_tab=4
	await capture("ring-spawn-menu")
	print("RING_SPAWN_PASS local_and_three_remote_views=true saved_restart_path=true grounded=true remote_f1_cursor=true")

func review_floating_features():
	var service=arena.floating_origin;service.enabled=true
	var kit=arena.vehicle_kit;var car=kit.car;var tour=arena.cloud_review.viewpoints
	var home=Ring.coordinates(car.global_position);var home_basis=car.global_basis
	var saves=[JSON.stringify(arena.forge.store.records),JSON.stringify(arena.actors.store.records),JSON.stringify(arena.painted_trees.store.records)]
	var sample_tree: Dictionary={}
	for item in arena.painted_trees.candidates:
		if item.valid:sample_tree=item;break
	var before=car.global_position;var eye=arena.camera.global_position-before
	service.rebase(Vector3(512,128,-256))
	assert((car.global_position-before+Vector3(512,128,-256)).length()<.001)
	assert((arena.camera.global_position-car.global_position-eye).length()<.001)
	if not sample_tree.is_empty() and is_instance_valid(sample_tree.body):assert(sample_tree.body.global_position.distance_to(sample_tree.transform.origin)<.001)
	service.rebase(-Ring.offset())
	assert(car.global_position.distance_to(before)<.001)
	assert(arena.streamer.ready_at(car.global_position))
	arena.cloud_review.water.set_enabled(true);arena.cloud_review.weather.set_preset(5)
	await capture("floating-home-before")
	service.rebase(Vector3(256,64,-128))
	await capture("floating-home-shifted")
	service.rebase(-Ring.offset())
	tour.visit_coordinates(-809197.144,-8685.961)
	for i in 10:await physics_frame
	assert(arena.camera.global_position.length()<2048)
	assert(absf(Ring.coordinates(arena.camera.global_position).x+809197.144)<.25)
	await capture("floating-distant-view")
	await tour.drive_test_pad()
	kit.test_throttle=0;kit.test_brake=true
	await create_timer(3).timeout
	assert(car.global_position.length()<2048 and car.grounded_count>=3)
	var pad: Vector3=arena.ring_landing.test_pads[false]
	var ground=arena.on_foot.find_ground(pad+Ring.up_at(pad)*2+Ring.spinward_at(pad)*10,4,20)
	assert(not ground.is_empty())
	assert(tour.player_start.apply_ground(ground.feet,"spawn"))
	await create_timer(.5).timeout
	assert(arena.on_foot.active and arena.on_foot.is_on_floor())
	assert(tour.player_start.apply_ground(arena.on_foot.global_position,"save"))
	var saved_start=tour.player_start.start.duplicate()
	tour.player_start.start={};tour.player_start.load_start()
	for key in ["arc_m","lateral_m","height_m","yaw"]:assert(absf(float(tour.player_start.start[key])-float(saved_start[key]))<.00001)
	await tour.player_start.apply_saved_start()
	assert(arena.on_foot.active and absf(Ring.coordinates(arena.on_foot.global_position).x-saved_start.arc_m)<.25)
	tour.review.dialog.hide()
	await capture("floating-distant-player")
	# Return to the original car pose, in the original local frame.
	arena.on_foot.deactivate();service.enabled=false;service.rebase(-Ring.offset())
	car.freeze=true;await physics_frame
	car.global_transform=Transform3D(home_basis,Ring.point(home.x,home.y+.5,home.z));car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO
	car.freeze=false;car.reset_physics_interpolation();kit.driving=true
	await create_timer(3).timeout
	assert(car.grounded_count>=3 and not car.freeze)
	assert(JSON.stringify(arena.forge.store.records)==saves[0] and JSON.stringify(arena.actors.store.records)==saves[1] and JSON.stringify(arena.painted_trees.store.records)==saves[2])
	await capture("floating-home-return")
	print("FLOATING_FEATURES_PASS camera, tree collision, terrain support, distant viewpoint, spawn, saved-start reload, return home, persistent records")

func review_floating_car():
	var kit=arena.vehicle_kit;var car=kit.car
	arena.floating_origin.enabled=false
	kit.driving=true;kit.test_controls=true;arena.on_foot.deactivate()
	var rows=[]
	for near in [true,false]:
		var point: Vector3=arena.ring_landing.test_pad(near)
		car.freeze=true;await physics_frame
		arena.floating_origin.rebase(point)
		point=arena.ring_landing.test_pads[near]
		car.global_transform=Transform3D(Ring.tangent_basis(point,0),point+Ring.up_at(point)*1.5)
		car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO
		car.stream_velocity=Vector3.ZERO;car.stream_angular=Vector3.ZERO;car.freeze=false
		for c in car.corners:c.omega=0.0;c.travel=0.0
		car.reset_physics_interpolation();kit.test_throttle=0;kit.test_brake=true
		await create_timer(3).timeout
		assert(car.grounded_count>=3 and not car.freeze)
		var up=Ring.up_at(car.global_position)
		for driving in [false,true]:
			kit.test_throttle=1 if driving else 0;kit.test_brake=not driving
			var sq=0.0;var grounded=0
			for i in 300:
				await physics_frame
				if driving and i==150:
					var before=Ring.coordinates(car.global_position);var velocity=car.linear_velocity;var basis=car.global_basis
					arena.floating_origin.rebase(Vector3(256,-128,64))
					assert(Ring.coordinates(car.global_position).distance_to(before)<.15)
					assert(car.linear_velocity.distance_to(velocity)<.0001 and car.global_basis.is_equal_approx(basis))
				var speed=car.linear_velocity.dot(up);sq+=speed*speed;grounded+=int(car.grounded_count>=3)
			var row={"near":near,"driving":driving,"normal_rms":sqrt(sq/300),"grounded_fraction":grounded/300.0,"local_position":str(car.global_position),"ring_position":arena.ring_position_data()}
			rows.append(row);print("FLOATING_CAR_CASE ",JSON.stringify(row))
		await capture("floating-car-"+str(near))
	var file=FileAccess.open(OUT+"floating-car-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()

func review_car_frames():
	arena.floating_origin.enabled=false
	var kit=arena.vehicle_kit;var car=kit.car
	kit.set_physics_process(false);kit.driving=true;arena.on_foot.deactivate()
	car.set_stream_ready(true);car.controlled=true;car.trace_suspension=true
	var far=Vector3(-472445.28125,536341.625,-8685.9609375)
	var tilted=Ring.tangent_basis(far,0)
	var rows=[]
	for distant in [false,true]:
		for rotated in [false,true]:
			var centre=far if distant else Vector3(0,2000,0)
			var frame=tilted if rotated else Basis.IDENTITY
			var pad=StaticBody3D.new();pad.position=centre;pad.collision_layer=1
			var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(600,2,600)
			shape.shape=box;shape.transform=Transform3D(frame,-frame.y);pad.add_child(shape);arena.add_child(pad)
			car.freeze=true;await physics_frame
			car.global_transform=Transform3D(frame,centre+frame.y*1.5)
			car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO;car.gravity_up=frame.y
			for c in car.corners:c.omega=0.0;c.travel=0.0
			car.set_controls(0,0,true);car.freeze=false;car.reset_physics_interpolation()
			await create_timer(3).timeout
			for driving in [false,true]:
				car.set_controls(1.0 if driving else 0.0,0,not driving)
				var sum_sq=0.0;var grounded=0;var first=car.global_position;var contacts=0
				for i in 300:
					await physics_frame
					var speed=car.linear_velocity.dot(frame.y);sum_sq+=speed*speed
					grounded+=int(car.grounded_count>=3);contacts+=car.get_contact_count()
				var row={"distant":distant,"rotated":rotated,"driving":driving,"normal_rms":sqrt(sum_sq/300),"grounded_fraction":grounded/300.0,"contacts":contacts,"distance":car.global_position.distance_to(first)}
				rows.append(row);print("CAR_FRAME_CASE ",JSON.stringify(row))
			car.freeze=true;pad.queue_free();await physics_frame
	var file=FileAccess.open(OUT+"car-frame-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"\t"));file.close()

func review_flat_car():
	arena.floating_origin.enabled=false
	arena.on_foot.deactivate();arena.vehicle_kit.driving=true
	var kit=arena.vehicle_kit;var car=kit.car
	car.trace_suspension=true;kit.test_controls=true
	var results=[]
	for near_origin in [true,false]:
		var point: Vector3=arena.ring_landing.test_pad(near_origin)
		await physics_frame
		car.global_transform=Transform3D(Ring.tangent_basis(point,0),point+Ring.up_at(point)*1.5)
		car.linear_velocity=Vector3.ZERO;car.angular_velocity=Vector3.ZERO;car.reset_physics_interpolation()
		kit.test_throttle=0;kit.test_brake=true;kit.test_steer=0
		await create_timer(3).timeout
		assert(not car.freeze and car.grounded_count>0,"Flat-pad vehicle must be supported before measurement")
		for driving in [false,true]:
			kit.test_throttle=1.0 if driving else 0.0;kit.test_brake=not driving
			var speeds=[];var grounded=0;var frames=0;var first=car.global_position;var start=Time.get_ticks_msec()
			while Time.get_ticks_msec()-start<5000:
				await physics_frame
				speeds.append(car.linear_velocity.dot(Ring.up_at(point)))
				grounded+=int(car.grounded_count>=3);frames+=1
			var sq=0.0
			for speed in speeds:sq+=speed*speed
			speeds.sort()
			var row={"near_origin":near_origin,"driving":driving,"normal_rms":sqrt(sq/frames),"normal_min":speeds[0],"normal_max":speeds[-1],"grounded_fraction":float(grounded)/frames,"distance":car.global_position.distance_to(first),"samples":frames}
			results.append(row);print("FLAT_CAR_CASE ",JSON.stringify(row))
		await capture("flat-car-"+str(near_origin))
	var file=FileAccess.open(OUT+"flat-car-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	kit.test_throttle=0;kit.test_brake=true
	arena.cloud_review.open_review();arena.cloud_review.tabs.current_tab=4
	await capture("flat-car-menu")

func review_regional_satellite():
	var tour=arena.cloud_review.viewpoints
	var spawn=tour.player_start
	spawn.restoring=true
	tour.begin()
	var top=Ring.point(209013.6,12000.0,9962.4)
	arena.camera.global_position=top
	var hit: Dictionary=await arena.ring_landing.pick(top,-Ring.up_at(top))
	assert(not hit.is_empty(),"Comparison terrain ray missed")
	# Capture fresh local coordinates after any shift during the asynchronous pick.
	await arena.ring_landing.prepare(hit.position)
	var ground=arena.on_foot.find_ground(hit.position,4,200)
	assert(not ground.is_empty(),"Comparison spawn is not walkable")
	spawn.place_player(ground.feet,0.0)
	tour.finish()
	spawn.restoring=false
	arena.on_foot.set_process(true)
	for i in 60:await physics_frame
	assert(arena.on_foot.is_on_floor(),"Comparison spawn must be grounded")
	assert(spawn.apply_ground(arena.on_foot.global_position,"save"))
	arena.cloud_review.dialog.hide()
	await spawn.apply_saved_start()
	for i in 60:await physics_frame
	assert(arena.on_foot.is_on_floor(),"Saved comparison start must reload on ground")
	var stream=arena.regional_satellite
	var deadline=Time.get_ticks_msec()+90000
	while stream.loaded!=stream.wanted or stream.loaded<0:
		assert(Time.get_ticks_msec()<deadline,"Regional image timed out")
		await process_frame
	assert(stream.texture.get_width()==8192)
	# Ensure the baseline is the real 512px preview, never an unresolved tint layer.
	var preview: Image=arena.backdrop._decode_preview("res://mocks/dem/"+arena.backdrop._patch_names[stream.loaded])
	assert(preview and preview.get_width()==512)
	arena.backdrop._patch_col_tex.update_layer(preview,stream.loaded)
	# Freeze view and time for a fair imagery comparison.
	arena.on_foot.set_process(false)
	arena.camera.rotate_object_local(Vector3.RIGHT,-.25)
	arena.backdrop._mat.set_shader_parameter("regional_satellite_enabled",false)
	await create_timer(1).timeout
	await capture("regional-satellite-before")
	arena.backdrop._mat.set_shader_parameter("regional_satellite_enabled",true)
	await create_timer(1).timeout
	await capture("regional-satellite-after")
	var before=Ring.coordinates(arena.camera.global_position)
	arena.floating_origin.rebase(Vector3(128,64,-128))
	await create_timer(.5).timeout
	assert(Ring.coordinates(arena.camera.global_position).distance_to(before)<.1)
	await capture("regional-satellite-shifted")
	print("REGIONAL_SATELLITE_PASS ",JSON.stringify(spawn.start)," patch=",arena.backdrop._patch_names[stream.loaded])

func review_ring_day():
	arena.loading.close();lock_input(arena);arena.controller.set_physics_process(false)
	await create_timer(3).timeout
	arena.on_foot.deactivate();arena.on_foot.set_process(false);arena.diagnostic=true
	if not arena.collision_debug.hud_hidden:arena.collision_debug.toggle_hud()
	arena.camera.global_position=Ring.point(0,250,16000)
	arena.camera.look_at(Ring.point(Ring.Frame.CIRCUMFERENCE*.40,0,16000),Vector3.UP)
	var review=arena.cloud_review
	var cycle=review.day_cycle
	assert(review.defaults_started and review.mode==2 and review.playing)
	assert(cycle.enabled and cycle.animate and is_equal_approx(cycle.hours_per_second,.02))
	assert(review.weather.cycling and arena.showcases.wind_preset==2)
	var weather=review.weather
	for step in weather.CYCLE_ORDER.size():
		weather._process(weather.CYCLE_SECONDS-weather.cycle_elapsed)
		var start=weather.current_profile()
		weather._process(weather.BLEND_SECONDS*.5)
		var middle=weather.current_profile()
		weather._process(weather.BLEND_SECONDS*.5)
		var end=weather.current_profile()
		for key in ["rain","wind","fog_density","mist_density","upper_fill"]:
			if weather.selected!=7:assert(is_equal_approx(float(middle[key]),lerpf(float(start[key]),float(end[key]),.5)))
	weather.set_preset(1);assert(not weather.cycling)
	weather.set_cycling(true);assert(weather.cycling)
	weather.reset();assert(not weather.cycling)
	print("ENVIRONMENT_DEFAULTS_PASS automatic start, all weather blends, manual override and restart")
	for hour in [12.0,0.0,6.0,18.0]:
		cycle.set_hour(hour)
		await create_timer(.5).timeout
		assert(arena.backdrop._mat.get_shader_parameter("ring_cycle_enabled"))
		var direction: Vector3=arena.daylight.sun.global_basis.z
		var local_height=Ring.up_at(arena.camera.global_position).dot(direction)
		var remote_height=Ring.up_at(Ring.point(Ring.Frame.CIRCUMFERENCE*.5,0,0)).dot(direction)
		assert(absf(local_height+remote_height)<.001)
		print("RING_DAY_CASE hour=",hour," local=",local_height," opposite=",remote_height)
		await capture("ring-day-"+str(int(hour)))
	# Clear sky isolates daytime stars from cloud coverage.
	cycle.set_hour(12)
	arena.camera.look_at(arena.camera.global_position+Vector3(.4,1,.2),Vector3.FORWARD)
	arena.sky_comparison.legacy.visible=false
	arena.sky_comparison.high_painterly.visible=false
	await create_timer(.5).timeout
	await capture("ring-stars-day")
	var before: Vector3=arena.daylight.sun.global_basis.z
	arena.floating_origin.rebase(Vector3(4096,1024,2048))
	cycle.apply_time();await process_frame;await process_frame
	assert(before.is_equal_approx(arena.daylight.sun.global_basis.z))
	assert(arena.backdrop._mat.get_shader_parameter("cycle_origin").is_equal_approx(Ring.offset()))
	cycle.reset();await process_frame;await process_frame
	assert(not arena.backdrop._mat.get_shader_parameter("ring_cycle_enabled"))
	cycle.set_hour(0)
	review.update_ring_lighting()
	var planet: Vector3=review.arena.sky_comparison.painted_material.get_shader_parameter("planet_direction")
	arena.camera.look_at(arena.camera.global_position+planet*100,Vector3.UP)
	print("PLANET_LIGHT_ENERGY ",review.moonlight.light_energy)
	assert(review.moonlight.light_energy>0 and review.moonlight.light_energy<=.140001)
	assert(not review.moonlight.shadow_enabled)
	assert(review.moon_fill.light_energy>0 and not review.moon_fill.shadow_enabled)
	assert(review.water.material.get_shader_parameter("moon_color").length()>0)
	await capture("planet-night-scale")
	arena.camera.fov=12
	await capture("planet-night-detail")
	cycle.set_hour(12);review.update_ring_lighting()
	assert(is_zero_approx(review.moonlight.light_energy))
	planet=review.arena.sky_comparison.painted_material.get_shader_parameter("planet_direction")
	arena.camera.look_at(arena.camera.global_position+planet*100,Vector3.UP)
	await capture("planet-day-detail")
	for i in review.viewpoints.entries.size():
		var entry=review.viewpoints.entries[i]
		if entry.kind=="showcase" and entry.index==0:
			arena.camera.fov=75
			await review.viewpoints.visit(i)
			cycle.set_hour(0);await create_timer(.5).timeout
			await capture("moonlight-landscape")
			break
	print("PLANET_PASS night light, day fade, shadows disabled")
	print("RING_DAY_PASS opposite hemispheres, rebase and reset")
	quit()
