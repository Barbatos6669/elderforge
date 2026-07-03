## Static data for one item type.
##
## Item definitions describe what an item is. They do not track ownership or
## quantity; ItemStack handles the runtime count for a specific inventory slot.
class_name ItemDefinition
extends Resource

@export var id := ""
@export var display_name := ""
@export var category := "Item"
@export var family_id := ""
@export var equip_slot := ""
@export_file("*.tscn") var equipment_scene_path := ""
@export_file("*.tres") var equipment_attachment_profile_path := ""
@export_file("*.tres") var equipment_animation_profile_path := ""
@export_range(0, 8, 1) var tier := 0
@export var tier_roman := ""
@export var icon_id := ""
@export_range(1, 999, 1) var max_stack := 1
@export_range(0.0, 1000.0, 0.001) var unit_weight := 0.0
@export var color := Color(0.72, 0.72, 0.72, 1.0)
@export_multiline var description := ""


## Converts this definition plus a runtime quantity into UI-facing data.
func to_display_dict(quantity: int) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"quantity": clampi(quantity, 0, max_stack),
		"max_stack": max_stack,
		"category": category,
		"family_id": family_id,
		"equip_slot": equip_slot,
		"equipment_scene_path": equipment_scene_path,
		"equipment_attachment_profile_path": equipment_attachment_profile_path,
		"equipment_animation_profile_path": equipment_animation_profile_path,
		"tier": tier,
		"tier_roman": tier_roman,
		"icon": icon_id,
		"unit_weight": unit_weight,
		"color": color,
		"description": description,
	}
