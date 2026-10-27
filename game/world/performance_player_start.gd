extends Node
const Ring=preload("res://world/terrain_drive_ring.gd")
var arena: Node3D
var tour: Node
var label: Label
var path: String
var operation=""
var start: Dictionary={}
var startup_checked=false
var log_clock=0.0
var restoring=false
var owns_tour=false

func setup(owner_arena: Node3D, owner_tour: Node, column: VBoxContainer):
	arena=owner_arena;tour=owner_tour
	# Keep starts with their terrain layout, including isolated benchmark layouts.
	path=arena.destruction.save_path+".player-start.json"
	load_start()
	var row=HBoxContainer.new();column.add_child(row)
	for item in [["Set player start...","save"],["Spawn here now...","spawn"],["Reset saved start","reset"]]:
		var button=Button.new();button.text=item[0];row.add_child(button)
		button.pressed.connect(arm.bind(item[1]))
	label=Label.new();column.add_child(label);refresh_label()
	var below=HBoxContainer.new();column.add_child(below)
	for item in [["Save start below view","save"],["Spawn below view now","spawn"]]:
		var button=Button.new();button.text=item[0];below.add_child(button);button.pressed.connect(below_view.bind(item[1]))
	var note=Label.new();note.text="Click terrain anywhere on the ring, or use the below-view buttons.\nSaved start applies next launch, on foot. Spawn now leaves it unchanged.\nCoordinates: arc along ring / lateral across ring, metres from world origin.";column.add_child(note)

func load_start():
	start={}
	if not FileAccess.file_exists(path):return
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("version")==1:
		for key in ["arc_m","lateral_m","height_m","yaw"]:
			if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):return
		start=data

func refresh_label():
	label.text="Start: default vehicle spawn" if start.is_empty() else "Saved start: arc %.1f m | lateral %.1f m" % [start.arc_m,start.lateral_m]

func arm(action: String):
	if action=="reset":
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path))!=OK:
			label.text="Could not remove saved start.";return
		start={};refresh_label();print("PLAYER_START_RESET");return
	operation=action;owns_tour=not tour.active;tour.begin();tour.review.dialog.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	# F1 flight may have just reached a new area. Keep collision streaming alive
	# for local placement instead of freezing an incomplete neighborhood.
	var at=Ring.coordinates(arena.camera.global_position)
	if arena.streamer.world_bounds.has_point(Vector2(at.x,at.z)):
		arena.streamer.process_mode=Node.PROCESS_MODE_INHERIT;arena.streamer.plan()
	# A small persistent prompt remains visible while the panel is closed.
	arena.on_foot.notice="Click clear ground to "+("set player start" if action=="save" else "spawn now")+"; Esc cancels."

func handle_input(event: InputEvent) -> bool:
	if restoring:return true
	if operation.is_empty():return false
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		cancel_placement();return true
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		pick_destination(event.position)
		return true
	return false

func cancel_placement():
	operation="";arena.on_foot.notice=""
	if owns_tour:tour.finish()
	tour.review.open_review()

func below_view(action: String):
	arm(action)
	await resolve_ray(arena.camera.global_position,-Ring.up_at(arena.camera.global_position))

func pick_destination(screen: Vector2):
	await resolve_ray(arena.camera.project_ray_origin(screen),arena.camera.project_ray_normal(screen))

func resolve_ray(origin: Vector3, direction: Vector3):
	restoring=true
	label.text="Preparing landing ground..."
	var hit: Dictionary=await arena.ring_landing.pick(origin,direction)
	if hit.is_empty():
		restoring=false;label.text="No ring terrain in that direction. Aim at the ground.";cancel_placement();return
	await arena.ring_landing.prepare(hit.position)
	var ground=arena.on_foot.find_ground(hit.position,4.0,200.0)
	# A mountain click may land on a steep face; search a small nearby area.
	if ground.is_empty():
		var at=Ring.coordinates(hit.position)
		for radius in [8.0,24.0,64.0,128.0]:
			for i in 8:
				var point=Ring.point(at.x+cos(i*TAU/8)*radius,at.y,at.z+sin(i*TAU/8)*radius)
				ground=arena.on_foot.find_ground(point,200.0,400.0)
				if not ground.is_empty():break
			if not ground.is_empty():break
	restoring=false
	if ground.is_empty():
		label.text="No safe standing space within 128 m. Choose a gentler slope.";cancel_placement();return
	apply_ground(ground.feet,operation)

func apply_ground(feet: Vector3, action: String) -> bool:
	var valid=arena.on_foot.find_ground(feet,1.0,2.0)
	if valid.is_empty():return false
	feet=valid.feet
	var coord=Ring.coordinates(feet)
	var forward: Vector3=-arena.camera.global_basis.z
	var yaw=Ring.tangent_yaw(feet,forward.slide(Ring.up_at(feet)).normalized())
	if action=="save":
		var record={"version":1,"arc_m":coord.x,"lateral_m":coord.z,"height_m":coord.y,"yaw":yaw}
		var file=FileAccess.open(path,FileAccess.WRITE)
		if not file:
			label.text="Could not write saved start.";cancel_placement();return false
		file.store_string(JSON.stringify(record,"\t"));file.close();start=record
		print("PLAYER_START_SAVED ",JSON.stringify(record));refresh_label()
		if owns_tour:tour.finish()
		tour.review.open_review()
	else:
		tour.finish();place_player(feet,yaw)
		print("PLAYER_SPAWN_NOW ",JSON.stringify(arena.ring_position_data()))
	operation="";arena.on_foot.notice="";return true

func place_player(feet: Vector3, yaw: float):
	if arena.editor.opened:arena.editor.toggle()
	# Float32 world positions lose centimetre precision far around the ring.
	# Give the capsule enough separation recovery and snap distance at that scale.
	var far_without_origin=feet.length()>100000.0 and not arena.floating_origin.enabled
	arena.on_foot.safe_margin=.15 if far_without_origin else .001
	arena.on_foot.floor_snap_length=.6 if far_without_origin else .3
	arena.on_foot.toss_time=0;arena.on_foot.toss_velocity=Vector3.ZERO
	arena.on_foot.activate_at(feet);arena.on_foot.yaw=yaw;arena.on_foot.pitch=0;arena.on_foot.update_camera()

func apply_saved_start():
	if start.is_empty():return
	var point=Ring.point(start.arc_m,start.height_m,start.lateral_m)
	restoring=true;tour.begin();arena.camera.global_position=point+Ring.up_at(point)*2
	await arena.ring_landing.prepare(point)
	var ground=arena.on_foot.find_ground(point,50.0,200.0)
	tour.finish();restoring=false
	if ground.is_empty():
		label.text="Saved start is obstructed or unavailable; using default.";print("PLAYER_START_REJECTED no clear ground");return
	place_player(ground.feet,start.yaw)
	print("PLAYER_START_APPLIED ",JSON.stringify(arena.ring_position_data()))

func _process(delta: float):
	if not arena.ready_to_play or not arena.loading.dismissed:return
	if not startup_checked:
		startup_checked=true;apply_saved_start()
	log_clock-=delta
	if log_clock<=0:
		log_clock=5.0;print("RING_POSITION ",JSON.stringify(arena.ring_position_data()))

