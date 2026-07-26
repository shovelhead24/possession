shader_type spatial;
render_mode cull_back;
// Vertex heightmap displacement to measure vertex-texture-fetch cost on Intel UHD — the
// operation a geometry clipmap depends on. Toggle via do_disp to isolate its cost.

uniform sampler2D heightmap;
uniform float disp = 120.0;
uniform bool do_disp = true;

varying float v_h;

void vertex() {
	if (do_disp) {
		float h = texture(heightmap, UV).r;   // vertex texture fetch
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
