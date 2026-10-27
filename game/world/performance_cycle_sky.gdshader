shader_type sky;
#include "res://world/performance_planet.gdshaderinc"
#include "res://world/performance_stars.gdshaderinc"
uniform vec3 local_up=vec3(0,1,0);
uniform float weather_overcast=0.0;
uniform vec3 sky_tint=vec3(1.0);
uniform vec3 sun_direction=vec3(0,1,0);
uniform bool cycle_enabled=false;
void sky(){
 vec3 view=normalize(EYEDIR);vec3 up_axis=normalize(local_up);
 float up=dot(view,up_axis);
 COLOR=mix(vec3(0.62,0.74,0.86),vec3(0.24,0.28,0.43),smoothstep(-0.03,0.9,up))*sky_tint;
 COLOR=mix(COLOR,vec3(0.42,0.48,0.52)*sky_tint,weather_overcast);
 COLOR+=ring_stars(view,up)*(1.0-weather_overcast);
 if(cycle_enabled){
  float sun_height=dot(normalize(sun_direction),up_axis);
  float facing=max(0.0,dot(view,normalize(sun_direction)));
  float dusk=(1.0-smoothstep(0.05,0.4,abs(sun_height)))*smoothstep(-0.2,0.03,sun_height);
  COLOR+=vec3(0.7,0.22,0.05)*pow(facing,12.0)*exp(-abs(up)*5.0)*dusk;
  float disk=smoothstep(0.99992,0.99996,facing)*smoothstep(-0.03,0.0,sun_height);
  COLOR+=(1.0-weather_overcast)*mix(vec3(1.0,0.28,0.05),vec3(1.0,0.95,0.8),smoothstep(0.0,0.3,sun_height))*disk;
 }
 COLOR=planet_sky(COLOR,normalize(EYEDIR),day,weather_overcast);
}
