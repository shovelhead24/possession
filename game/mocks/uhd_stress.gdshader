shader_type spatial;
render_mode cull_back;
// Vertex heightmap displacement to measure vertex-texture-fetch cost on Intel UHD — the
// operation a geometry clipmap depends on. Toggle via do_disp to isolate its cost.

uniform sampler2D heightmap;
uniform float disp = 120.0;
uniform float terrain_size = 2000.0;
uniform bool do_disp = true;

varying float v_h;

void vertex() {
	// sample by WORLD position so tiled and one-mesh sample the same field (fair comparison,
	// and no per-tile UV repeat). XZ is unaffected by the Y displacement below.
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = world.xz / terrain_size + vec2(0.5);
	if (do_disp) {
		float h = texture(heightmap, uv).r;   // vertex texture fetch
		VERTEX.y += h * disp;
		v_h = h;
	} else {
		v_h = 0.5;
	}
}

void fragment() {
	ALBEDO = mix(vec3(0.28, 0.36, 0.22), vec3(0.5, 0.5, 0.48), smoothstep(0.4, 0.8, v_h));
	ROUGHNESS = 0.95;
}
