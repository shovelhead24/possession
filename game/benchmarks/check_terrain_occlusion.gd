extends SceneTree
const Occlusion=preload("res://world/terrain_occlusion.gd")

class Arena extends Node3D:
	var camera := Camera3D.new()
	var chunks := {}
	var revision := 1
	var preview_expected := {}
	func key_at(point: Vector3) -> Vector2i:
		return Vector2i(floori(point.x/32),floori(point.z/32))

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("Occlusion test timeout");quit(1))
	run.call_deferred()

func run() -> void:
	var arena := Arena.new();root.add_child(arena);arena.add_child(arena.camera)
	var chunk := Node3D.new();arena.add_child(chunk)
	var visual := MeshInstance3D.new();visual.mesh=BoxMesh.new();chunk.add_child(visual)
	var body := StaticBody3D.new();chunk.add_child(body)
	var collision := CollisionShape3D.new();collision.shape=BoxShape3D.new();body.add_child(collision)
	var original_shape := collision.shape
	arena.chunks[Vector2i.ZERO]={"node":chunk,"revision":1}
	var helper := Occlusion.new();helper.arena=arena;arena.add_child(helper);helper.set_process(false)
	helper._process(.25)
	assert(helper.entries.size()==1)
	var stale: OccluderInstance3D=helper.entries[Vector2i.ZERO].node
	arena.preview_expected[Vector2i.ZERO]=true
	helper._process(0)
	assert(helper.entries.is_empty() and not stale.visible,"Edited terrain retained an active stale occluder")
	arena.preview_expected.clear();helper._process(.25)
	assert(helper.entries.size()==1)
	stale=helper.entries[Vector2i.ZERO].node
	visual.mesh=SphereMesh.new();helper._process(0)
	assert(helper.entries.is_empty() and not stale.visible,"Replaced mesh retained a stale occluder")
	helper._process(.25)
	assert(helper.entries.size()==1)
	stale=helper.entries[Vector2i.ZERO].node
	arena.camera.position.x=320;helper._process(0)
	assert(helper.entries.is_empty() and not stale.visible,"Distant occluder was retained")
	assert(collision.shape==original_shape and not collision.disabled,"Occlusion altered collision")
	arena.queue_free();await process_frame
	print("TERRAIN_OCCLUSION_PASS edit mesh_replacement distance_eviction collision_unchanged")
	quit()
