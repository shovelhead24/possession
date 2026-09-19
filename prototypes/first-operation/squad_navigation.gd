extends RefCounted
var grid := AStarGrid2D.new()
var arena: Node
var cover: Node
func setup(owner_arena: Node,owner_cover: Node) -> void:
	arena=owner_arena;cover=owner_cover
	grid.region=Rect2i(-65,-140,131,151);grid.cell_size=Vector2(4,4);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	for x in range(-65,66):
		for z in range(-140,11):
			var wx=x*4.0;var wz=z*4.0;var h=arena.height_at(wx,wz)
			if absf(arena.height_at(wx+2,wz)-h)>1.6 or absf(arena.height_at(wx,wz+2)-h)>1.6 or (absf(wx)<42 and wz< -276 and wz> -338): grid.set_point_solid(Vector2i(x,z))
	for rock in cover.rocks:
		var cell=Vector2i(roundi(rock.position.x/4),roundi(rock.position.z/4));var radius=ceili((rock.radius+2)/4)
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var c=cell+Vector2i(x,z)
				if grid.is_in_boundsv(c) and Vector2(c.x*4-rock.position.x,c.y*4-rock.position.z).length()<rock.radius+1.8: grid.set_point_solid(c)
	var trees=arena.get_node_or_null("ArenaTrees")
	if trees:
		for tree in trees.trees:
			var cell=Vector2i(roundi(tree.position.x/4),roundi(tree.position.z/4))
			if grid.is_in_boundsv(cell): grid.set_point_solid(cell)
func open_cell(point: Vector3) -> Vector2i:
	var cell=Vector2i(clampi(roundi(point.x/4),-65,65),clampi(roundi(point.z/4),-140,10))
	if not grid.is_point_solid(cell): return cell
	for radius in range(1,12):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var candidate=cell+Vector2i(x,z)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate): return candidate
	return cell
func path(a: Vector3,b: Vector3) -> Array[Vector3]:
	var result: Array[Vector3]=[];var start=open_cell(a);var end=open_cell(b)
	if grid.is_point_solid(start) or grid.is_point_solid(end): return result
	for point in grid.get_point_path(start,end,true): result.append(Vector3(point.x,arena.height_at(point.x,point.y),point.y))
	return result
