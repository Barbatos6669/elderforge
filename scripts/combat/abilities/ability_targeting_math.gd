## Shared horizontal targeting math for directional equipment abilities.
class_name AbilityTargetingMath
extends RefCounted


static func is_point_in_arc(
	origin: Vector3,
	direction: Vector3,
	point: Vector3,
	radius: float,
	arc_degrees: float,
	extra_radius: float = 0.0
) -> bool:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.0001:
		return false

	var offset := point - origin
	offset.y = 0.0
	var safe_radius := maxf(radius, 0.0) + maxf(extra_radius, 0.0)
	if offset.length_squared() > safe_radius * safe_radius:
		return false
	if offset.length_squared() <= 0.0001:
		return true

	var half_arc_radians := deg_to_rad(clampf(arc_degrees, 1.0, 360.0)) * 0.5
	if half_arc_radians >= PI - 0.0001:
		return true
	return flat_direction.normalized().dot(offset.normalized()) >= cos(half_arc_radians)
