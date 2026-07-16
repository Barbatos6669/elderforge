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
@export_enum("socket", "skeleton") var equipment_visual_mode := "socket"
@export_file("*.tscn") var equipment_scene_path := ""
## Optional body-specific alternatives used by fitted armor visuals.
@export var equipment_scene_paths_by_body: Dictionary = {}
## Outfit mesh-name fragments replaced by this equipped visual.
@export var equipment_replaces_outfit_parts: PackedStringArray = PackedStringArray()
@export_file("*.tres") var equipment_attachment_profile_path := ""
@export_file("*.tres") var equipment_animation_profile_path := ""
@export_file("*.tres") var q_ability_path := ""
## Equipment-provided action-bar abilities keyed by stable slot id.
@export var ability_paths: Dictionary = {}
## Additive player stat bonuses granted while this item is equipped.
@export var stat_modifiers: Dictionary = {}
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
		"equipment_visual_mode": equipment_visual_mode,
		"equipment_scene_path": equipment_scene_path,
		"equipment_scene_paths_by_body": equipment_scene_paths_by_body.duplicate(true),
		"equipment_replaces_outfit_parts": equipment_replaces_outfit_parts.duplicate(),
		"equipment_attachment_profile_path": equipment_attachment_profile_path,
		"equipment_animation_profile_path": equipment_animation_profile_path,
		"q_ability_path": q_ability_path,
		"ability_paths": ability_paths.duplicate(true),
		"stat_modifiers": stat_modifiers.duplicate(true),
		"tier": tier,
		"tier_roman": tier_roman,
		"icon": icon_id,
		"unit_weight": unit_weight,
		"color": color,
		"description": description,
	}
