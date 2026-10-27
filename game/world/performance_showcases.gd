extends Node
const Ring=preload("res://world/terrain_drive_ring.gd")
const ROOT="res://assets/showcases/"
var arena: Node3D
var sites: Array=[]
var instances: Array=[]
var refresh=0.0
var tree_batches: Array=[]
var terrain_materials: Array=[]
var wind_materials: Array=[]
var wind_variants: Array=[]
var wind_preset=2
var wind_field: Texture2D
var wind_grove: Node3D
func clear_wind_grove():
	if is_instance_valid(wind_grove):wind_grove.queue_free()
	wind_grove=null
func create_wind_grove():
	clear_wind_grove()
	var car=arena.vehicle_kit.car
	wind_grove=Node3D.new();arena.add_child(wind_grove);wind_grove.global_position=car.global_position;wind_grove.set_meta("floating_origin_root",true)
	for i in 3:
		var estimate=car.global_position+car.global_basis.x*(7.0+i*6.0)+car.global_basis.z*3.0
		var ground=arena.on_foot.find_ground(estimate,100,200)
		if ground.is_empty():continue
		var tree=MeshInstance3D.new();tree.mesh=wind_variants[i%wind_variants.size()][3 if i==2 else 2]
		wind_grove.add_child(tree);tree.global_transform=Transform3D(Ring.tangent_basis(ground.feet,i*.7).scaled(Vector3.ONE*(8.0+i*4.0)),ground.feet)
		tree.extra_cull_margin=12.0;tree.visibility_range_end=1600;tree.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.cloud_review.dialog.hide()
func set_wind_preset(index: int):
	wind_preset=index
	for material in wind_materials:
		material.set_shader_parameter("wind_strength",[0.0,.55,1.0][index])
		material.set_shader_parameter("wind_gust",[0.0,.25,.85][index])
func set_wind_direction(degrees: float):
	for material in wind_materials:material.set_shader_parameter("wind_direction",Vector2(cos(deg_to_rad(degrees)),sin(deg_to_rad(degrees))))
func set_wind_time(value: float):
	for material in wind_materials:material.set_shader_parameter("wind_time",value)
func set_tree_bend(value: float):
	for material in wind_materials:material.set_shader_parameter("tree_bend_gain",value)
func register_wind(material: ShaderMaterial):
	if wind_materials.has(material):return
	material.set_shader_parameter("wind_radius",Ring.Frame.CIRCUMFERENCE/TAU)
	material.set_shader_parameter("wind_field",wind_field)
	material.set_shader_parameter("tree_bend_gain",3.0)
	wind_materials.append(material)
func set_grass_scale(metres: float):
	for material in terrain_materials:material.set_shader_parameter("tile_metres",metres)
func set_grass_sample(index: int):
	for material in terrain_materials:material.set_shader_parameter("grass_sample",index)
func setup(owner_arena: Node3D):
	arena=owner_arena
	wind_field=(load(ROOT+"terrain.res") as ShaderMaterial).get_shader_parameter("ground_breakup")
	assert(wind_field!=null,"Wind requires the saved spatial field")
	# Separate materials keep this wind trial out of the original play area.
	for name in arena.trees.names:
		var levels=[]
		for level in 4:
			var mesh=preload("res://world/showcase_wind_assets.gd").prepare(arena.trees.variants[name][level],level)
			for surface in mesh.get_surface_count():
				var material=mesh.surface_get_material(surface)
				if material is ShaderMaterial:register_wind(material)
			levels.append(mesh)
		# Once motion is fully faded, retain the original cheapest static cards.
		levels.append(arena.trees.variants[name][3])
		wind_variants.append(levels)
	if not FileAccess.file_exists(ROOT+"manifest.json"):return
	sites=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	for site in sites:
		var packed=load(ROOT+site.id+".scn") as PackedScene
		if not packed:continue
		var node=packed.instantiate();arena.add_child(node)
		node.position=Ring.point(site.arc,site.base,site.lateral)
		node.set_meta("floating_origin_root",true)
		node.visible=false
		instances.append(node)
		# Reuse the established fir assets and their billboard LODs.
		for child in node.get_children():
			if child is MeshInstance3D and not child.material_override:
				var ground_material=child.mesh.surface_get_material(0)
				if not terrain_materials.has(ground_material):terrain_materials.append(ground_material)
			if not child is MultiMeshInstance3D:continue
			var mm=child.multimesh
			if mm.mesh.get_aabb().size.y>5.0:
				for j in mm.instance_count:
					var xf=mm.get_instance_transform(j);xf.basis=xf.basis.scaled(Vector3.ONE*10.0);mm.set_instance_transform(j,xf)
				var species=tree_batches.size()%arena.trees.names.size()
				mm.mesh=wind_variants[species][3]
				child.extra_cull_margin=12.0
				child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				tree_batches.append({"node":child,"species":species,"lod":3})
			elif mm.mesh.get_aabb().size.y>1.05:
				var mat=mm.mesh.surface_get_material(0)
				if mat is ShaderMaterial:
					mat.set_shader_parameter("detail_tex",arena.material.get_shader_parameter("grass"));register_wind(mat)
				child.extra_cull_margin=.5
		var tour=arena.cloud_review.viewpoints
		tour.entries.append({"name":site.name,"kind":"showcase","index":instances.size()-1})
		tour.picker.add_item(site.name)
	var column=arena.cloud_review.viewpoints.picker.get_parent()
	var label=Label.new();label.text="Wilderness ground texture / live scale comparison";column.add_child(label)
	var row=HBoxContainer.new();column.add_child(row)
	var scale_control=SpinBox.new();scale_control.min_value=.5;scale_control.max_value=8;scale_control.step=.5;scale_control.value=1;scale_control.suffix="m per tile";row.add_child(scale_control)
	scale_control.value_changed.connect(set_grass_scale)
	var samples=OptionButton.new();samples.add_item("Biome blend");samples.add_item("A / Golden straw");samples.add_item("B / Upland tussocks");row.add_child(samples);samples.item_selected.connect(set_grass_sample)
	label=Label.new();label.text="Compare 1, 2 and 4 m beside your player or Warthog. Session-only; default 1 m.";column.add_child(label)
	column=VBoxContainer.new();column.name="Wind";arena.cloud_review.tabs.add_child(column)
	label=Label.new();label.text="Wilderness trees and grass / session-only comparison";column.add_child(label)
	row=HBoxContainer.new();column.add_child(row)
	label=Label.new();label.text="Wilderness wind";row.add_child(label)
	var wind_picker=OptionButton.new()
	for title in ["Calm","Breeze","Gusts"]:wind_picker.add_item(title)
	wind_picker.select(2);wind_picker.item_selected.connect(set_wind_preset);row.add_child(wind_picker)
	var direction=SpinBox.new();direction.min_value=0;direction.max_value=360;direction.step=15;direction.value=30;direction.suffix="degrees";direction.custom_minimum_size.x=150;row.add_child(direction);direction.value_changed.connect(set_wind_direction)
	set_wind_preset(2);set_wind_direction(30)
	row=HBoxContainer.new();column.add_child(row)
	label=Label.new();label.text="Whole-tree bend";row.add_child(label)
	var bend=SpinBox.new();bend.min_value=0;bend.max_value=3;bend.step=.25;bend.value=3;bend.custom_minimum_size.x=130;row.add_child(bend);bend.value_changed.connect(set_tree_bend)
	var exaggerate=Button.new();exaggerate.text="Exaggerated tree wind";row.add_child(exaggerate)
	exaggerate.pressed.connect(func():wind_picker.select(2);set_wind_preset(2);bend.value=3.0)
	row=HBoxContainer.new();column.add_child(row)
	var grove=Button.new();grove.text="Test grove beside Warthog";row.add_child(grove);grove.pressed.connect(create_wind_grove)
	var clear=Button.new();clear.text="Clear test grove";row.add_child(clear);clear.pressed.connect(clear_wind_grove)
	label=Label.new();label.text="Three temporary visual trees: two mesh trees and one billboard.\nRoots stay anchored; trunk and foliage share the bend.\nCollision stays fixed. Exaggerated mode is for judging motion.";column.add_child(label)
func _process(delta: float):
	refresh-=delta
	if refresh>0 or not arena or not arena.camera:return
	refresh=.25
	var coord=Ring.coordinates(arena.camera.global_position)
	for i in instances.size():
		instances[i].visible=Vector2(coord.x-sites[i].arc,coord.z-sites[i].lateral).length()<6800.0
	for batch in tree_batches:
		if not batch.node.is_visible_in_tree():continue
		var distance=arena.camera.global_position.distance_to(batch.node.global_position)
		var level=2 if distance<240 else (3 if distance<1800 else 4)
		if level!=batch.lod:
			batch.node.multimesh.mesh=wind_variants[batch.species][level];batch.lod=level
func viewpoint(index: int) -> Dictionary:
	var site=sites[index]
	return {"eye":Ring.point(site.arc+site.eye[0],site.base+site.eye[1],site.lateral+site.eye[2]),"target":Ring.point(site.arc+site.target[0],site.base+site.target[1],site.lateral+site.target[2])}
func contains(point: Vector3) -> bool:
	var coord=Ring.coordinates(point)
	for site in sites:
		if absf(coord.x-site.arc)<2350 and absf(coord.z-site.lateral)<2350:return true
	return false
