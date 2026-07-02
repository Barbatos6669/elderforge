## Named character socket for visible equipment.
##
## Add this to a BoneAttachment3D on the character skeleton. Runtime equipment
## prefabs spawn as children of the socket and receive either a preview transform
## or an item-specific EquipmentAttachmentProfile transform.
class_name EquipmentSocket3D
extends BoneAttachment3D

@export var slot_id := ""
@export var preview_path: NodePath = NodePath("MainHandPreview")
@export var use_preview_transform := true
@export var hide_preview_at_runtime := true
@export var fallback_position := Vector3.ZERO
@export var fallback_rotation_degrees := Vector3.ZERO
@export var fallback_scale := Vector3.ONE

var _preview: Node3D


func get_preview() -> Node3D:
	if _preview != null and is_instance_valid(_preview):
		return _preview
	if preview_path.is_empty():
		return null

	_preview = get_node_or_null(preview_path) as Node3D
	return _preview


func hide_runtime_preview() -> void:
	if not hide_preview_at_runtime:
		return

	var preview := get_preview()
	if preview != null:
		preview.visible = false


func should_live_sync_preview() -> bool:
	return use_preview_transform and get_preview() != null


func get_item_transform(profile: Resource = null) -> Transform3D:
	var preview := get_preview()
	if use_preview_transform and preview != null:
		return preview.transform

	if profile != null and profile.has_method("to_transform"):
		return profile.call("to_transform")

	return _fallback_transform()


func _fallback_transform() -> Transform3D:
	var basis := Basis.from_euler(Vector3(
		deg_to_rad(fallback_rotation_degrees.x),
		deg_to_rad(fallback_rotation_degrees.y),
		deg_to_rad(fallback_rotation_degrees.z)
	))
	basis = basis.scaled(_safe_scale(fallback_scale))
	return Transform3D(basis, fallback_position)


func _safe_scale(scale_value: Vector3) -> Vector3:
	if is_zero_approx(scale_value.x) or is_zero_approx(scale_value.y) or is_zero_approx(scale_value.z):
		push_warning("Equipment socket fallback scale had a zero axis; using Vector3.ONE.")
		return Vector3.ONE

	return scale_value
