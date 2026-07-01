## Temporary in-code item catalog for prototype gathering resources.
##
## This is the bridge before we move item data into authored `.tres` resources
## or server-provided definitions. UI code should ask inventories for stacks
## instead of duplicating this item data.
class_name PrototypeItemCatalog
extends RefCounted

const ItemDefinitionScript := preload("res://scripts/inventory/item_definition.gd")
const RESOURCE_CATEGORY := "Resource"

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


## Builds the current five-family gathering resource pass.
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
	usage_text: String
) -> void:
	for tier_index in range(names.size()):
		var tier := tier_index + 1
		var roman := tier_roman(tier)
		var definition := ItemDefinitionScript.new()
		definition.id = "%s_t%d" % [item_id_prefix, tier]
		definition.display_name = "%s %s" % [String(names[tier_index]), roman]
		definition.category = RESOURCE_CATEGORY
		definition.family_id = family_id
		definition.tier = tier
		definition.tier_roman = roman
		definition.icon_id = icon_id
		definition.max_stack = 999
		definition.unit_weight = base_weight + float(tier - 1) * weight_per_tier
		definition.color = tier_color(tier)
		definition.description = "Tier %s %s used for %s prototypes." % [roman, family_id, usage_text]
		definitions.append(definition)
