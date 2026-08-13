shader_type spatial;
render_mode unshaded, cull_disabled;
// Rim wall: flat structural grey, sun-lit, with the same manual distance haze the terrain
// uses (fade to sky_color) so distant wall sections dissolve into the sky consistently.

uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform float haze_density = 0.000008;
uniform vec3 sky_color = vec3(0.45, 0.62, 0.82);
uniform vec3 wall_color = vec3(0.58, 0.60, 0.64);

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_world_normal);
	if (!FRONT_FACING) { n = -n; }
	float diffuse = max(dot(n, normalize(to_sun)), 0.0);
	// BOUNCE, not just sun. The inner face of the rim looks out across the entire lit ring floor,
	// which is an enormous area light -- so when the sun is behind the wall it is not black, it is
	// filled by the world in front of it. At a 0.15 ambient floor it rendered as a featureless black
	// slab cutting the horizon in half, which reads far heavier than the wall actually is.
	vec3 lit = wall_color * (0.42 + 0.58 * diffuse);
	// Faint strata so the surface has SCALE. A flat tone gives the eye nothing to judge distance or
	// size against, which is part of why the rim felt so dominating: it read as a void, not a cliff.
	float band = sin(v_world_pos.y * 0.0055) * 0.5 + 0.5;
	lit *= 0.94 + 0.06 * band;
	float dist = length(v_world_pos - CAMERA_POSITION_WORLD);
	float fog = 1.0 - exp(-haze_density * dist);
	ALBEDO = mix(lit, sky_color, fog);
}
