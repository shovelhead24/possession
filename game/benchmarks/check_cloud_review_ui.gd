extends SceneTree
class Cached extends Node3D:
	var materials=[]
	var chunks={}
	var gpu_orientation=false
	var settle=0.0
	var animation_bounds_margin=0.0
class Legacy extends Node:
	var cached: Node3D
class SkyCompare extends Node:
	var legacy: Node
	var high_painterly: MeshInstance3D
	var painted_material=ShaderMaterial.new()
	var dialog: AcceptDialog
class Backdrop extends Node:
	var _wall_mat: ShaderMaterial
	var _field_mat: ShaderMaterial
class Arena extends Node3D:
	var sky_comparison: Node
	var backdrop: Node
func _initialize():run.call_deferred()
func run():
	root.size=Vector2i(1366,768)
	var arena=Arena.new();root.add_child(arena)
	arena.sky_comparison=SkyCompare.new();arena.add_child(arena.sky_comparison)
	var sky=arena.sky_comparison;sky.legacy=Legacy.new();sky.add_child(sky.legacy)
	sky.legacy.cached=Cached.new();sky.legacy.add_child(sky.legacy.cached)
	for i in 3:sky.legacy.cached.materials.append(ShaderMaterial.new())
	sky.high_painterly=MeshInstance3D.new();arena.add_child(sky.high_painterly);sky.high_painterly.material_override=ShaderMaterial.new()
	sky.dialog=AcceptDialog.new();arena.add_child(sky.dialog);sky.dialog.add_child(VBoxContainer.new())
	arena.backdrop=Backdrop.new();arena.add_child(arena.backdrop)
	var review=preload("res://world/performance_cloud_review.gd").new();arena.add_child(review);review.setup(arena)
	for screen in [Vector2i(1366,768),Vector2i(1280,720)]:
		root.size=screen;sky.dialog.popup_centered();await process_frame
		sky.dialog.get_child(0).get_children()[-1].pressed.emit()
		await create_timer(.2).timeout
		assert(not sky.dialog.visible and review.dialog.visible)
		assert(review.dialog.size.y<root.size.y-30,"Review window must fit vertically")
		assert(review.dialog.size.x<root.size.x-30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/Bran the builder/Documents/Codex/2026-10-17/rea/outputs/cloud-review-controls-"+str(screen.y)+".png")
		print("CLOUD_UI_SIZE ",review.dialog.size," screen ",screen)
		review.dialog.hide()
	print("CLOUD_UI_PASS: launch closes parent popup; controls fit 720p and 768p");quit()
