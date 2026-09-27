extends RefCounted
var grid := AStarGrid2D.new()
var trex_grid := AStarGrid2D.new()
var arena: Node
var cover: Node
var cell_size := 4.0
func setup(owner_arena: Node,owner_cover: Node) -> void:
	arena=owner_arena;cover=owner_cover
	if arena.get("world_data"):
		cell_size=8.0
		for nav in [grid,trex_grid]:
			nav.clear()
			nav.region=Rect2i(-101,-331,270,345);nav.cell_size=Vector2.ONE*cell_size;nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;nav.update()
			for cell in arena.world_data.blocked:
				if nav.is_in_boundsv(Vector2i(cell)): nav.set_point_solid(Vector2i(cell))
		for cell in arena.world_data.tree_cells:
			if grid.is_in_boundsv(Vector2i(cell)): grid.set_point_solid(Vector2i(cell))
		return
	for navigation_grid in [grid,trex_grid]:
		navigation_grid.region=Rect2i(-65,-140,131,151);navigation_grid.cell_size=Vector2(4,4);navigation_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;navigation_grid.update()
	for x in range(-65,66):
		for z in range(-140,11):
			var wx=x*4.0;var wz=z*4.0;var h=arena.height_at(wx,wz)
			if absf(arena.height_at(wx+2,wz)-h)>1.6 or absf(arena.height_at(wx,wz+2)-h)>1.6 or (absf(wx)<42 and wz< -276 and wz> -338):
				for navigation_grid in [grid,trex_grid]: navigation_grid.set_point_solid(Vector2i(x,z))
	for rock in cover.rocks:
		var cell=Vector2i(roundi(rock.position.x/4),roundi(rock.position.z/4));var radius=ceili((rock.radius+2)/4)
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var c=cell+Vector2i(x,z)
				if grid.is_in_boundsv(c) and Vector2(c.x*4-rock.position.x,c.y*4-rock.position.z).length()<rock.radius+1.8:
					for navigation_grid in [grid,trex_grid]: navigation_grid.set_point_solid(c)
	var trees=arena.get_node_or_null("ArenaTrees")
	if trees:
		for tree in trees.trees:
			var cell=Vector2i(roundi(tree.position.x/4),roundi(tree.position.z/4))
			if grid.is_in_boundsv(cell): grid.set_point_solid(cell)
func open_cell(point: Vector3,ignore_trees: bool=false) -> Vector2i:
	var navigation_grid: AStarGrid2D=trex_grid if ignore_trees else grid
	var cell=bounded_cell(point,navigation_grid)
	if not navigation_grid.is_point_solid(cell): return cell
	for radius in range(1,12):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				var candidate=cell+Vector2i(x,z)
				if navigation_grid.is_in_boundsv(candidate) and not navigation_grid.is_point_solid(candidate): return candidate
	return cell
func path(a: Vector3,b: Vector3,ignore_trees: bool=false) -> Array[Vector3]:
	var navigation_grid: AStarGrid2D=trex_grid if ignore_trees else grid
	var result: Array[Vector3]=[];var start=open_cell(a,ignore_trees);var end=open_cell(b,ignore_trees)
	if navigation_grid.is_point_solid(start) or navigation_grid.is_point_solid(end): return result
	for point in navigation_grid.get_point_path(start,end,true): result.append(Vector3(point.x,arena.height_at(point.x,point.y),point.y))
	return result
func is_blocked(point: Vector3,ignore_trees: bool=false) -> bool:
	var navigation_grid: AStarGrid2D=trex_grid if ignore_trees else grid
	var cell=bounded_cell(point,navigation_grid)
	return navigation_grid.is_point_solid(cell)

func bounded_cell(point: Vector3,nav: AStarGrid2D) -> Vector2i:
	return Vector2i(clampi(roundi(point.x/cell_size),nav.region.position.x,nav.region.end.x-1),clampi(roundi(point.z/cell_size),nav.region.position.y,nav.region.end.y-1))
