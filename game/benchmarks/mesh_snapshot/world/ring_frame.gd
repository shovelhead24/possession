extends RefCounted
## Ring coordinates are metres: arc (spinward), altitude (inward), lateral (+Z).
## Scalars retain double precision; Vector3 is used only at the rendering boundary.
## Circumference and width follow .decisions/world.md.
const CIRCUMFERENCE := 3_000_000.0
const WIDTH := 50_000.0

static func position(arc: float, altitude: float, lateral: float, radius: float = CIRCUMFERENCE / TAU) -> Vector3:
	var theta := arc / radius
	var radial := radius - altitude
	# Stable near theta=0: avoid subtracting two almost-equal radii.
	return Vector3(radial * sin(theta), altitude + 2.0 * radial * pow(sin(theta * 0.5), 2.0), lateral)

static func coordinates(point: Vector3, radius: float = CIRCUMFERENCE / TAU) -> Vector3:
	return Vector3(atan2(point.x, radius - point.y) * radius,
		radius - sqrt(float(point.x) * point.x + pow(radius - point.y, 2.0)), point.z)

static func up(arc: float, radius: float = CIRCUMFERENCE / TAU) -> Vector3:
	return Vector3(-sin(arc / radius), cos(arc / radius), 0.0)

static func sun_direction(phase: float, tilt: float) -> Vector3:
	return Vector3(sin(phase), cos(phase) * cos(tilt), cos(phase) * sin(tilt))

static func relative_position(arc: float, altitude: float, lateral: float,
		origin_arc: float, origin_altitude: float, origin_lateral: float,
		radius: float = CIRCUMFERENCE / TAU) -> Vector3:
	# Evaluate in the origin's tangent frame BEFORE conversion to float32.
	var delta := wrapf(arc - origin_arc, -PI * radius, PI * radius) / radius
	var radial := radius - altitude
	return Vector3(radial * sin(delta),
		altitude - origin_altitude + 2.0 * radial * pow(sin(delta * 0.5), 2.0),
		lateral - origin_lateral)
