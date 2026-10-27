shader_type spatial;
global uniform vec3 ring_origin_offset;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D satellite : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 home_origin;
uniform vec2 home_span;
uniform float ring_radius;
varying vec2 ground_uv;

void vertex() {
	vec3 point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz + ring_origin_offset;
	float arc = atan(point.x, ring_radius-point.y)*ring_radius;
	ground_uv = home_origin + vec2(arc, -point.z) / home_span;
}

void fragment() {
	ALBEDO = texture(satellite, ground_uv).rgb;
	ROUGHNESS = 1.0;
}
