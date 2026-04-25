shader_type spatial;
render_mode cull_disabled, shadows_disabled, blend_mix, depth_draw_never, unshaded;

uniform vec3  color_top    : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3  color_bottom : source_color = vec3(0.58, 0.64, 0.72);
uniform float coverage     : hint_range(0.0, 1.0) = 0.50;
uniform float softness     : hint_range(0.05, 0.5) = 0.22;

// Per-billboard UV offset derived from world position — unique pattern per chunk,
// stable against camera rotation because it's baked in the vertex shader.
varying vec2 _chunk_uv;
varying vec2 _edge_uv;

float _h2(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float _vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(_h2(i), _h2(i + vec2(1.0, 0.0)), f.x),
	           mix(_h2(i + vec2(0.0, 1.0)), _h2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float _fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * _vn(p); p *= 2.1; a *= 0.5; }
	return v;
}

void vertex() {
	// Chunk center in world XZ, scaled to spread chunks across FBM space.
	// Adjacent 512m chunks differ by 512 * 0.002 = 1.024 FBM units — distinct patterns.
	vec2 cc = MODEL_MATRIX[3].xz * 0.002;
	_chunk_uv = UV * 6.0 + cc;
	_edge_uv  = UV * 4.0 + cc + vec2(17.3, 41.7);

	// Spherical billboard: cancel rotation, keep scale + translation.
	float sx = length(MODELVIEW_MATRIX[0].xyz);
	float sy = length(MODELVIEW_MATRIX[1].xyz);
	float sz = length(MODELVIEW_MATRIX[2].xyz);
	MODELVIEW_MATRIX[0] = vec4(sx, 0.0, 0.0, MODELVIEW_MATRIX[0].w);
	MODELVIEW_MATRIX[1] = vec4(0.0, sy, 0.0, MODELVIEW_MATRIX[1].w);
	MODELVIEW_MATRIX[2] = vec4(0.0, 0.0, sz, MODELVIEW_MATRIX[2].w);
}

void fragment() {
	// Primary cloud density — drifts slowly, pattern pinned to world (not UV).
	vec2 uv = _chunk_uv + vec2(TIME * 0.003, 0.0);
	float d = _fbm(uv);
	d = smoothstep(1.0 - coverage - softness, 1.0 - coverage + softness, d);

	// Edge fade: secondary FBM breaks up the square boundary.
	// Fades out over the outer 25-35% of each edge with an organic, noisy profile.
	float edge_noise = _fbm(_edge_uv) * 0.35;
	vec2 dc = abs(UV - 0.5) * 2.0;
	float edge_dist = max(dc.x, dc.y) + edge_noise;
	float edge_fade = 1.0 - smoothstep(0.65, 1.05, edge_dist);

	ALBEDO = mix(color_bottom, color_top, d * 0.4 + 0.3);
	ALPHA  = d * edge_fade;
}
