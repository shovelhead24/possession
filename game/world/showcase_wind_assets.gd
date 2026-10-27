extends RefCounted
static func prepare(source: Mesh,level: int) -> ArrayMesh:
	var mesh=split_billboard(source) if level==3 else source.duplicate() as ArrayMesh
	for surface in mesh.get_surface_count():
		var original=mesh.surface_get_material(surface)
		var material: ShaderMaterial
		if original is ShaderMaterial:
			material=original.duplicate() as ShaderMaterial
			material.shader=preload("res://world/showcase_tree_wind.gdshader")
			material.set_shader_parameter("wind_flutter",.35 if level<3 else 0.0)
		elif original is BaseMaterial3D:
			material=ShaderMaterial.new();material.shader=preload("res://world/showcase_bark_wind.gdshader")
			material.set_shader_parameter("bark_colour",original.albedo_color)
			material.set_shader_parameter("bark_uv_scale",original.uv1_scale);material.set_shader_parameter("bark_uv_offset",original.uv1_offset)
			material.set_shader_parameter("bark_has_texture",original.albedo_texture!=null)
			if original.albedo_texture:material.set_shader_parameter("bark_tex",original.albedo_texture)
		else:continue
		mesh.surface_set_material(surface,material)
	return mesh

# Four height bands let an impostor follow the same curve as the mesh tree.
# Interpolate the original atlas UVs; never regenerate or rotate the cards.
static func split_billboard(source: Mesh) -> ArrayMesh:
	var mesh=ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays=source.surface_get_arrays(surface)
		var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count=indices.size() if indices!=null and not indices.is_empty() else vertices.size()
		for triangle in range(0,count,3):
			var polygon=[]
			for corner in 3:
				var i=indices[triangle+corner] if indices!=null and not indices.is_empty() else triangle+corner
				var v={"p":vertices[i],"n":arrays[Mesh.ARRAY_NORMAL][i],"uv":arrays[Mesh.ARRAY_TEX_UV][i]}
				polygon.append(v)
			var low=minf(polygon[0].p.y,minf(polygon[1].p.y,polygon[2].p.y))
			var high=maxf(polygon[0].p.y,maxf(polygon[1].p.y,polygon[2].p.y))
			if high-low<.00001:
				emit_polygon(st,polygon);continue
			for band in 4:
				var clipped=clip_height(polygon,band*.25,true)
				clipped=clip_height(clipped,(band+1)*.25,false)
				emit_polygon(st,clipped)
		st.index();st.commit(mesh);mesh.surface_set_material(surface,source.surface_get_material(surface))
	return mesh
static func clip_height(polygon: Array,height: float,above: bool) -> Array:
	var result=[]
	if polygon.is_empty():return result
	var previous=polygon[-1]
	var previous_inside=previous.p.y>=height if above else previous.p.y<=height
	for current in polygon:
		var inside=current.p.y>=height if above else current.p.y<=height
		if inside!=previous_inside:
			var t=(height-previous.p.y)/(current.p.y-previous.p.y)
			result.append({"p":previous.p.lerp(current.p,t),"n":previous.n.lerp(current.n,t).normalized(),"uv":previous.uv.lerp(current.uv,t)})
		if inside:result.append(current)
		previous=current;previous_inside=inside
	return result
static func emit_polygon(st: SurfaceTool,polygon: Array):
	for i in range(1,polygon.size()-1):
		if (polygon[i].p-polygon[0].p).cross(polygon[i+1].p-polygon[0].p).length_squared()<.0000000001:continue
		for v in [polygon[0],polygon[i],polygon[i+1]]:
			st.set_normal(v.n);st.set_uv(v.uv);st.add_vertex(v.p)
