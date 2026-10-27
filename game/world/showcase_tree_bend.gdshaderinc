#include "res://world/showcase_wind.gdshaderinc"
uniform float tree_bend_gain=1.0;
uniform float wind_flutter=0.0;
void bend_tree(inout vec3 vertex,inout vec3 normal,mat4 model,float time,float variation,float distance_m){
 float h=clamp(vertex.y,0.0,1.0);
 float far_fade=1.0-smoothstep(650.0,1600.0,distance_m);
 vec3 bend=wind_displacement(model,time,1.0,.10,0.0,variation)*tree_bend_gain*far_fade;
 bend.y=0.0;
 // One height-dependent curve for wood and foliage; roots cannot translate.
 vertex+=bend*h*h;
 normal=normalize(vec3(normal.x,normal.y-2.0*h*dot(normal.xz,bend.xz),normal.z));
 float t=wind_time>=0.0?wind_time:time;
 float tips=smoothstep(.03,.2,length(vertex.xz));
 float flutter=sin(t*3.3+variation*31.0+vertex.x*13.0+vertex.z*17.0)*wind_flutter*wind_strength*.012*h*h*tips;
 vertex.x+=flutter*(1.0-smoothstep(90.0,200.0,distance_m));
}
