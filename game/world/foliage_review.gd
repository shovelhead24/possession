extends Node
var arena: Node3D
var dialog: AcceptDialog
var text: Label
var sampling := false
var last_result := {}
func setup(owner_arena: Node3D, parent: Control) -> void:
	arena=owner_arena
	var button=Button.new();button.text="Forest density & performance…";parent.add_child(button)
	parent.move_child(button,3)
	button.pressed.connect(open)
	dialog=AcceptDialog.new();dialog.title="Authored forest review";dialog.size=Vector2i(620,480);add_child(dialog)
	var column=VBoxContainer.new();dialog.add_child(column)
	text=Label.new();text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size=Vector2(580,300);column.add_child(text)
	var toggle=CheckBox.new();toggle.text="Try density-based detail budget (experimental)";toggle.button_pressed=arena.painted_trees.foliage_budget.enabled;column.add_child(toggle)
	toggle.toggled.connect(func(value):
		for patch in [arena.trees,arena.painted_trees]: patch.foliage_budget.enabled=value;patch.dirty=true;patch.update_batches()
		last_result.clear();refresh())
	for action in [["Bake density cache",bake],["Measure this view (8 seconds)",measure]]:
		var b=Button.new();b.text=action[0];b.pressed.connect(action[1]);column.add_child(b)
func open() -> void:
	if sampling: return
	refresh();dialog.popup_centered()
func refresh() -> void:
	var field=arena.painted_trees.density_field
	var report=field.report()
	if not last_result.is_empty() and last_result.density_fingerprint!=field.fingerprint(): last_result.clear()
	text.text="%d authored trees · %d occupied cells · %d dense cells\nDensity is cached; tree edits update neighbouring cells.\n\nDensest areas to inspect (arc, lateral metres):\n" % [report.trees,report.occupied_cells,report.dense_cells]
	for hot in report.hotspots.slice(0,5): text.text+="  %.0f, %.0f — canopy estimate %.2f\n" % [hot.arc_m,hot.lateral_m,hot.canopy_coverage]
	text.text+="\n120 FPS target: 8.33 ms average. Measure several gameplay-height views and record a combat/walking route with F8. A density bake does not certify performance.\n"
	if not last_result.is_empty(): text.text+="\nLast editor view: %.1f FPS · %.2f ms average · %.2f ms p95\n%s" % [last_result.fps,last_result.mean_ms,last_result.p95_ms,last_result.verdict]
func write_report() -> bool:
	var report=arena.painted_trees.density_field.report()
	report["density_fingerprint"]=arena.painted_trees.density_field.fingerprint()
	report["current_editor_view"]=last_result
	report["recorded_at_utc"]=Time.get_datetime_string_from_system(true)
	report["terrain_fingerprint"]=arena.destruction.current_signature.sha256_text()
	report["construction_fingerprint"]=arena.forge.store.signature().sha256_text()
	report["gameplay_validation"]="Required: walk/drive and combat with normal shadows; editor view alone is not acceptance."
	var f=FileAccess.open(arena.painted_trees.store.path+".forest-review.json",FileAccess.WRITE)
	if not f: return false
	f.store_string(JSON.stringify(report,"  "));f.close();return true
func bake() -> void:
	if arena.painted_trees.bake_density():
		last_result.clear();refresh()
		text.text+="\nCache saved. "+("Review report saved beside the tree save." if write_report() else "Review report write failed.")
	else: text.text=arena.painted_trees.store.notice
func measure() -> void:
	if sampling: return
	if arena.painted_trees.busy() or arena.destruction.busy(): text.text="Finish tree / terrain edits before measuring.";return
	sampling=true;dialog.hide()
	var layer_visible=arena.editor.layer.visible;arena.editor.layer.hide()
	var cap=Engine.max_fps;var vsync=DisplayServer.window_get_vsync_mode()
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().create_timer(2.0).timeout
	var values=[];var began=Time.get_ticks_usec();var last=began
	while Time.get_ticks_usec()-began<6000000:
		await get_tree().process_frame
		var now=Time.get_ticks_usec();values.append((now-last)/1000.0);last=now
	Engine.max_fps=cap;DisplayServer.window_set_vsync_mode(vsync);arena.editor.layer.visible=layer_visible
	values.sort();var total=0.0
	for value in values: total+=value
	var mean=total/values.size()
	last_result={"mean_ms":mean,"fps":1000.0/mean,"p95_ms":values[mini(values.size()-1,floori(values.size()*.95))],"frames":values.size(),"density_detail_enabled":arena.painted_trees.foliage_budget.enabled,"forced_lod":arena.painted_trees.forced_lod,"viewport":str(get_viewport().get_visible_rect().size),"camera":str(arena.camera.global_transform),"adapter":RenderingServer.get_video_adapter_name(),"density_fingerprint":arena.painted_trees.density_field.fingerprint(),"verdict":"Within average target for this editor view only" if mean<=1000.0/120 else "Over frame budget — review this area"}
	sampling=false;refresh()
	text.text+="\n"+("Review report saved beside the tree save." if write_report() else "Review report write failed.")
	dialog.popup_centered()
