extends SceneTree
const Recipe=preload("res://world/sdf_recipe.gd")
const Field=preload("res://world/unified_terrain_field.gd")
func _initialize() -> void:
	var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://sdf-authoring.json"))
	if not Recipe.validate(saved): push_error("Missing valid preservation baseline");quit(1);return
	var field := Field.new()
	if not field.setup(saved.features): push_error("DEM setup failed");quit(1);return
	var count := 0
	for z in range(-768,769,96):
		for x in range(-768,769,96):
			for y in [-24.0,0.0,4.0,8.0,12.0,32.0,64.0]:
				var p := Vector3(x,y,z)
				if field.field(p,3,.2)!=Recipe.field(p,3,.2,saved.features): push_error("Protected field changed");quit(1);return
				count+=1
	for p in [Vector3(-245,8,145),Vector3(-245,23,145),Vector3(145,8,-140),Vector3(-154,-5,-80),Vector3(-154,8,-80)]:
		if field.field(p,3,.2)!=Recipe.field(p,3,.2,saved.features): push_error("Landmark field changed");quit(1);return
	if field.dem_height(-14,-1600)!=field.dem_height(-14+Field.Frame.CIRCUMFERENCE,-1600): push_error("Arc wrap mismatch");quit(1);return
	for z in range(-768,-1601,-16):
		var p := Vector3(-14,4,z)
		if not is_finite(field.field(p,3,.2)): push_error("Nonfinite outward transition");quit(1);return
	var p := Vector3(-14,4,-1600)
	var q := Field.Frame.coordinates(p)
	var surface := Vector3(p.x,field.surface_height(Vector2(p.x,p.z)),p.z)
	q=Field.Frame.coordinates(surface)
	if absf(q.y-field.dem_height(q.x,q.z))>.05 or absf(field.base_field(surface,3,.2))>.001: push_error("Outer DEM mismatch");quit(1);return
	var expected_origin: float=float(field.elevation.decode_u16((int(field.metadata.camera_px[1])*int(field.metadata.w)+int(field.metadata.camera_px[0]))*2))/float(field.metadata.h_scale)
	if field.dem_height(0,0)!=expected_origin: push_error("DEM pixel origin mismatch");quit(1);return
	var edits: Array=[Recipe.feature("hill",p),Recipe.feature("carve",p)]
	var edited := Field.new()
	if not edited.setup(edits): push_error("Edited snapshot failed");quit(1);return
	if edited.source_hash==field.source_hash or edited.field(p,3,.2)!=Recipe.compose(p,edited.base_field(p,3,.2),edits): push_error("Ordered composition/identity mismatch");quit(1);return
	print("UNIFIED_TERRAIN_SAMPLE_PASS protected_samples=",count," landmarks=5 outward_direction=-Z full_dem=true source_hash=",field.source_hash)
	quit()
