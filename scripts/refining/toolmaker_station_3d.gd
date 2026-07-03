## World-side recipe generator for tool maker crafting stations.
##
## Tool makers craft several output families, so they override the single-output
## recipe generation from `RefiningStation3D` while keeping the same interaction
## and UI plumbing.
class_name ToolmakerStation3D
extends RefiningStation3D

const TOOL_RECIPE_INPUTS := {
	"axe": [
		{"prefix": "planks", "quantity": 2},
		{"prefix": "ingots", "quantity": 2},
	],
	"hammer": [
		{"prefix": "planks", "quantity": 1},
		{"prefix": "blocks", "quantity": 3},
	],
	"pickaxe": [
		{"prefix": "planks", "quantity": 1},
		{"prefix": "ingots", "quantity": 3},
	],
	"sickle": [
		{"prefix": "planks", "quantity": 1},
		{"prefix": "ingots", "quantity": 2},
		{"prefix": "cloth", "quantity": 1},
	],
	"skinning_knife": [
		{"prefix": "planks", "quantity": 1},
		{"prefix": "ingots", "quantity": 2},
		{"prefix": "worked_leather", "quantity": 1},
	],
}

const TOOL_LABELS := {
	"axe": "Axe",
	"hammer": "Hammer",
	"pickaxe": "Pickaxe",
	"sickle": "Sickle",
	"skinning_knife": "Skinning Knife",
}

## Tool output families this station can craft.
@export var tool_item_id_prefixes := PackedStringArray([
	"axe",
	"hammer",
	"pickaxe",
	"sickle",
	"skinning_knife",
])


func _init() -> void:
	display_name = "Tool Maker"
	station_type = "toolmaker"
	input_item_id_prefix = ""
	output_item_id_prefix = ""
	input_item_id = ""
	output_item_id = ""
	output_quantity = 1
	require_lower_tier_refined_input = false


## Returns one recipe per tool family per available tier.
func get_refining_recipes() -> Array:
	var recipes := []
	var first_tier := clampi(min_recipe_tier, 1, 8)
	var last_tier := clampi(max_recipe_tier, first_tier, 8)
	for tier in range(first_tier, last_tier + 1):
		for tool_prefix in tool_item_id_prefixes:
			var tool_id := String(tool_prefix)
			if tool_id.is_empty():
				continue
			recipes.append(_build_tool_recipe(tool_id, tier))

	return recipes


func _build_tool_recipe(tool_prefix: String, tier: int) -> Dictionary:
	var tier_roman := _tier_roman(tier)
	return {
		"station_name": display_name,
		"station_type": station_type,
		"tier": tier,
		"tier_roman": tier_roman,
		"recipe_label": "Tier %s %s" % [tier_roman, _tool_label(tool_prefix)],
		"action_text": "Craft",
		"inputs": _build_tool_inputs(tool_prefix, tier),
		"output_item_id": "%s_t%d" % [tool_prefix, tier],
		"output_quantity": output_quantity,
		"seconds_per_action": seconds_per_action,
	}


func _build_tool_inputs(tool_prefix: String, tier: int) -> Array:
	var inputs := []
	var input_rows: Array = TOOL_RECIPE_INPUTS.get(tool_prefix, [])
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


func _tool_label(tool_prefix: String) -> String:
	return String(TOOL_LABELS.get(tool_prefix, tool_prefix.capitalize()))
