shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,blend_add,depth_draw_never;
uniform vec3 shaft_color=vec3(1.0,0.91,0.72);
uniform float strength=0.0;
void fragment(){
 float width=mix(0.03,0.48,UV.y);
 float edge=1.0-smoothstep(width*0.15,width,abs(UV.x-0.5));
 float ends=smoothstep(0.0,0.25,UV.y)*(1.0-smoothstep(0.35,1.0,UV.y));
 ALBEDO=shaft_color;ALPHA=edge*ends*strength*0.07;
}
