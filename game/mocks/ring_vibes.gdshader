shader_type spatial;
render_mode unshaded, cull_disabled;
// reverted 2026-07-23: attempted cull_back broke rendering (winding fix was wrong direction).
// Back to known-good double-sided. Walk mode is the real fix for the underneath-disorientation issue.
// Ring vibe mock: manual N.L lighting from an in-plane sun so the terminator
// crosses the band honestly; manual distance haze with weaker extinction for
// city emission (night lights punch through — knowledge.md "air is the horizon").

uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform float haze_density = 0.000012;
uniform vec3 sky_color = vec3(0.45, 0.62, 0.82);
uniform sampler2D city_tex;
uniform float ring_width = 50000.0;
uniform float wall_ramp = 2500.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_world_normal);
	if (!FRONT_FACING) { n = -n; }
	float nl = dot(n, normalize(to_sun));
	float diffuse = max(nl, 0.0);
	float night = smoothstep(0.06, -0.06, nl);

	vec3 terrain = vec3(0.30, 0.38, 0.24);            // vague grassland
	vec3 city_mask = texture(city_tex, UV).rgb;
	vec3 albedo = mix(terrain, vec3(0.42, 0.41, 0.38), clamp(city_mask.r * 2.0, 0.0, 0.6));
	vec3 lit = albedo * (0.04 + 0.96 * diffuse);

	float dist = length(v_world_pos - CAMERA_POSITION_WORLD);
	float fog = 1.0 - exp(-haze_density * dist);
	float light_fog = 1.0 - exp(-haze_density * 0.30 * dist);

	vec3 col = mix(lit, sky_color, fog);
	col += city_mask * night * (1.0 - light_fog) * 1.4;  // emissive cities where it's dark
	ALBEDO = col;
}
