## Item-specific local offset for an equipped visual prefab.
##
## Professional equipment systems usually keep the socket stable on the
## character, then store item-specific offsets here so each tool, weapon, or
## armor piece can line up with that socket.
class_name EquipmentAttachmentProfile
extends Resource

@export var slot_id := ""
@export var local_position := Vector3.ZERO
@export var local_rotation_degrees := Vector3.ZERO
@export var local_scale := Vector3.ONE


## Builds the transform used when the item is spawned under its equipment socket.
func to_transform() -> Transform3D:
	var basis := Basis.from_euler(Vector3(
		deg_to_rad(local_rotation_degrees.x),
		deg_to_rad(local_rotation_degrees.y),
		deg_to_rad(local_rotation_degrees.z)
	))
	basis = basis.scaled(_safe_scale(local_scale))
	return Transform3D(basis, local_position)


func _safe_scale(scale_value: Vector3) -> Vector3:
	if is_zero_approx(scale_value.x) or is_zero_approx(scale_value.y) or is_zero_approx(scale_value.z):
		return Vector3.ONE

	return scale_value
