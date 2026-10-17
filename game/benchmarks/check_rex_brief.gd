extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var owner=Node.new();root.add_child(owner)
	var loading=preload("res://world/workshop_loading.gd").new();loading.brief_path="res://world/rebuild_demo_brief.json";owner.add_child(loading)
	loading.ready_to_enter=true;loading.bar.value=100;loading.status.text="Ready — review the changes, then enter."
	loading.enter.disabled=false;loading.enter.text="Enter workshop"
	for tick in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-12/ok-we-are-going-to-continue/outputs/rex-bite-fix-brief.png")
	owner.free();quit()
