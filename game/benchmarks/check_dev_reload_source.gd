extends SceneTree
const Reload=preload("res://world/rebuild_dev_reload.gd")
func write_source(path: String, value: int) -> void:
	var f=FileAccess.open(path,FileAccess.WRITE)
	f.store_string("extends RefCounted\nvar state=10\nfunc answer(): return %d\n" % value);f.close()
func _initialize():
	var path="res://benchmarks/__reload_fixture_%d.gd" % Time.get_ticks_usec()
	write_source(path,1)
	var script=load(path);var object=script.new();object.state=77
	assert(object.answer()==1)
	write_source(path,2)
	assert(Reload.reload_sources([path]).is_empty())
	assert(object.answer()==2 and object.state==77)
	write_source(path,3)
	assert(Reload.reload_sources([path]).is_empty())
	assert(object.answer()==3 and object.state==77)
	DirAccess.remove_absolute(path)
	print("PASS live method updates from disk preserve instance state")
	quit()
