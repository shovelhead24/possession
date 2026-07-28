shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
// Cloud cards: flat quads lying just above the player (see ring_clouds.gd), alpha-cut from a shared
// noise texture. coverage/softness are per-TYPE uniforms (cirrus/cumulus/overcast) so one texture
// serves every type -- density/scale differences come from how the cards are scattered, not the art.

uniform sampler2D cloud_tex : source_color, filter_linear;
uniform float coverage : hint_range(0.0, 1.0) = 0.5;
uniform float softness : hint_range(0.01, 0.5) = 0.3;
uniform float day : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float raw = texture(cloud_tex, UV).r;
	float a = smoothstep(1.0 - coverage - softness, 1.0 - coverage + softness, raw);
	vec3 day_col = vec3(0.92, 0.94, 0.97);
	vec3 night_col = vec3(0.05, 0.06, 0.09);
	ALBEDO = mix(night_col, day_col, day);
	ALPHA = a;
}
