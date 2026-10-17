extends SceneTree
const Ring=preload("res://world/terrain_drive_ring.gd")
var output="C:/Users/Bran the builder/Documents/Codex/2026-10-09/let/outputs"
func _initialize():
	create_timer(180).timeout.connect(func(): push_error("Review check timeout");quit(1))
	run.call_deferred()
func run():
	var arena=load("res://world/rebuild_demo.tscn").instantiate();root.add_child(arena)
	while not arena.ready_to_play or not arena.loading.ready_to_enter: await process_frame
	assert(arena.painted_trees.store.path.contains("collision-saves"))
	assert(not arena.painted_trees.foliage_budget.enabled)
	assert(arena.painted_trees.density_field.loaded_cache)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("foliage-slice-loading.png"))
	arena.loading.close();arena.editor.toggle()
	await process_frame
	var review=arena.editor.foliage_review
	review.open();review.bake()
	var toggle=review.dialog.find_children("*","CheckBox",true,false)[0]
	toggle.button_pressed=true;assert(arena.painted_trees.foliage_budget.enabled)
	toggle.button_pressed=false;assert(not arena.painted_trees.foliage_budget.enabled)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("foliage-editor-review.png"))
	await review.measure()
	assert(not review.last_result.is_empty())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("foliage-editor-measured.png"))
	print("FOLIAGE_REVIEW_PASS: persisted field loaded, default distance policy, optional toggle, bake/report and timed review")
	quit()
