## World-side recipe generator for weapon crafting stations.
##
## Weapon smiths craft weapon families while reusing the same interaction,
## inventory, channel, and UI plumbing as refining stations and tool makers.
class_name WeaponSmithStation3D
extends RefiningStation3D

const WEAPON_RECIPE_INPUTS := {
	"one_handed_sword": [
		{"prefix": "ingots", "quantity": 4},
		{"prefix": "planks", "quantity": 1},
	],
}

const WEAPON_LABELS := {
	"one_handed_sword": "One-Handed Sword",
}

## Weapon output families this station can craft.
@export var weapon_item_id_prefixes := PackedStringArray([
	"one_handed_sword",
])


func _init() -> void:
	display_name = "Weapon Smith"
	station_type = "weapon_smith"
	input_item_id_prefix = ""
	output_item_id_prefix = ""
	input_item_id = ""
	output_item_id = ""
	output_quantity = 1
	require_lower_tier_refined_input = false


## Returns one recipe per weapon family per available tier.
func get_refining_recipes() -> Array:
	var recipes := []
	var first_tier := clampi(min_recipe_tier, 1, 8)
	var last_tier := clampi(max_recipe_tier, first_tier, 8)
	for tier in range(first_tier, last_tier + 1):
		for weapon_prefix in weapon_item_id_prefixes:
			var weapon_id := String(weapon_prefix)
			if weapon_id.is_empty():
				continue
			recipes.append(_build_weapon_recipe(weapon_id, tier))

	return recipes


func _build_weapon_recipe(weapon_prefix: String, tier: int) -> Dictionary:
	var tier_roman := _tier_roman(tier)
	return {
		"station_name": display_name,
		"station_type": station_type,
		"tier": tier,
		"tier_roman": tier_roman,
		"recipe_label": "Tier %s %s" % [tier_roman, _weapon_label(weapon_prefix)],
		"action_text": "Craft",
		"inputs": _build_weapon_inputs(weapon_prefix, tier),
		"output_item_id": "%s_t%d" % [weapon_prefix, tier],
		"output_quantity": output_quantity,
		"seconds_per_action": seconds_per_action,
	}


func _build_weapon_inputs(weapon_prefix: String, tier: int) -> Array:
	var inputs := []
	var input_rows: Array = WEAPON_RECIPE_INPUTS.get(weapon_prefix, [])
	for input_row in input_rows:
		var row := input_row as Dictionary
		var prefix := String(row.get("prefix", ""))
		var quantity := maxi(int(row.get("quantity", 1)), 1)
		if prefix.is_empty():
			continue

		inputs.append({
			"item_id": "%s_t%d" % [prefix, tier],
			"quantity": quantity,
		})

	return inputs


func _weapon_label(weapon_prefix: String) -> String:
	return String(WEAPON_LABELS.get(weapon_prefix, weapon_prefix.capitalize()))
