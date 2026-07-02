## Applies item tier color to selected mesh pieces on an equipped prefab.
##
## The item definition owns the tier color. PlayerEquipmentVisuals passes the
## equipped stack's display data into this node, and this script keeps the color
## limited to named meshes such as an axe blade instead of tinting the handle.
class_name TierTintedEquipment
extends Node3D

## Mesh node names that should receive the tier color.
@export var tinted_mesh_names := PackedStringArray(["RightBlade", "RightBladeEdge"])
## Fallback color used for editor previews or scenes without item display data.
@export var default_tint_color := Color(0.72, 0.72, 0.72, 1.0)
## Slightly metallic keeps placeholder blades readable without affecting handles.
@export_range(0.0, 1.0, 0.01) var metallic := 0.25
@export_range(0.0, 1.0, 0.01) var roughness := 0.42

var _current_tint_color := Color.WHITE
var _has_tint_color := false


func _ready() -> void:
	if not _has_tint_color:
		_current_tint_color = default_tint_color
	_apply_tint(_current_tint_color)


## Called by PlayerEquipmentVisuals after an inventory item is equipped.
func apply_equipment_display_data(slot_data: Dictionary) -> void:
	var tint_color := default_tint_color
	var color_value = slot_data.get("color", default_tint_color)
	if typeof(color_value) == TYPE_COLOR:
		tint_color = color_value

	_current_tint_color = tint_color
	_has_tint_color = true
	_apply_tint(tint_color)


func _apply_tint(tint_color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint_color
	material.metallic = metallic
	material.roughness = roughness

	_apply_tint_recursive(self, material)


func _apply_tint_recursive(node: Node, material: Material) -> void:
	if node is MeshInstance3D and tinted_mesh_names.has(String(node.name)):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = material

	for child in node.get_children():
		_apply_tint_recursive(child, material)
