shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(0.58,0.30,1.0,0.08);
varying vec3 pos;
void vertex(){pos=VERTEX;}
void fragment(){float band=0.85+0.15*sin(pos.y*45.0-TIME*1.2);ALBEDO=tint.rgb;ALPHA=tint.a*band;}
