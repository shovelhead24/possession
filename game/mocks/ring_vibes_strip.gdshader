shader_type spatial;
render_mode unshaded, cull_disabled;
// DEM near-strip: per-pixel normal perturbation baked from the full-res heightmap
// (lighting detail at data resolution even where the mesh is coarser) + a
// slope/height color ramp + Irish field patchwork. Same manual sun/haze as the band.

uniform vec3 to_sun = vec3(0.0, 1.0, 0.0);
uniform float haze_density = 0.000012;
uniform vec3 sky_color = vec3(0.45, 0.62, 0.82);
uniform sampler2D detail_tex : filter_linear;
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
	float slope = length(pert.xz);

	vec3 sand  = vec3(0.55, 0.52, 0.40);
	vec3 grass = vec3(0.31, 0.40, 0.23);
	vec3 turf  = vec3(0.30, 0.30, 0.19);    // upland bog
	vec3 rock  = vec3(0.44, 0.40, 0.35);

	vec3 col = mix(grass, turf, smoothstep(180.0, 450.0, hgt));
	col = mix(col, rock, smoothstep(0.9, 2.2, slope));
	col = mix(sand, col, smoothstep(1.0, 7.0, hgt));  // shoreline
	// field patchwork: hashed cells darken lowland into tillage/pasture mosaic
	vec2 cell = floor(v_world_pos.xz / 260.0);
	float hash = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float fields = step(0.55, hash) * smoothstep(400.0, 100.0, hgt) * (1.0 - smoothstep(0.7, 1.4, slope));
	col = mix(col, col * 0.62, fields * 0.8);

	vec3 lit = col * (0.05 + 0.95 * diffuse);
	float dist = length(v_world_pos - CAMERA_POSITION_WORLD);
	float fog = 1.0 - exp(-haze_density * dist);
	ALBEDO = mix(lit, sky_color, fog);
}
