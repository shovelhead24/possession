shader_type spatial;
render_mode unshaded;
// DEM near-strip: per-pixel normal perturbation baked from the full-res heightmap
// (lighting detail at data resolution even where the mesh is coarser) + a
// slope/height color ramp + Irish field patchwork. Same manual sun/haze as the band.

uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform float haze_density = 0.000012;
uniform vec3 sky_color = vec3(0.45, 0.62, 0.82);
uniform sampler2D detail_tex : filter_linear;
uniform sampler2D sat_tex : source_color, filter_linear;
uniform bool has_sat = false;
uniform sampler2D road_tex : filter_linear;
uniform bool has_roads = false;
uniform float sat_gain = 1.35;
uniform float dem_scale = 3.0;
uniform float normal_strength = 1.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 d = texture(detail_tex, UV);
	vec3 n = normalize(v_world_normal);
	if (!FRONT_FACING) { n = -n; }
	// R/G encode east/north height gradients (1.2 slope-norm at bake); exaggeration steepens them
	vec3 pert = vec3((d.r - 0.5) * 2.4, 0.0, (d.g - 0.5) * 2.4) * dem_scale * normal_strength;
	n = normalize(n + pert);
	float nl = dot(n, normalize(to_sun));
	float diffuse = max(nl, 0.0);

	float hgt = d.b * 1020.0;               // meters (pre-exaggeration — ramp uses real heights)
	float slope = length(pert.xz) / max(dem_scale, 1.0);  // material from REAL slope, not exaggerated

	vec3 sand  = vec3(0.55, 0.52, 0.40);
	vec3 grass = vec3(0.31, 0.40, 0.23);
	vec3 turf  = vec3(0.30, 0.30, 0.19);    // upland bog
	vec3 rock  = vec3(0.44, 0.40, 0.35);

	vec3 col;
	if (has_sat) {
		// real Sentinel-2 color; ramp only as fallback where the mosaic is nodata-dark
		vec3 sat = texture(sat_tex, UV).rgb * sat_gain;
		vec3 ramp = mix(grass, turf, smoothstep(180.0, 450.0, hgt));
		col = mix(ramp, sat, smoothstep(0.015, 0.05, dot(sat, vec3(0.333))));
	} else {
		col = mix(grass, turf, smoothstep(180.0, 450.0, hgt));
		col = mix(col, rock, smoothstep(0.45, 1.1, slope));
		col = mix(sand, col, smoothstep(1.0, 7.0, hgt));  // shoreline
		// field mosaic: continuous per-cell tint variation, two scales, subtle
		vec2 c1 = floor(v_world_pos.xz / 230.0);
		vec2 c2 = floor((v_world_pos.xz + vec2(87.0, 41.0)) / 520.0);
		float h1 = fract(sin(dot(c1, vec2(127.1, 311.7))) * 43758.5453);
		float h2 = fract(sin(dot(c2, vec2(269.5, 183.3))) * 43758.5453);
		float lowland = smoothstep(380.0, 120.0, hgt) * (1.0 - smoothstep(0.35, 0.8, slope));
		col *= mix(vec3(1.0), vec3(0.90 + 0.14 * h1, 0.94 + 0.10 * h2, 0.82 + 0.12 * h1), lowland);
	}

	float dist = length(v_world_pos - CAMERA_POSITION_WORLD);
	if (has_roads) {
		float road = texture(road_tex, UV).r;
		col = mix(col, vec3(0.27, 0.27, 0.285), smoothstep(0.2, 0.75, road));
	}
	// near-field micro detail (early-Xbox honesty: two hash scales, fades out by ~400 m)
	float n1 = fract(sin(dot(floor(v_world_pos.xz * 1.6), vec2(12.9898, 78.233))) * 43758.5453);
	float n2 = fract(sin(dot(floor(v_world_pos.xz * 0.4), vec2(93.9898, 67.345))) * 24634.6345);
	float near_f = 1.0 - smoothstep(120.0, 420.0, dist);
	col *= 1.0 + ((n1 - 0.5) * 0.14 + (n2 - 0.5) * 0.10) * near_f;

	vec3 lit = col * (0.05 + 0.95 * diffuse);
	float fog = 1.0 - exp(-haze_density * dist);
	ALBEDO = mix(lit, sky_color, fog);
}
