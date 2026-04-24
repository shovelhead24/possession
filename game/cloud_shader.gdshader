shader_type spatial;
render_mode cull_disabled;

uniform float cloud_base : hint_range(0.0, 5000.0) = 1500.0;
uniform float cloud_top  : hint_range(0.0, 5000.0) = 2000.0;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float h = clamp((world_y - cloud_base) / max(cloud_top - cloud_base, 1.0), 0.0, 1.0);
	ALBEDO = mix(vec3(0.0, 0.5, 1.0), vec3(1.0, 0.0, 0.0), h);  // blue bottom, red top — unmissable
}
