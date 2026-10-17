extends SceneTree
func _initialize() -> void:
 var importer=preload("res://world/content_gallery.gd").new()
 for name in ["doom-plasma.glb","halo-ce-plasma.glb"]:
  var m=importer.import_source(ProjectSettings.globalize_path("res://../assets/"+name).simplify_path())
  print(name," INITIAL ",m.transform," bounds ",importer.model_bounds(m))
  m.rotation.y=PI*.5
  var b: AABB=importer.model_bounds(m)
  m.scale=Vector3.ONE*(.60/maxf(b.size.z,.001))
  b=importer.model_bounds(m)
  m.position=Vector3(-.06,-.04,-.08)-b.get_center()
  print(" FINAL ",m.transform," bounds ",importer.model_bounds(m))
  m.free()
 importer.contact_debug.free();importer.free();quit()
