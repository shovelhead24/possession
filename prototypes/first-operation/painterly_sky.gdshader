shader_type sky;
uniform float time_seconds = 0.0;
uniform bool moving = true;
uniform vec3 horizon : source_color = vec3(0.62,0.74,0.86);
float hash(highp vec2 p){p=fract(p*vec2(123.34,345.45));p+=dot(p,p+34.345);return fract(p.x*p.y);}
float noise2(highp vec2 p){highp vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky(){
 vec3 d=normalize(EYEDIR);
 vec3 col=mix(horizon,vec3(0.16,0.12,0.29),smoothstep(-0.03,0.85,d.y));
 // Direction-based cloud appearance only; reachable ring geography is separate world geometry.
 highp vec2 p=d.xz*3.5+vec2(d.y*1.8,d.y*0.7);
 float t=moving ? time_seconds*0.0015 : 0.0;
 float mass=noise2(p+vec2(t,0.0))*0.65+noise2(p*2.0+vec2(0.0,t*0.5))*0.25+noise2(p*4.0)*0.10;
 float cloud=smoothstep(0.37,0.65,mass)*smoothstep(0.02,0.28,d.y);
 vec3 shadow=vec3(0.28,0.22,0.37);
 vec3 light=vec3(0.77,0.68,0.71);
 col=mix(col,mix(shadow,light,smoothstep(0.45,0.73,mass)),cloud*0.80);
 COLOR=col;
}
