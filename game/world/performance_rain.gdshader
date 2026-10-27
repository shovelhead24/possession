shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled,blend_mix,depth_draw_never;
uniform vec3 rain_tint=vec3(1.0);
uniform float opacity=0.25;
uniform bool ground_known=false;
uniform vec3 ground_origin=vec3(0.0);
uniform vec3 ground_up=vec3(0.0,1.0,0.0);
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 if(ground_known && dot(world_position-ground_origin,ground_up)<0.05){discard;}
 ALBEDO=vec3(0.64,0.73,0.81)*rain_tint;ALPHA=opacity;
}
