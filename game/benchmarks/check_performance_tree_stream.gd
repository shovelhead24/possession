extends SceneTree
## Compare the production stream method with its pre-optimization source copy.
## The fixture builds in-memory placement records; it does not load tree assets.

class CurrentPaint:
	extends "res://world/tree_paint.gd"
	var fixture_centres: Array=[]
	func stream_centres() -> Array: return fixture_centres.duplicate(true)

class ReferencePaint:
	extends "res://benchmarks/performance_reference/tree_paint.gd"
	var fixture_centres: Array=[]
	var stream_scan_calls := 0
	func stream_centres() -> Array: return fixture_centres.duplicate(true)
	func refresh_stream() -> void:
		stream_scan_calls+=1 # The reference scans by_id on every call.
		super.refresh_stream()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var current := CurrentPaint.new();root.add_child(current)
	var reference := ReferencePaint.new();root.add_child(reference)
	for paint in [current,reference]:
		for id in range(1,66): add_record(paint,id,Vector2i(0,0))
		add_record(paint,100,Vector2i(4,0))
		add_record(paint,101,Vector2i(12,0))
		add_record(paint,102,Vector2i(16,0))

	set_centres(current,[Vector2i(0,0),Vector2i(4,0)])
	set_centres(reference,[Vector2i(0,0),Vector2i(4,0)])
	current.refresh_stream();reference.refresh_stream()
	current.activate_pending();reference.activate_pending() # 64 of 65 cell-zero trees
	check_pair(current,reference,"initial partial activation")

	# Stationary stream: the current implementation skips the all-tree retirement scan.
	current.refresh_stream();reference.refresh_stream()
	check_pair(current,reference,"stationary wanted set")
	assert(current.stream_retirement_scan_count==1)
	assert(reference.stream_scan_calls==2)

	# Boundary move and teleport retire old cells and queue the newly wanted cells.
	set_centres(current,[Vector2i(4,0),Vector2i(12,0)])
	set_centres(reference,[Vector2i(4,0),Vector2i(12,0)])
	current.refresh_stream();reference.refresh_stream()
	check_pair(current,reference,"boundary move")
	current.activate_pending();reference.activate_pending()
	set_centres(current,[Vector2i(16,0)]);set_centres(reference,[Vector2i(16,0)])
	current.refresh_stream();reference.refresh_stream()
	check_pair(current,reference,"teleport")

	# Disable and re-enable exercise empty and partially filled active sets.
	current.enabled=false;reference.enabled=false
	set_centres(current,[]);set_centres(reference,[])
	current.refresh_stream();reference.refresh_stream()
	check_pair(current,reference,"disable")
	current.enabled=true;reference.enabled=true
	set_centres(current,[Vector2i(0,0)]);set_centres(reference,[Vector2i(0,0)])
	current.refresh_stream();reference.refresh_stream()
	current.activate_pending();reference.activate_pending()
	check_pair(current,reference,"re-enable partial activation")

	# New paint in an active cell keeps the invariant; out-of-stream paint forces
	# a retirement scan, matching the production 800 m picker versus 650 m stream.
	add_painted_record(current,200,Vector2i(0,0))
	add_painted_record(reference,200,Vector2i(0,0))
	current.refresh_stream();reference.refresh_stream()
	check_pair(current,reference,"paint in active cell")
	add_painted_record(current,201,Vector2i(40,0))
	add_painted_record(reference,201,Vector2i(40,0))
	current.refresh_stream();reference.refresh_stream()
	check_pair(current,reference,"paint outside active cells")

	# Erase removes metadata and its live instance from both real scripts.
	current.remove_record(200);reference.remove_record(200)
	current.refresh_stream();reference.refresh_stream()
	check_pair(current,reference,"erase")
	assert(current.stream_retirement_scan_count<reference.stream_scan_calls)
	print("PERFORMANCE_TREE_STREAM_PASS ",JSON.stringify({"reference_scans":reference.stream_scan_calls,"optimized_scans":current.stream_retirement_scan_count,"live_ids":current.by_id.keys()}))
	quit()

func add_record(paint, id: int, cell: Vector2i) -> void:
	var record := make_record(id,cell)
	paint.index_record(record,paint.store.records.size())
	paint.store.records.append(record)
	paint.store.next_id=maxi(paint.store.next_id,id+1)

func add_painted_record(paint, id: int, cell: Vector2i) -> void:
	var record := make_record(id,cell)
	var item: Dictionary=paint.make_item(record);item.valid=true
	paint.store.next_id=id
	if paint is CurrentPaint:
		paint.register_painted_item(record,item)
	else:
		paint.index_record(record,paint.store.records.size())
		paint.store.records.append(record);paint.store.next_id+=1
		paint.by_id[id]=item

func make_record(id: int, cell: Vector2i) -> Dictionary:
	return {"id":id,"x":float(cell.x*96+48),"z":float(cell.y*96+48),"height":9.0,"yaw":0.0,"species":"fixture"}

func set_centres(paint, cells: Array) -> void:
	paint.fixture_centres.clear()
	for cell: Vector2i in cells:
		paint.fixture_centres.append([Vector2(cell.x*96+48,cell.y*96+48),40.0])

func check_pair(current, reference, label: String) -> void:
	assert(current.active_cells==reference.active_cells,label+": active cells differ")
	assert(sorted_ids(current.by_id)==sorted_ids(reference.by_id),label+": live tree ids differ")
	assert(current.activation_queue==reference.activation_queue,label+": activation queues differ")

func sorted_ids(items: Dictionary) -> Array:
	var result := items.keys();result.sort();return result
