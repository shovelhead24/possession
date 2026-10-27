shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_height : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_straw : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_tussocks : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D landscape_character : filter_linear_mipmap, repeat_disable;
uniform sampler2D landscape_variation : filter_linear_mipmap, repeat_disable;
uniform sampler2D ground_breakup : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D track_mask : filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool tracks_enabled=false;
uniform float tile_metres=1.0;
uniform int grass_sample=0;
uniform float snow_start=900.0;
uniform float snow_full=1050.0;
varying vec3 p;
varying float terrain_height;
void vertex(){p=VERTEX;terrain_height=UV2.x;}
void fragment(){
 float d=length(VERTEX);
 float fine=1.0-smoothstep(8.0,35.0,d);
 vec3 patches=texture(landscape_variation,UV/4800.0+vec2(.5)).rgb;
 vec3 clumps=texture(ground_breakup,UV/512.0).rgb;
 vec4 character=texture(landscape_character,UV/4800.0+vec2(.5));
 float dry=clamp(1.0-smoothstep(.25,.7,character.g)+(clumps.g-.5)*.25,0.0,1.0);
 if(grass_sample==1){dry=1.0;}
 if(grass_sample==2){dry=0.0;}
 vec3 straw=texture(dry_straw,UV/tile_metres).rgb;
 vec3 tussocks=texture(dry_tussocks,UV/tile_metres).rgb;
 // Coarsest mip supplies the actual asset's mean colour, not enlarged blades.
 vec3 mean_straw=textureLod(dry_straw,vec2(.5),10.0).rgb;
 vec3 mean_tussocks=textureLod(dry_tussocks,vec2(.5),10.0).rgb;
 vec3 mean_colour=mix(mean_tussocks,mean_straw,dry);
 vec3 close_colour=mix(tussocks,straw,dry);
 float blade_value=dot(close_colour,vec3(.299,.587,.114))/max(dot(mean_colour,vec3(.299,.587,.114)),.02);
 // Muted meadow palette; preserve strand contrast without the luminous yellow.
 vec3 palette=mix(vec3(.055,.16,.045),vec3(.32,.255,.135),dry);
 float damp=character.r;
 palette=mix(palette,vec3(.057,.079,.036),damp*.75);
 float bare=smoothstep(.38,.7,clumps.g)*(.4+.6*(1.0-character.a));
 palette=mix(palette,vec3(.115,.092,.062),bare*.65);
 float small_patch=texture(ground_breakup,UV/217.0+vec2(.17,.63)).r;
 palette=mix(palette,vec3(.18,.135,.075),smoothstep(.48,.66,small_patch)*dry*.5);
 palette=mix(palette,vec3(.38,.32,.19),smoothstep(.51,.7,clumps.r)*dry*.45);
 vec3 vegetation=palette*mix(1.0,clamp(blade_value,.35,2.2),fine);
 // Clumps and bare patches bridge individual blades and landscape-scale colour.
 float middle=1.0+(clumps.r-.5)*.35+(clumps.g-.5)*.4+(clumps.b-.5)*.2;
 vegetation*=middle*mix(.82,1.12,character.a);
 // Broad patches are present near and far so the blend has no moving colour ring.
 float patch_value=clamp((patches.r-.5)*.7+(patches.g-.5)*.7+(patches.b-.5)*.5,-.45,.4);
 vegetation*=1.0+patch_value;
 vegetation*=mix(vec3(.82,.92,.72),vec3(1.08,1.0,.89),smoothstep(.3,.7,patches.g));
 vegetation*=mix(.88,1.12,COLOR.a);
 vec3 n=normalize(NORMAL);
 // Choose projections from the actual surface, avoiding stretched cliff bands.
 vec3 terrain_point=vec3(UV.x,terrain_height,UV.y);
 vec3 face=abs(normalize(cross(dFdx(terrain_point),dFdy(terrain_point))));
 vec3 weights=pow(face,vec3(4.0));weights/=max(dot(weights,vec3(1.0)),.0001);
 vec3 stone=texture(rock,terrain_point.yz/4.0).rgb*weights.x;
 stone+=texture(rock,terrain_point.xz/4.0).rgb*weights.y;
 stone+=texture(rock,terrain_point.xy/4.0).rgb*weights.z;
 float sv=dot(stone,vec3(.299,.587,.114));
 // Slow, irregular coordinate warping breaks repeated rows without a moving pattern.
 vec3 warped=terrain_point+(patches.gbr-.5)*140.0+(clumps.bgb-.5)*18.0;
 vec3 broad_stone=texture(rock,vec2(warped.y*.8+warped.z*.6,warped.z*.8-warped.y*.6)/53.0).rgb*weights.x;
 broad_stone+=texture(rock,vec2(warped.x*.6-warped.z*.8,warped.x*.8+warped.z*.6)/71.0).rgb*weights.y;
 broad_stone+=texture(rock,vec2(warped.x*.8+warped.y*.6,warped.y*.8-warped.x*.6)/61.0+vec2(.31,.57)).rgb*weights.z;
 float crags=texture(ground_breakup,warped.xy/512.0).g*weights.z+texture(ground_breakup,warped.yz/512.0).g*weights.x+clumps.g*weights.y;
 float broad_value=dot(broad_stone,vec3(.299,.587,.114));
 float strata=mix(clumps.b,patches.r,.45);
 vec3 rock_color=mix(vec3(.095,.105,.105),vec3(.26,.245,.205),smoothstep(.22,.78,strata));
 rock_color*=clamp(broad_value/.23,.6,1.5)*mix(.8,1.2,crags);
 rock_color*=mix(1.0,clamp(sv/.23,.45,1.8),fine);
 float rock_weight=clamp(max(COLOR.g,character.b)+(clumps.g-.5)*.32*smoothstep(.1,.6,character.b),0.0,1.0);
 vec3 soil=mix(vegetation,rock_color,rock_weight);
 float track=0.0;
 if(tracks_enabled){
  vec2 track_uv=(UV-vec2(-32.0,-900.0))/vec2(64.0,240.0);
  float inside=step(0.0,track_uv.x)*step(track_uv.x,1.0)*step(0.0,track_uv.y)*step(track_uv.y,1.0);
  track=texture(track_mask,track_uv).r*inside*(1.0-rock_weight);
 }
 soil=mix(soil,vec3(.08,.062,.038)*mix(.75,1.25,clumps.r),track*.72);
 float snow=COLOR.b*smoothstep(snow_start,snow_full,terrain_height);
 ALBEDO=mix(soil,vec3(.78,.82,.84),snow);
 // The new dry samples have no matching height maps: keep their colour intact.
 // Procedural clump/crag relief; this is not a height map recovered from the albedo.
 float middle_fade=1.0-smoothstep(100.0,450.0,d);
 float crag_fade=1.0-smoothstep(400.0,1600.0,d);
 float relief=(sv*.025*rock_weight*fine+clumps.r*.12*(1.0-rock_weight)*middle_fade+crags*.65*rock_weight*crag_fade-track*.045*middle_fade)*(1.0-snow);
 vec3 q0=dFdx(VERTEX);vec3 q1=dFdy(VERTEX);
 vec3 r0=cross(q1,n);vec3 r1=cross(n,q0);
 float determinant=dot(q0,r0);
 vec3 gradient=(r0*dFdx(relief)+r1*dFdy(relief))*sign(determinant)/max(abs(determinant),.00001);
 NORMAL=normalize(n-gradient);
 ROUGHNESS=mix(mix(.98,.64,damp),.87,rock_weight);
 SPECULAR=mix(.06,.18,damp)*(1.0-snow);METALLIC=0.0;
}
