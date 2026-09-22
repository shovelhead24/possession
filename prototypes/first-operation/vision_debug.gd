extends MeshInstance3D

# Render-only vision frustum. It has no collision, gameplay query, or shadow.
func setup(range_m: float,fov_degrees: float,tint: Color,eye_height: float) -> void:
	# Outlines communicate the cone without translucent full-screen overdraw.
	var half=tan(deg_to_rad(fov_degrees*.5))*range_m
	var points=[Vector3.ZERO,Vector3(-half,0,-range_m),Vector3.ZERO,Vector3(half,0,-range_m),Vector3.ZERO,Vector3(0,half,-range_m),Vector3.ZERO,Vector3(0,-half,-range_m)]
	var line=ImmediateMesh.new();line.surface_begin(Mesh.PRIMITIVE_LINES)
	for point in points: line.surface_add_vertex(point)
	line.surface_end();mesh=line
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(tint,.8);material.emission_enabled=true;material.emission=tint;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position=Vector3(0,eye_height,0)
