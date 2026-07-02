## Temporary in-code item catalog for prototype gathering resources.
##
## This is the bridge before we move item data into authored `.tres` resources
## or server-provided definitions. UI code should ask inventories for stacks
## instead of duplicating this item data.
class_name PrototypeItemCatalog
extends RefCounted

const ItemDefinitionScript := preload("res://scripts/inventory/item_definition.gd")
const RESOURCE_CATEGORY := "Resource"
const TOOL_CATEGORY := "Tool"
const AXE_TOOL_SCENE_PATH_TEMPLATE := "res://scenes/equipment/tools/axes/Tier%dAxe.tscn"
const AXE_MAIN_HAND_ATTACHMENT_PROFILE_PATH := "res://assets/models/equipment/attachments/axe_main_hand.tres"

const TIER_COLORS := {
	1: Color(0.72, 0.72, 0.72, 1.0),
	2: Color(0.72, 0.50, 0.30, 1.0),
	3: Color(0.20, 0.62, 0.25, 1.0),
	4: Color(0.20, 0.42, 0.82, 1.0),
	5: Color(0.78, 0.18, 0.16, 1.0),
	6: Color(0.92, 0.48, 0.14, 1.0),
	7: Color(0.95, 0.82, 0.18, 1.0),
	8: Color(0.94, 0.94, 0.9, 1.0),
}


## Builds the current gathering resource item pass.
static func create_gathering_definitions() -> Array:
	var definitions := []
	_append_family(
		definitions,
		"logs",
		"logs",
		"timber",
		[
			"Crude Logs",
			"Rough Logs",
			"Sturdy Logs",
			"Seasoned Logs",
			"Hardened Logs",
			"Emberwood Logs",
			"Sunheart Logs",
			"Kingswood Logs",
		],
		0.03,
		0.01,
		"woodworking, crafting, and construction"
	)
	_append_family(
		definitions,
		"stone",
		"rocks",
		"stone",
		[
			"Crude Stone",
			"Rough Stone",
			"Sturdy Stone",
			"Dense Stone",
			"Hardened Stone",
			"Runed Stone",
			"Sunstone",
			"Kingsstone",
		],
		0.06,
		0.015,
		"masonry, construction, and refining"
	)
	_append_family(
		definitions,
		"ore",
		"ores",
		"ore",
		[
			"Crude Ore",
			"Rough Ore",
			"Sturdy Ore",
			"Dense Ore",
			"Hardened Ore",
			"Runed Ore",
			"Star Ore",
			"Kingsmetal Ore",
		],
		0.08,
		0.02,
		"smelting, weapon crafting, and refining"
	)
	_append_family(
		definitions,
		"cotton",
		"cotton",
		"cotton",
		[
			"Crude Cotton",
			"Rough Cotton",
			"Coarse Cotton",
			"Soft Cotton",
			"Fine Cotton",
			"Lustrous Cotton",
			"Sunspun Cotton",
			"Kingsweave Cotton",
		],
		0.02,
		0.006,
		"tailoring, cloth crafting, and refining"
	)
	_append_family(
		definitions,
		"hide",
		"hide",
		"hide",
		[
			"Crude Hide",
			"Rough Hide",
			"Thick Hide",
			"Cured Hide",
			"Hardened Hide",
			"Pristine Hide",
			"Royal Hide",
			"Elder Hide",
		],
		0.04,
		0.012,
		"leatherworking, armor crafting, and refining"
	)
	return definitions


## Builds temporary gathering tool preview items before real tool data exists.
static func create_equipment_preview_definitions() -> Array:
	var definitions := []
	_append_family(
		definitions,
		"axe",
		"axe",
		"axe",
		[
			"Crude Axe",
			"Rough Axe",
			"Sturdy Axe",
			"Forged Axe",
			"Hardened Axe",
			"Runed Axe",
			"Sunsteel Axe",
			"Elder Axe",
		],
		2.5,
		0.25,
		"woodcutting, gathering tests, and tool prototypes",
		TOOL_CATEGORY,
		1,
		"main_hand",
		AXE_TOOL_SCENE_PATH_TEMPLATE,
		AXE_MAIN_HAND_ATTACHMENT_PROFILE_PATH
	)
	return definitions


## Builds every temporary item definition known to the prototype.
static func create_prototype_definitions() -> Array:
	var definitions := create_gathering_definitions()
	definitions.append_array(create_equipment_preview_definitions())
	return definitions


static func tier_color(tier: int) -> Color:
	return TIER_COLORS.get(clampi(tier, 1, 8), TIER_COLORS[1])


static func tier_roman(tier: int) -> String:
	var roman_values := {
		1: "I",
		2: "II",
		3: "III",
		4: "IV",
		5: "V",
		6: "VI",
		7: "VII",
		8: "VIII",
	}
	return String(roman_values.get(tier, str(tier)))


static func _append_family(
	definitions: Array,
	family_id: String,
	icon_id: String,
	item_id_prefix: String,
	names: Array,
	base_weight: float,
	weight_per_tier: float,
	usage_text: String,
	category: String = RESOURCE_CATEGORY,
	max_stack: int = 999,
	equip_slot: String = "",
	equipment_scene_path: String = "",
	equipment_attachment_profile_path: String = ""
) -> void:
	for tier_index in range(names.size()):
		var tier := tier_index + 1
		var roman := tier_roman(tier)
		var definition := ItemDefinitionScript.new()
		definition.id = "%s_t%d" % [item_id_prefix, tier]
		definition.display_name = "%s %s" % [String(names[tier_index]), roman]
		definition.category = category
		definition.family_id = family_id
		definition.equip_slot = equip_slot
		definition.equipment_scene_path = _resolve_equipment_scene_path(equipment_scene_path, tier)
		definition.equipment_attachment_profile_path = equipment_attachment_profile_path
		definition.tier = tier
		definition.tier_roman = roman
		definition.icon_id = icon_id
		definition.max_stack = max_stack
		definition.unit_weight = base_weight + float(tier - 1) * weight_per_tier
		definition.color = tier_color(tier)
		definition.description = "Tier %s %s used for %s prototypes." % [roman, family_id, usage_text]
		definitions.append(definition)


static func _resolve_equipment_scene_path(scene_path_template: String, tier: int) -> String:
	if scene_path_template.contains("%d"):
		return scene_path_template % tier
	return scene_path_template
