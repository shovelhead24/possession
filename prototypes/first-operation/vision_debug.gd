extends MeshInstance3D

# Render-only vision frustum. It has no collision, gameplay query, or shadow.
func setup(range_m: float,fov_degrees: float,tint: Color,eye_height: float) -> void:
	var cone=CylinderMesh.new();cone.height=range_m;cone.top_radius=tan(deg_to_rad(fov_degrees*.5))*range_m;cone.bottom_radius=.08;cone.radial_segments=20;cone.rings=1;mesh=cone
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color(tint,.12);material.emission_enabled=true;material.emission=Color(tint,.45);material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.no_depth_test=true;material_override=material
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position=Vector3(0,eye_height,-range_m*.5);rotation.x=-PI*.5
