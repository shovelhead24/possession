extends MeshInstance3D
const Ring=preload("res://world/terrain_drive_ring.gd")
var altitude := 6000.0
func _ready():
	position=-Ring.offset()
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	var vertices=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
	# Full cylinder: physical clouds remain in front of distant inner-ring terrain.
	for a in 2049:
		var arc=float(a)/2048.0*3000000.0
		for z in 5:
			var lat=lerpf(-25000,25000,z/4.0)
			vertices.append(Ring.Frame.position(arc,altitude,lat));uv.append(Vector2(arc,lat))
	for a in 2048:
		for z in 4:
			var v=a*5+z;indices.append_array([v,v+5,v+1,v+1,v+5,v+6])
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material=ShaderMaterial.new();material.shader=preload("res://world/sky_high_painterly.gdshader")
	material.set_shader_parameter("cloud_map",preload("res://world/sky_cached_textures.gd").get_upper())
	material.set_shader_parameter("altitude",altitude);material.render_priority=-10;material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	custom_aabb=AABB(Vector3(-480000,-15000,-26000),Vector3(960000,990000,52000))
func set_altitude(value: float):
	altitude=value
	if material_override: material_override.set_shader_parameter("altitude",altitude)
func set_brightness(value: float):
	if material_override: material_override.set_shader_parameter("cloud_brightness",value)
