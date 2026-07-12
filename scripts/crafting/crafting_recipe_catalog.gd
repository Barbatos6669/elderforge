## Prototype recipe catalog for the master menu and future crafting journals.
##
## The world crafting stations own the actual craft action. This catalog mirrors
## their current recipe rules so UI pages can show every craftable prototype item
## without needing a placed station node in the active scene.
class_name CraftingRecipeCatalog
extends RefCounted

const PrototypeItemCatalogScript := preload("res://scripts/inventory/prototype_item_catalog.gd")

const REFINED_RECIPE_FAMILIES := [
	{
		"output_prefix": "planks",
		"station_name": "Sawmill",
		"category": "Refining",
		"inputs": [{"prefix": "timber", "quantity": 4}],
		"requires_lower_tier_refined": true,
		"lore": "Woodcutters turn raw logs into straight beams for homes, tools, bridges, ward posts, and shrine repairs. Higher tiers keep the old settlement craft alive by binding new timber around a lower-tier beam.",
	},
	{
		"output_prefix": "blocks",
		"station_name": "Stonecutter",
		"category": "Refining",
		"inputs": [{"prefix": "stone", "quantity": 4}],
		"requires_lower_tier_refined": true,
		"lore": "Stone blocks are shaped for walls, roads, kilns, foundations, and town repairs. Masons say a block remembers the hill it came from, so stronger work is built on older stone.",
	},
	{
		"output_prefix": "ingots",
		"station_name": "Smelter",
		"category": "Refining",
		"inputs": [{"prefix": "ore", "quantity": 4}],
		"requires_lower_tier_refined": true,
		"lore": "Ore becomes ingots in the furnace, ready for tools, weapons, fittings, nails, traps, and armor repairs. Smiths treat each bar as a promise that heat can turn rough earth into purpose.",
	},
	{
		"output_prefix": "cloth",
		"station_name": "Loom",
		"category": "Refining",
		"inputs": [{"prefix": "cotton", "quantity": 4}],
		"requires_lower_tier_refined": true,
		"lore": "Fiber is spun and woven into cloth for robes, bandages, satchels, tents, sails, and alchemy wraps. Better cloth keeps a trace of the field, wind, and hands that made it.",
	},
	{
		"output_prefix": "worked_leather",
		"station_name": "Tannery",
		"category": "Refining",
		"inputs": [{"prefix": "hide", "quantity": 4}],
		"requires_lower_tier_refined": true,
		"lore": "Raw hides are scraped, softened, and cured into leather for bags, straps, boots, armor patches, and tool grips. Hunters respect worked leather because wasteful skinning offends both beast and forest.",
	},
]

const TOOL_RECIPE_FAMILIES := [
	{
		"output_prefix": "axe",
		"station_name": "Tool Maker",
		"category": "Tool",
		"inputs": [
			{"prefix": "planks", "quantity": 2},
			{"prefix": "ingots", "quantity": 2},
		],
		"lore": "Axes are woodcutters' trusted tools. A good axe bites cleanly, keeps the grove work honest, and helps gatherers take the trunk while leaving the cone.",
	},
	{
		"output_prefix": "hammer",
		"station_name": "Tool Maker",
		"category": "Tool",
		"inputs": [
			{"prefix": "planks", "quantity": 1},
			{"prefix": "blocks", "quantity": 3},
		],
		"lore": "Stone hammers break rock, shape masonry, and keep quarry work moving. They are simple tools, but every town wall starts with repeated honest strikes.",
	},
	{
		"output_prefix": "pickaxe",
		"station_name": "Tool Maker",
		"category": "Tool",
		"inputs": [
			{"prefix": "planks", "quantity": 1},
			{"prefix": "ingots", "quantity": 3},
		],
		"lore": "Pickaxes open ore seams and teach miners to listen for hollow stone. A careless swing wastes metal; a patient one finds the vein.",
	},
	{
		"output_prefix": "sickle",
		"station_name": "Tool Maker",
		"category": "Tool",
		"inputs": [
			{"prefix": "planks", "quantity": 1},
			{"prefix": "ingots", "quantity": 2},
			{"prefix": "cloth", "quantity": 1},
		],
		"lore": "Sickles harvest fiber, reeds, herbs, and soft stalks without tearing the field apart. Farmers and witches both judge a sickle by how little it bruises what it cuts.",
	},
	{
		"output_prefix": "skinning_knife",
		"station_name": "Tool Maker",
		"category": "Tool",
		"inputs": [
			{"prefix": "planks", "quantity": 1},
			{"prefix": "ingots", "quantity": 2},
			{"prefix": "worked_leather", "quantity": 1},
		],
		"lore": "Skinning knives are made for careful hide work. Hunters sharpen them before dawn, because respect for the animal begins after the fight is over.",
	},
]

const WEAPON_RECIPE_FAMILIES := [
	{
		"output_prefix": "one_handed_sword",
		"station_name": "Weapon Smith",
		"category": "Weapon",
		"inputs": [
			{"prefix": "ingots", "quantity": 4},
			{"prefix": "planks", "quantity": 1},
		],
		"lore": "A one-handed sword is the first proper blade many fighters trust. It leaves the off hand free for shields, torches, tools, or future spell work.",
	},
]


## Returns all prototype recipes in the order players should read them.
static func create_recipes() -> Array:
	var definitions := _definitions_by_id()
	var recipes := []
	_append_family_recipes(recipes, REFINED_RECIPE_FAMILIES, definitions)
	_append_family_recipes(recipes, TOOL_RECIPE_FAMILIES, definitions)
	_append_family_recipes(recipes, WEAPON_RECIPE_FAMILIES, definitions)
	return recipes


## Builds a quick lookup table for detail-page selection.
static func create_recipe_lookup() -> Dictionary:
	var lookup := {}
	for recipe in create_recipes():
		var recipe_data := recipe as Dictionary
		lookup[String(recipe_data.get("id", ""))] = recipe_data
	return lookup


static func _append_family_recipes(recipes: Array, recipe_families: Array, definitions: Dictionary) -> void:
	for family in recipe_families:
		var family_data := family as Dictionary
		var output_prefix := String(family_data.get("output_prefix", ""))
		if output_prefix.is_empty():
			continue

		for tier in range(1, 9):
			var output_item_id := "%s_t%d" % [output_prefix, tier]
			if not definitions.has(output_item_id):
				continue

			var output_definition := definitions[output_item_id] as Resource
			if output_definition == null:
				continue
			recipes.append({
				"id": output_item_id,
				"label": String(output_definition.get("display_name")),
				"category": String(family_data.get("category", "Crafting")),
				"station_name": String(family_data.get("station_name", "Crafting Station")),
				"tier": tier,
				"tier_roman": PrototypeItemCatalogScript.tier_roman(tier),
				"output_item_id": output_item_id,
				"output_name": String(output_definition.get("display_name")),
				"output_quantity": 1,
				"ingredients": _build_ingredients(family_data, tier, definitions),
				"lore": String(family_data.get("lore", "")),
				"description": String(output_definition.get("description")),
			})


static func _build_ingredients(family_data: Dictionary, tier: int, definitions: Dictionary) -> Array:
	var ingredients := []
	var input_rows := family_data.get("inputs", []) as Array
	for input_row in input_rows:
		var row := input_row as Dictionary
		var prefix := String(row.get("prefix", ""))
		var quantity := maxi(int(row.get("quantity", 1)), 1)
		if prefix.is_empty():
			continue

		_append_ingredient(ingredients, "%s_t%d" % [prefix, tier], quantity, definitions)

	if bool(family_data.get("requires_lower_tier_refined", false)) and tier > 1:
		var output_prefix := String(family_data.get("output_prefix", ""))
		_append_ingredient(ingredients, "%s_t%d" % [output_prefix, tier - 1], 1, definitions)

	return ingredients


static func _append_ingredient(ingredients: Array, item_id: String, quantity: int, definitions: Dictionary) -> void:
	var display_name := _display_name_for_item(item_id, definitions)
	ingredients.append({
		"item_id": item_id,
		"name": display_name,
		"quantity": maxi(quantity, 1),
	})


static func _definitions_by_id() -> Dictionary:
	var definitions := {}
	for definition in PrototypeItemCatalogScript.create_prototype_definitions():
		var definition_resource := definition as Resource
		if definition_resource == null:
			continue
		definitions[String(definition_resource.get("id"))] = definition_resource
	return definitions


static func _display_name_for_item(item_id: String, definitions: Dictionary) -> String:
	if definitions.has(item_id):
		var definition := definitions[item_id] as Resource
		if definition != null:
			return String(definition.get("display_name"))

	return item_id.replace("_", " ").capitalize()
