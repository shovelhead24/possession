// Original ring_sky starfield, shared by both painterly backgrounds.
uniform float day = 1.0;
uniform float star_density = 260.0;
uniform float star_day_visibility = 0.4;
uniform float star_rot = 0.0;
uniform vec3 star_axis = vec3(0,0,1);
float star_hash(vec2 p) {
 vec3 p3=fract(vec3(p.xyx)*0.1031);
 p3+=dot(p3,p3.yzx+33.33);
 return fract((p3.x+p3.y)*p3.z);
}
vec3 ring_stars(vec3 dir, float up) {
 float c=cos(star_rot),s=sin(star_rot);
 vec3 axis=normalize(star_axis);
 vec3 sd=dir*c+cross(axis,dir)*s+axis*dot(axis,dir)*(1.0-c);
 vec2 grid=floor(vec2(atan(sd.x,sd.z),asin(clamp(sd.y,-1.0,1.0)))*star_density);
 float star=step(0.9975,star_hash(grid))*star_hash(grid+vec2(3.7,1.3));
 return vec3(star*mix(1.0,star_day_visibility,day)*smoothstep(-0.05,0.2,up));
}
