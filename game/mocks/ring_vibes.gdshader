shader_type spatial;
render_mode unshaded, cull_disabled;
// reverted 2026-07-23: attempted cull_back broke rendering (winding fix was wrong direction).
// Back to known-good double-sided. Walk mode is the real fix for the underneath-disorientation issue.
// Ring vibe mock: manual N.L lighting from an in-plane sun so the terminator
// crosses the band honestly; manual distance haze with weaker extinction for
// city emission (night lights punch through — knowledge.md "air is the horizon").
//
// 2026-07-28: the real compiled Millstreet satellite/roads drape now TILES across the whole far
// band (UV is world arc/lat divided by the patch's real-world size, set on the CPU in _rebuild(),
// repeat-wraps for free) — no geographic accuracy intended out here, just replacing the flat green
// ramp with real photo texture. City-light glow no longer comes from a synthetic random blob
// (city_tex, gone) — it's a coarse-mip read of the REAL road texture (local road density is a
// decent free proxy for "there's a town/junction here" without fetching real population data).

uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform float haze_density = 0.000012;
uniform vec3 sky_color = vec3(0.45, 0.62, 0.82);
uniform sampler2D sat_tex : source_color, filter_linear;
uniform bool has_sat = false;
uniform sampler2D road_tex : filter_linear;
uniform bool has_roads = false;
uniform float sat_gain = 1.35;
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

	vec3 albedo = vec3(0.30, 0.38, 0.24);   // vague grassland fallback (no DEM loaded)
	if (has_sat) {
		vec3 sat = texture(sat_tex, UV).rgb * sat_gain;
		albedo = mix(albedo, sat, smoothstep(0.015, 0.05, dot(sat, vec3(0.333))));  // ramp where nodata-dark
		if (has_roads) {
			float road = texture(road_tex, UV).r;
			albedo = mix(albedo, vec3(0.27, 0.27, 0.285), smoothstep(0.2, 0.75, road));
		}
	}
	vec3 lit = albedo * (0.20 + 0.80 * diffuse);   // floor raised again (0.04->0.14->0.20); still read too dark

	float dist = length(v_world_pos - CAMERA_POSITION_WORLD);
	float fog = 1.0 - exp(-haze_density * dist);
	float light_fog = 1.0 - exp(-haze_density * 0.30 * dist);

	vec3 col = mix(lit, sky_color, fog);
	if (has_roads) {
		float density = textureLod(road_tex, UV, 5.0).r;   // blurred road density -> "settlement" proxy
		col += vec3(1.0, 0.75, 0.4) * density * night * (1.0 - light_fog) * 1.1;  // emissive at night
	}
	ALBEDO = col;
}
