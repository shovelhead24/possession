global uniform vec3 ring_origin_offset;
uniform float wind_strength=0.0;
uniform float wind_gust=0.0;
uniform vec2 wind_direction=vec2(.8,.6);
uniform float wind_radius=318309.886;
uniform float wind_time=-1.0;
uniform sampler2D wind_field : filter_linear_mipmap, repeat_enable;
float wind_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float wind_noise(vec2 p){
 return textureLod(wind_field,p/32.0,0.0).g;
}
// Two travelling spatial fields plus individual response avoid repeating waves.
vec3 wind_displacement(mat4 model,float clock_time,float height_weight,float amplitude,float flutter,float variation){
 vec3 anchor=model[3].xyz+ring_origin_offset;
 float angle=atan(anchor.x,wind_radius-anchor.y);
 vec2 position=vec2(angle*wind_radius,anchor.z);
 float seed=wind_hash(floor(position*.5)+vec2(variation*23.0,variation*11.0));
 float phase=seed*6.283185;
 float t=wind_time>=0.0?wind_time:clock_time;
 float gust=wind_noise(position/85.0-wind_direction*t*.075);
 float eddy=wind_noise(position/19.0-wind_direction*t*.21+vec2(31.7,17.2));
 float swing=sin(t*(.7+seed*.55)+phase)*(.28+.32*eddy);
 float flow=wind_strength*(.18+.5*gust+wind_gust*gust*1.25+swing)*mix(.75,1.25,seed);
 vec2 direction=normalize(wind_direction+vec2(-wind_direction.y,wind_direction.x)*(eddy-.5)*.55);
 vec3 world_dir=vec3(cos(angle)*direction.x,sin(angle)*direction.x,direction.y);
 vec3 local_dir=vec3(dot(normalize(model[0].xyz),world_dir),dot(normalize(model[1].xyz),world_dir),dot(normalize(model[2].xyz),world_dir));
 float flicker=sin(t*(3.1+seed*2.3)+phase*2.1)*flutter;
 return local_dir*(flow+wind_strength*flicker)*height_weight*amplitude;
}
