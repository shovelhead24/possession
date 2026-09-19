extends Node3D
var rocks: Array[Dictionary]=[]
var slots: Array[Vector3]=[]
var arena: Node
func _ready() -> void:
	name="ArenaCover";arena=get_parent()
	var rng=RandomNumberGenerator.new();rng.seed=6104
	# Cover near the squad positions, plus quieter outlying clusters.
	for cluster in [Vector2(48,-90),Vector2(112,-180),Vector2(-118,-230),Vector2(145,-370),Vector2(190,-450),Vector2(-170,-410)]:
		for i in range(9):
			var p=cluster+Vector2(rng.randf_range(-26,26),rng.randf_range(-24,24))
			if absf(p.x+65)<15 or absf(p.x-25)<9: continue
			var radius=rng.randf_range(1.5,3.0);var height=rng.randf_range(1.2,3.3)
			var center=Vector3(p.x,arena.height_at(p.x,p.y),p.y)
			var too_close=false
			for rock in rocks:
				if Vector2(rock.position.x-p.x,rock.position.z-p.y).length()<rock.radius+radius+3: too_close=true
			if too_close: continue
			var sphere=SphereMesh.new();sphere.radius=1;sphere.height=2;sphere.radial_segments=9;sphere.rings=5
			var arrays=sphere.get_mesh_arrays();var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			for j in range(vertices.size()):
				var v=vertices[j];var noise=1+.11*sin(v.x*12+v.y*7+v.z*5);vertices[j]=Vector3(v.x*radius*noise,(v.y*.5+.4)*height,v.z*radius*noise)
			arrays[Mesh.ARRAY_VERTEX]=vertices;var raw=ArrayMesh.new();raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var tool=SurfaceTool.new();tool.create_from(raw,0);tool.generate_normals();var mesh=tool.commit()
			var visual=MeshInstance3D.new();visual.mesh=mesh;visual.material_override=arena.material(Color(.28,.30,.26)*rng.randf_range(.85,1.15),0,.94);add_child(visual);visual.position=center;visual.create_convex_collision()
			rocks.append({"position":center,"radius":radius,"height":height})
			for side in range(8):
				var pos=center+Vector3(cos(side*PI/4),0,sin(side*PI/4))*(radius+1.5);pos.y=arena.height_at(pos.x,pos.z);slots.append(pos)
	print("COVER_READY: ",rocks.size()," boulders / ",slots.size()," cover positions")
func obscures(point: Vector3,threat: Vector3,exclude: Array[RID]) -> bool:
	var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.7,threat+Vector3.UP);ray.exclude=exclude
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.position.distance_to(threat)>2
