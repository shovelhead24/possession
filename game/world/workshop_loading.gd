extends CanvasLayer
## Honest phase-count progress, not a predicted duration or per-byte percentage.
const SNAPSHOT := "user://workshop-last-view.png"
const SNAPSHOT_META := "user://workshop-last-view.json"
var root: ColorRect
var bar: ProgressBar
var status: Label
var activity: RichTextLabel
var preview: TextureRect
var caption: Label
var enter: Button
var ready_to_enter := false
var dismissed := false
var capturing := false
var lines: Array[String]=[]
var last_progress := ""
var started := Time.get_ticks_msec()
var brief: Dictionary

func _ready() -> void:
	layer=100
	brief=JSON.parse_string(FileAccess.get_file_as_string("res://world/workshop_brief.json"))
	if get_parent().get("stress_course"):
		brief.title="SDF stress course — increasing spline density"
		brief.goal="F1 enters play when terrain is ready. E enters the Warthog; WASD drive, Space brakes, C changes camera. From its spawn near x=-28m, steer toward x=-14m and drive -Z beneath the bridges, through three labelled tiers to z=-604m. F8 begins/ends hitch capture. Save writes only sdf-stress-course.json."
		brief.changes="228 deterministic features are added to a copy of your workshop; the normal save stays separate. "+brief.changes
	root=ColorRect.new();root.color=Color(.025,.035,.055);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
	var margin := MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	root.add_child(margin)
	var outer := VBoxContainer.new();margin.add_child(outer)
	var scroll := ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(scroll)
	var content := VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	var title := Label.new();title.text=brief.title;title.add_theme_font_size_override("font_size",24);content.add_child(title)
	var subtitle := Label.new();subtitle.text=brief.iteration;content.add_child(subtitle)
	var row := HBoxContainer.new();content.add_child(row)
	preview=TextureRect.new();preview.custom_minimum_size=Vector2(310,175);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(preview)
	var description := Label.new();description.size_flags_horizontal=Control.SIZE_EXPAND_FILL;description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.text="TEST GOAL\n"+brief.goal+"\n\n"+brief.changes;row.add_child(description)
	caption=Label.new();caption.text="A current scene screenshot will appear when loading finishes.";content.add_child(caption)
	if FileAccess.file_exists(SNAPSHOT):
		var previous := Image.load_from_file(SNAPSHOT)
		if previous: preview.texture=ImageTexture.create_from_image(previous)
		caption.text="Previous workshop view (not a live loading preview)"
		if FileAccess.file_exists(SNAPSHOT_META):
			var meta: Variant=JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT_META))
			if meta is Dictionary: caption.text+=" / "+str(meta.get("utc",""))
	var controls := Label.new();controls.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;controls.text="CONTROLS\n"+brief.controls;content.add_child(controls)
	bar=ProgressBar.new();bar.custom_minimum_size.y=20;outer.add_child(bar)
	status=Label.new();status.text="Preparing workshop…";status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;outer.add_child(status)
	activity=RichTextLabel.new();activity.custom_minimum_size.y=70;activity.scroll_following=true;outer.add_child(activity)
	enter=Button.new();enter.text="Loading…";enter.disabled=true;enter.pressed.connect(close);outer.add_child(enter)
	log_event("Preparing this iteration. Progress measures completed work, not remaining time.")

func log_event(message: String) -> void:
	var line := "[%5.1fs] %s" % [(Time.get_ticks_msec()-started)/1000.0,message]
	lines.append(line)
	if lines.size()>60: lines.pop_front()
	activity.text="\n".join(lines)
	print("WORKSHOP_LOAD ",line)

func update_progress(terrain_done: int, terrain_total: int, imagery_done: int, imagery_total: int, sources_done: int, sources_total: int, kit_ready: bool, complete: bool) -> void:
	if ready_to_enter or capturing: return
	var estimated := 5+40.0*terrain_done/maxi(1,terrain_total)+20.0*imagery_done/maxi(1,imagery_total)+25.0*sources_done/maxi(1,sources_total)+(9 if kit_ready else 0)
	bar.value=maxf(bar.value,minf(99,estimated))
	var progress := "Terrain %d/%d chunks | Ring images %d/%d processed | Models %d/%d | %s" % [terrain_done,terrain_total,imagery_done,imagery_total,sources_done,sources_total,"Finalising" if kit_ready else "Preparing rigs / trees / weapons"]
	status.text="Approx. %d%% — %s" % [bar.value,progress]
	if progress!=last_progress: last_progress=progress;log_event(progress)
	if complete: capture_ready.call_deferred()

func capture_ready() -> void:
	if capturing or ready_to_enter: return
	capturing=true
	# Input stays gated while the unobscured viewport is captured for this brief.
	root.hide()
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.resize(640,400,Image.INTERPOLATE_LANCZOS)
	preview.texture=ImageTexture.create_from_image(shot)
	var saved := shot.save_png(SNAPSHOT)
	var utc := Time.get_datetime_string_from_system(true)+"Z"
	if saved==OK:
		var file := FileAccess.open(SNAPSHOT_META,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify({"utc":utc,"iteration":brief.iteration}));file.close()
	caption.text="Current workshop / "+utc
	ready_to_enter=true;capturing=false;bar.value=100;status.text="Ready — review the goal and controls, then enter."
	enter.text="Enter workshop";enter.disabled=false;root.show()
	log_event("Ready. Screenshot captured. F2 reopens this briefing.")

func close() -> void:
	if not ready_to_enter: return
	dismissed=true;root.hide()

func reopen() -> void:
	if not ready_to_enter: return
	dismissed=false;root.show()
