shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D satellite : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 home_origin;
uniform vec2 home_span;
varying vec2 ground_uv;

void vertex() {
	vec3 point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_uv = home_origin + vec2(point.x, -point.z) / home_span;
}

void fragment() {
	ALBEDO = texture(satellite, ground_uv).rgb;
	ROUGHNESS = 1.0;
}
