extends SceneTree
func _initialize(): run.call_deferred()
func run():
	root.size=Vector2i(1366,768)
	var loading=preload("res://world/workshop_loading.gd").new()
	loading.brief_path="res://world/rebuild_demo_brief.json";root.add_child(loading)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs/forge-snap-brief.png")
	quit()
