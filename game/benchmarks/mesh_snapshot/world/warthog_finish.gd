extends RefCounted

static func finish(model: Node3D, bounds: Callable) -> void:
	var paint=surface(Color(.19,.235,.13),.12,.43)
	paint.clearcoat_enabled=true;paint.clearcoat=.15;paint.clearcoat_roughness=.55
	var rubber=surface(Color(.025,.028,.027),0,.94)
	var noise=FastNoiseLite.new();noise.frequency=.14
	var grain=NoiseTexture2D.new();grain.width=128;grain.height=128;grain.noise=noise;grain.seamless=true;grain.as_normal_map=true;grain.bump_strength=.12
	rubber.normal_enabled=true;rubber.normal_texture=grain;rubber.normal_scale=.18
	var rim=surface(Color(.16,.18,.13),.65,.48)
	var steel=surface(Color(.13,.145,.16),.8,.36)
	var dark=surface(Color(.045,.05,.052),.25,.65)
	var glass=surface(Color(.15,.20,.23,.28),.05,.14);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	var lamp=surface(Color(.43,.12,.8),0,.35);lamp.emission_enabled=true;lamp.emission=Color(.43,.12,.8);lamp.emission_energy_multiplier=1.5
	var stack: Array[Node]=[model]
	while not stack.is_empty():
		var node=stack.pop_back()
		if node is MeshInstance3D:
			for i in range(node.mesh.get_surface_count()):
				var source=node.get_active_material(i)
				if not source: continue
				var key=source.resource_name.to_lower()
				var wheel=String(node.name).to_lower().begins_with("wheel")
				var mat=paint
				if "black" in key: mat=rubber if wheel else dark
				elif "green" in key: mat=rim if wheel else paint
				elif "metal" in key: mat=steel
				elif "glass" in key: mat=glass
				elif "light" in key: mat=lamp
				node.set_surface_override_material(i,mat)
		for child in node.get_children(): stack.append(child)
	var gun=model.find_child("Gun",true,false) as Node3D
	if gun:
		# Bounds and node.position are both in the gun parent's coordinates.
		var box: AABB=bounds.call(gun)
		var mount=Vector3(box.get_center().x,box.position.y,box.get_center().z)
		gun.position=mount+(gun.position-mount)*.75
		gun.scale*=.75

static func surface(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.metallic=metal;mat.roughness=rough;return mat
