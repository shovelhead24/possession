// Exact arena zero-surface recipe, ported from the frozen expanded_field.
// Divisor is experimental, not a mathematical safety certificate.
uniform int max_steps=4096;
uniform float step_divisor=8.0;
uniform float tunnel_radius=3.2;
uniform float terrain_detail=0.35;
uniform bool show_failures=true;
float sdf_box(vec3 p,vec3 b){vec3 q=abs(p)-b;return length(max(q,vec3(0.0)))+min(max(q.x,max(q.y,q.z)),0.0);}
float pad(vec2 p,vec2 c,vec2 b){vec2 q=abs(p-c)-b;return 1.0-smoothstep(0.0,14.0,max(q.x,q.y));}
float height_at(vec2 p){
 float broad=smoothstep(70.0,125.0,length(p));
 float h=.35*sin(p.x*.04)*cos(p.y*.05);
 h+=broad*(2.5*sin(p.x*.014)*cos(p.y*.017)+36.0*exp(-dot((p-vec2(145,-140))/vec2(72,78),(p-vec2(145,-140))/vec2(72,78)))+34.0*exp(-dot((p-vec2(-245,145))/vec2(75,82),(p-vec2(-245,145))/vec2(75,82)))+22.0*exp(-dot((p-vec2(220,230))/vec2(90,65),(p-vec2(220,230))/vec2(90,65))));
 h+=46.0*exp(-dot((p-vec2(450,430))/vec2(115,105),(p-vec2(450,430))/vec2(115,105)));
 h+=50.0*exp(-dot((p-vec2(-500,-430))/vec2(125,95),(p-vec2(-500,-430))/vec2(125,95)));
 h-=15.0*(1.0-smoothstep(12.0,35.0,abs(p.x-440.0-20.0*sin(p.y*.009))))*smoothstep(170.0,260.0,p.y)*(1.0-smoothstep(610.0,680.0,p.y));
 float cx=-140.0+18.0*sin(p.y*.012);
 h-=18.0*(1.0-smoothstep(9.0,24.0,abs(p.x-cx)))*smoothstep(-300.0,-265.0,p.y)*(1.0-smoothstep(255.0,300.0,p.y));
 float ramps=(1.0-smoothstep(12.0,20.0,abs(p.y+80.0)))*(1.0-smoothstep(42.0,80.0,abs(p.x+154.0)))*smoothstep(22.0,34.0,abs(p.x+154.0));
 h=mix(h,10.0,ramps);
 h=mix(h,2.0,pad(p,vec2(-30,180),vec2(32,30)));
 h=mix(h,5.0,pad(p,vec2(65,-195),vec2(43,34)));
 h=mix(h,1.5,pad(p,vec2(-363,145),vec2(10)));
 h=mix(h,1.5,pad(p,vec2(-127,145),vec2(10)));
 h=mix(h,1.5,pad(p,vec2(145,-250),vec2(10)));
 h=mix(h,1.5,pad(p,vec2(145,-30),vec2(10)));
 return h*(1.0-smoothstep(688.0,766.0,max(abs(p.x),abs(p.y))));
}
float arena_field(vec3 p){
 float ground=p.y-height_at(p.xz);
 float west=max(length(vec2(p.y-8.0,p.z-145.0))-7.0,abs(p.x+245.0)-120.0);
 float east=max(length(vec2(p.x-145.0,p.y-8.0))-6.0,abs(p.z+140.0)-110.0);
 ground=max(ground,max(-west,-east));
 float ridge=(length((p-vec3(-10,2,14))/vec3(19,10,8))-1.0)*8.0;
 ridge+=terrain_detail*sin(p.x*.65)*sin(p.y*.8)*cos(p.z*.5);
 ridge=max(ridge,-(length(vec2(p.x+10.0,p.y-3.0))-tunnel_radius));
 float cover=(length((p-vec3(25,1,8))/vec3(8,5,6))-1.0)*5.0;
 float ledge=sdf_box(p-vec3(-39,1.5,33),vec3(10,1.5,8));
 float bridge=sdf_box(p-vec3(-154,8,-80),vec3(42,2,10));
 bridge=min(bridge,sdf_box(p-vec3(-186,-5,-80),vec3(3,15,10)));
 bridge=min(bridge,sdf_box(p-vec3(-122,-5,-80),vec3(3,15,10)));
 return min(ground,min(bridge,min(ridge,min(cover,ledge))));
}
vec3 field_normal(vec3 p){float e=.03;return normalize(vec3(arena_field(p+vec3(e,0,0))-arena_field(p-vec3(e,0,0)),arena_field(p+vec3(0,e,0))-arena_field(p-vec3(0,e,0)),arena_field(p+vec3(0,0,e))-arena_field(p-vec3(0,0,e))));}
