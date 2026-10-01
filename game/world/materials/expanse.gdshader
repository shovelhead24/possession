shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D limestone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool textured = true;
uniform bool bridge_enabled = true;
uniform bool overpass_enabled = false;
uniform bool compound_floors = false;
uniform bool coarse_surface = false;
uniform sampler2D detail_mask : filter_nearest, repeat_disable;
uniform float local_extent = 384.0;
// Tile coverage in metres; limestone aspect ratio preserves the source image.
uniform float grass_metres = 2.0;
uniform float rock_metres = 3.0;
uniform vec2 stone_metres = vec2(1.656, 1.27144);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 n, vec3 w, vec2 metres) {
	vec3 s = mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), n));
	return texture(tex, vec2(-s.x * p.z, p.y) / metres) * w.x
		+ texture(tex, vec2(p.x, -s.y * p.z) / metres) * w.y
		+ texture(tex, vec2(s.z * p.x, p.y) / metres) * w.z;
}

// Project tangent perturbations into world space. A flat normal map leaves
// the original mesh normal unchanged, including on undersides and blends.
vec3 detail_normal(sampler2D tex, vec3 p, vec3 n, vec3 w, float metres) {
	vec3 s = mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), n));
	vec2 x = texture(tex, vec2(-s.x * p.z, p.y) / metres).rg * 2.0 - 1.0;
	vec2 y = texture(tex, vec2(p.x, -s.y * p.z) / metres).rg * 2.0 - 1.0;
	vec2 z = texture(tex, vec2(s.z * p.x, p.y) / metres).rg * 2.0 - 1.0;
	vec3 bump = vec3(0.0, x.y, -s.x * x.x) * w.x
		+ vec3(y.x, 0.0, -s.y * y.y) * w.y
		+ vec3(s.z * z.x, z.y, 0.0) * w.z;
	return normalize(n + 0.55 * (bump - n * dot(bump, n)));
}

float bridge_field(vec3 p) {
	vec3 q = abs(p - vec3(-65.0, 6.0, 45.0)) - vec3(28.0, 10.0, 10.0);
	float block = length(max(q, vec3(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
	float arch = (length(vec2((p.x + 65.0) / 18.0, (p.y - 1.0) / 11.0)) - 1.0) * 11.0;
	return max(block, -arch);
}

void fragment() {
	vec3 p = world_position;
	if (coarse_surface && texture(detail_mask,(p.xz+vec2(local_extent))/(2.0*local_extent)).r > 0.5) { discard; }
	// The two recovered buildings retain floors at their original terrain datum.
	// Reserve those footprints visually to prevent coincident grass/floor surfaces.
	if (compound_floors && abs(p.y-5.0)<0.1 &&
		((abs(p.x-46.0)<6.0 && abs(p.z+197.0)<7.0) || (abs(p.x-83.0)<6.0 && abs(p.z+203.0)<7.0))) { discard; }
	vec3 n = normalize(world_normal);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	float broad = smoothstep(28.0, 60.0, length(p.xz)) * (1.5 * sin(p.x * 0.035) * cos(p.z * 0.028));
	float basin = 5.0 * exp(-dot((p.xz - vec2(45.0, -80.0)) / vec2(24.0, 28.0), (p.xz - vec2(45.0, -80.0)) / vec2(24.0, 28.0)));
	float ground_field = p.y - broad + basin;
	ROUGHNESS = 0.95;
	if (!textured) {
		ALBEDO = vec3(0.48, 0.55, 0.40);
	} else if ((bridge_enabled && bridge_field(p) < ground_field && abs(p.x + 65.0) < 29.0 && abs(p.z - 45.0) < 11.0)
		|| (overpass_enabled && abs(p.x+154.0)<44.0 && abs(p.z+80.0)<12.0 && (p.y>5.0 || abs(abs(p.x+154.0)-32.0)<3.2))) {
		ALBEDO = triplanar(limestone, p, n, w, stone_metres).rgb * (overpass_enabled ? 0.72 : 1.0);
	} else {
		float grass = smoothstep(0.55, 0.85, n.y);
		vec3 detailed = n;
		vec3 color = vec3(0.0);
		vec3 rock_detail = n;
		// Most pixels are wholly grass or rock; only sample both in transitions.
		if (grass < 1.0) {
			color = triplanar(rock_albedo, p, n, w, vec2(rock_metres)).rgb;
			ROUGHNESS = mix(triplanar(rock_roughness, p, n, w, vec2(rock_metres)).r, 0.95, grass);
			rock_detail = detail_normal(rock_normal, p, n, w, rock_metres);
			detailed = rock_detail;
		}
		if (grass > 0.0) {
			color = mix(color, triplanar(grass_albedo, p, n, w, vec2(grass_metres)).rgb, grass);
			detailed = normalize(mix(rock_detail, detail_normal(grass_normal, p, n, w, grass_metres), grass));
		}
		ALBEDO = color;
		NORMAL = normalize((VIEW_MATRIX * vec4(detailed, 0.0)).xyz);
	}
}
