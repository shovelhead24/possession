extends SceneTree
const LOD=preload("res://world/runtime_mesh_lod.gd")
func _initialize() -> void:
	create_timer(90).timeout.connect(func(): push_error("Actor LOD timeout");quit(1))
	run.call_deferred()

func run() -> void:
	for path in ["res://../prototypes/first-operation/lizard_rig.glb","res://../assets/rigged-t-rex-fabulous/source/rigged_t-rex_fabulous.glb"]:
		var document := GLTFDocument.new();var state := GLTFState.new()
		assert(document.append_from_file(ProjectSettings.globalize_path(path).simplify_path(),state)==OK)
		var original := []
		for entry in state.get_meshes():
			var surfaces := []
			for surface in entry.mesh.get_surface_count(): surfaces.append(entry.mesh.get_surface_arrays(surface))
			original.append(surfaces)
		var levels := 0
		for attempt in 2:
			LOD.prepare(state,path,true)
			for index in state.get_meshes().size():
				var mesh: ImporterMesh=state.get_meshes()[index].mesh
				for surface in mesh.get_surface_count():
					assert(mesh.get_surface_arrays(surface)==original[index][surface],"Actor LOD altered full-detail vertices/weights/bones")
					levels+=mesh.get_surface_lod_count(surface)
		assert(levels>0,"Actor LOD levels missing")
		print("ACTOR_LOD_PASS ",path.get_file()," cached attributes including bones/weights unchanged; levels=",levels)
	quit()
