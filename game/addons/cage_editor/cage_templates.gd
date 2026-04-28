class_name CageTemplates
extends RefCounted

# Each template returns [PackedVector3Array, Array of PackedInt32Array].
# Faces use outward-facing CCW winding.

static func head() -> Array:
	var v := PackedVector3Array([
		# Front face
		Vector3(-0.38,  0.62,  0.42),  # 0 front top-left    (temple)
		Vector3( 0.38,  0.62,  0.42),  # 1 front top-right   (temple)
		Vector3( 0.40, -0.25,  0.40),  # 2 front bot-right   (jaw)
		Vector3(-0.40, -0.25,  0.40),  # 3 front bot-left    (jaw)
		# Back face
		Vector3(-0.36,  0.65, -0.40),  # 4 back top-left
		Vector3( 0.36,  0.65, -0.40),  # 5 back top-right
		Vector3( 0.38, -0.22, -0.38),  # 6 back bot-right
		Vector3(-0.38, -0.22, -0.38),  # 7 back bot-left
	])
	var f: Array = [
		PackedInt32Array([0, 3, 2, 1]),  # front
		PackedInt32Array([5, 6, 7, 4]),  # back
		PackedInt32Array([4, 0, 1, 5]),  # top
		PackedInt32Array([3, 7, 6, 2]),  # bottom (jaw underside)
		PackedInt32Array([1, 2, 6, 5]),  # right
		PackedInt32Array([4, 7, 3, 0]),  # left
	]
	return [v, f]

static func hand() -> Array:
	# Flattened palm shape — fingers emerge from subdivision
	var v := PackedVector3Array([
		Vector3(-0.50,  0.08,  0.14),  # 0
		Vector3( 0.50,  0.08,  0.14),  # 1
		Vector3( 0.50, -0.80,  0.10),  # 2
		Vector3(-0.50, -0.80,  0.10),  # 3
		Vector3(-0.50,  0.08, -0.14),  # 4
		Vector3( 0.50,  0.08, -0.14),  # 5
		Vector3( 0.50, -0.80, -0.10),  # 6
		Vector3(-0.50, -0.80, -0.10),  # 7
	])
	var f: Array = [
		PackedInt32Array([0, 3, 2, 1]),
		PackedInt32Array([5, 6, 7, 4]),
		PackedInt32Array([4, 0, 1, 5]),
		PackedInt32Array([3, 7, 6, 2]),
		PackedInt32Array([1, 2, 6, 5]),
		PackedInt32Array([4, 7, 3, 0]),
	]
	return [v, f]

static func foot() -> Array:
	# Wedge — thicker at heel, tapered at toe
	var v := PackedVector3Array([
		Vector3(-0.24,  0.14,  0.52),  # 0 toe top-left
		Vector3( 0.24,  0.14,  0.52),  # 1 toe top-right
		Vector3( 0.26, -0.06,  0.52),  # 2 toe bot-right
		Vector3(-0.26, -0.06,  0.52),  # 3 toe bot-left
		Vector3(-0.20,  0.30, -0.48),  # 4 heel top-left
		Vector3( 0.20,  0.30, -0.48),  # 5 heel top-right
		Vector3( 0.20, -0.08, -0.48),  # 6 heel bot-right
		Vector3(-0.20, -0.08, -0.48),  # 7 heel bot-left
	])
	var f: Array = [
		PackedInt32Array([0, 3, 2, 1]),
		PackedInt32Array([5, 6, 7, 4]),
		PackedInt32Array([4, 0, 1, 5]),
		PackedInt32Array([3, 7, 6, 2]),
		PackedInt32Array([1, 2, 6, 5]),
		PackedInt32Array([4, 7, 3, 0]),
	]
	return [v, f]

static func torso() -> Array:
	# Wider at shoulders, narrower at hips
	var v := PackedVector3Array([
		Vector3(-0.58,  0.80,  0.24),  # 0 shoulder front-left
		Vector3( 0.58,  0.80,  0.24),  # 1 shoulder front-right
		Vector3( 0.42, -0.80,  0.20),  # 2 hip front-right
		Vector3(-0.42, -0.80,  0.20),  # 3 hip front-left
		Vector3(-0.56,  0.80, -0.22),  # 4 shoulder back-left
		Vector3( 0.56,  0.80, -0.22),  # 5 shoulder back-right
		Vector3( 0.40, -0.80, -0.18),  # 6 hip back-right
		Vector3(-0.40, -0.80, -0.18),  # 7 hip back-left
	])
	var f: Array = [
		PackedInt32Array([0, 3, 2, 1]),
		PackedInt32Array([5, 6, 7, 4]),
		PackedInt32Array([4, 0, 1, 5]),
		PackedInt32Array([3, 7, 6, 2]),
		PackedInt32Array([1, 2, 6, 5]),
		PackedInt32Array([4, 7, 3, 0]),
	]
	return [v, f]
