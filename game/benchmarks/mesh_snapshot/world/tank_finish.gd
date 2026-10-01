extends RefCounted
static func apply(model: Node3D) -> void:
	var paint=StandardMaterial3D.new();paint.albedo_color=Color(.19,.23,.13);paint.metallic=.18;paint.roughness=.42
	var noise=FastNoiseLite.new();noise.frequency=.035
	var texture=NoiseTexture2D.new();texture.width=256;texture.height=256;texture.noise=noise;texture.seamless=true
	var ramp=Gradient.new();ramp.set_color(0,Color(.85,.85,.85));ramp.set_color(1,Color(1,1,1));texture.color_ramp=ramp;paint.albedo_texture=texture
	var rubber=StandardMaterial3D.new();rubber.albedo_color=Color(.035,.04,.037);rubber.roughness=.93
	var steel=StandardMaterial3D.new();steel.albedo_color=Color(.14,.16,.15);steel.metallic=.75;steel.roughness=.5
	var stack=[model]
	while not stack.is_empty():
		var node=stack.pop_back()
		if node is MeshInstance3D:
			var label=String(node.name).to_lower()
			var mat=paint
			if "palette" in label or "wheel" in label: mat=rubber
			elif "gun" in label or "hook" in label or "exhaust" in label or "suspension" in label: mat=steel
			node.material_override=mat
		for child in node.get_children(): stack.append(child)
