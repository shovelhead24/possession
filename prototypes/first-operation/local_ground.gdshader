shader_type spatial;
render_mode cull_disabled;
uniform vec3 base_color : source_color = vec3(.30,.37,.25);
varying vec3 world_position;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 float distance_m=length(world_position-CAMERA_POSITION_WORLD);
 float detail=1.0-smoothstep(18.0,75.0,distance_m);
 float grain=(noise(world_position.xz*9.0)-.5)*.12*detail;
 float patches=(noise(world_position.xz*.8)-.5)*.14;
 ALBEDO=base_color*(1.0+patches+grain);
 ROUGHNESS=.95;
}
