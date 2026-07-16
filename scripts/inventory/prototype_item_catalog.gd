## Temporary item catalog for prototype resources, refined materials, tools, and
## weapons.
##
## Item family data lives in `assets/items/families/`. This script turns each
## family resource into one ItemDefinition per tier. UI code should ask
## inventories for stacks instead of duplicating this item data.
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

const RAW_FAMILY_PATHS := [
	"res://assets/items/families/raw/logs.tres",
	"res://assets/items/families/raw/stone.tres",
	"res://assets/items/families/raw/ore.tres",
	"res://assets/items/families/raw/cotton.tres",
	"res://assets/items/families/raw/hide.tres",
]
const REFINED_FAMILY_PATHS := [
	"res://assets/items/families/refined/planks.tres",
	"res://assets/items/families/refined/blocks.tres",
	"res://assets/items/families/refined/ingots.tres",
	"res://assets/items/families/refined/cloth.tres",
	"res://assets/items/families/refined/worked_leather.tres",
]
const TOOL_FAMILY_PATHS := [
	"res://assets/items/families/tools/axe.tres",
	"res://assets/items/families/tools/hammer.tres",
	"res://assets/items/families/tools/pickaxe.tres",
	"res://assets/items/families/tools/sickle.tres",
	"res://assets/items/families/tools/skinning_knife.tres",
]
const WEAPON_FAMILY_PATHS := [
	"res://assets/items/families/weapons/one_handed_sword.tres",
]
const ARMOR_FAMILY_PATHS := [
	"res://assets/items/families/armor/leather_armor.tres",
	"res://assets/items/families/armor/leather_helmet.tres",
	"res://assets/items/families/armor/leather_boots.tres",
]


## Builds the current gathering resource item pass.
static func create_gathering_definitions() -> Array:
	return _create_definitions_from_paths(RAW_FAMILY_PATHS)


## Builds temporary refined resource items produced by crafting/refining.
static func create_refined_resource_definitions() -> Array:
	return _create_definitions_from_paths(REFINED_FAMILY_PATHS)


## Builds temporary gathering tool preview items before real tool data exists.
static func create_equipment_preview_definitions() -> Array:
	return _create_definitions_from_paths(TOOL_FAMILY_PATHS)


## Builds temporary weapon preview items before real weapon data exists.
static func create_weapon_preview_definitions() -> Array:
	return _create_definitions_from_paths(WEAPON_FAMILY_PATHS)


## Builds temporary wearable armor items before the full crafting tree exists.
static func create_armor_preview_definitions() -> Array:
	return _create_definitions_from_paths(ARMOR_FAMILY_PATHS)


## Builds every temporary item definition known to the prototype.
static func create_prototype_definitions() -> Array:
	var definitions := create_gathering_definitions()
	definitions.append_array(create_refined_resource_definitions())
	definitions.append_array(create_equipment_preview_definitions())
	definitions.append_array(create_weapon_preview_definitions())
	definitions.append_array(create_armor_preview_definitions())
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


static func _create_definitions_from_paths(paths: Array) -> Array:
	var definitions := []
	for path in paths:
		var family_definition := _load_family_definition(path)
		if family_definition == null:
			continue

		_append_family_definition(definitions, family_definition, path)
	return definitions


static func _load_family_definition(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		push_warning("Missing item family definition: %s" % path)
		return null

	var family_definition := load(path) as Resource
	if family_definition == null:
		push_warning("Item family definition did not load as a Resource: %s" % path)
		return null

	return family_definition


static func _append_family_definition(definitions: Array, family_definition: Resource, source_path: String) -> void:
	var family_id := String(family_definition.get("family_id"))
	var icon_id := String(family_definition.get("icon_id"))
	var item_id_prefix := String(family_definition.get("item_id_prefix"))
	var category := String(family_definition.get("category"))
	var tier_names := PackedStringArray(family_definition.get("tier_names"))
	var tier_descriptions := PackedStringArray(family_definition.get("tier_descriptions"))
	var base_weight := float(family_definition.get("base_weight"))
	var weight_per_tier := float(family_definition.get("weight_per_tier"))
	var usage_text := String(family_definition.get("usage_text"))
	var max_stack := maxi(1, int(family_definition.get("max_stack")))
	var equip_slot := String(family_definition.get("equip_slot"))
	var equipment_visual_mode := String(family_definition.get("equipment_visual_mode"))
	var equipment_scene_path_template := String(family_definition.get("equipment_scene_path_template"))
	var equipment_scene_path_templates_by_body := family_definition.get("equipment_scene_path_templates_by_body") as Dictionary
	var equipment_replaces_outfit_parts := PackedStringArray(family_definition.get("equipment_replaces_outfit_parts"))
	var equipment_attachment_profile_path := String(family_definition.get("equipment_attachment_profile_path"))
	var equipment_animation_profile_path_template := String(family_definition.get("equipment_animation_profile_path_template"))
	var q_ability_path_template := String(family_definition.get("q_ability_path_template"))
	var ability_path_templates := family_definition.get("ability_path_templates") as Dictionary
	var ability_choice_path_templates := family_definition.get("ability_choice_path_templates") as Dictionary
	var stat_modifiers := family_definition.get("stat_modifiers") as Dictionary

	if family_id.is_empty() or item_id_prefix.is_empty() or tier_names.is_empty():
		push_warning("Item family definition is missing required data: %s" % source_path)
		return
	if category.is_empty():
		category = RESOURCE_CATEGORY

	for tier_index in range(tier_names.size()):
		var tier := tier_index + 1
		var roman := tier_roman(tier)
		var definition := ItemDefinitionScript.new()
		definition.id = "%s_t%d" % [item_id_prefix, tier]
		definition.display_name = "%s %s" % [tier_names[tier_index], roman]
		definition.category = category
		definition.family_id = family_id
		definition.equip_slot = equip_slot
		definition.equipment_visual_mode = equipment_visual_mode if not equipment_visual_mode.is_empty() else "socket"
		definition.equipment_scene_path = _resolve_tier_path(equipment_scene_path_template, tier)
		definition.equipment_scene_paths_by_body = _resolve_body_scene_paths(
			equipment_scene_path_templates_by_body,
			tier
		)
		definition.equipment_replaces_outfit_parts = equipment_replaces_outfit_parts.duplicate()
		definition.equipment_attachment_profile_path = equipment_attachment_profile_path
		definition.equipment_animation_profile_path = _resolve_tier_path(equipment_animation_profile_path_template, tier)
		definition.q_ability_path = _resolve_tier_path(q_ability_path_template, tier)
		definition.ability_paths = _resolve_ability_paths(ability_path_templates, tier)
		definition.ability_choices = _resolve_ability_choices(
			ability_choice_path_templates,
			tier,
			definition.ability_paths
		)
		definition.stat_modifiers = stat_modifiers.duplicate(true) if stat_modifiers != null else {}
		definition.tier = tier
		definition.tier_roman = roman
		definition.icon_id = icon_id
		definition.max_stack = max_stack
		definition.unit_weight = base_weight + float(tier - 1) * weight_per_tier
		definition.color = tier_color(tier)
		definition.description = _definition_description(
			tier_descriptions,
			tier_index,
			roman,
			family_id,
			usage_text
		)
		definitions.append(definition)


static func _resolve_ability_paths(path_templates: Dictionary, tier: int) -> Dictionary:
	var resolved_paths := {}
	if path_templates == null:
		return resolved_paths

	for raw_slot_id in path_templates:
		var slot_id := String(raw_slot_id).strip_edges().to_lower()
		var path_template := String(path_templates[raw_slot_id])
		if slot_id.is_empty() or path_template.is_empty():
			continue
		resolved_paths[slot_id] = _resolve_tier_path(path_template, tier)
	return resolved_paths


static func _resolve_ability_choices(
	choice_templates: Dictionary,
	tier: int,
	default_paths: Dictionary
) -> Dictionary:
	var resolved_choices := {}
	if choice_templates != null:
		for raw_slot_id in choice_templates.keys():
			var slot_id := String(raw_slot_id).strip_edges().to_lower()
			if slot_id.is_empty():
				continue

			var paths := PackedStringArray()
			for raw_choice in _choice_entries(choice_templates[raw_slot_id]):
				var path_template := ""
				var min_tier := 1
				var max_tier := 8
				if raw_choice is Dictionary:
					var choice_data := raw_choice as Dictionary
					path_template = String(choice_data.get("path", ""))
					min_tier = maxi(int(choice_data.get("min_tier", 1)), 1)
					max_tier = maxi(int(choice_data.get("max_tier", 8)), min_tier)
				else:
					path_template = String(raw_choice)

				if tier < min_tier or tier > max_tier or path_template.is_empty():
					continue
				var resolved_path := _resolve_tier_path(path_template, tier)
				if not resolved_path.is_empty() and not paths.has(resolved_path):
					paths.append(resolved_path)

			if not paths.is_empty():
				resolved_choices[slot_id] = paths

	if default_paths != null:
		for raw_slot_id in default_paths.keys():
			var slot_id := String(raw_slot_id).strip_edges().to_lower()
			var default_path := String(default_paths[raw_slot_id]).strip_edges()
			if slot_id.is_empty() or default_path.is_empty():
				continue

			var paths := PackedStringArray(resolved_choices.get(slot_id, PackedStringArray()))
			if not paths.has(default_path):
				paths.insert(0, default_path)
			resolved_choices[slot_id] = paths

	return resolved_choices


static func _choice_entries(raw_choices: Variant) -> Array:
	if raw_choices is Array:
		return raw_choices as Array

	var entries: Array = []
	if raw_choices is PackedStringArray:
		for path in raw_choices as PackedStringArray:
			entries.append(path)
	elif raw_choices != null:
		entries.append(raw_choices)
	return entries


static func _resolve_tier_path(path_template: String, tier: int) -> String:
	var placeholder_count := path_template.count("%d")
	if placeholder_count <= 0:
		return path_template
	if placeholder_count == 1:
		return path_template % tier

	return path_template % [tier, tier]


static func _resolve_body_scene_paths(path_templates: Dictionary, tier: int) -> Dictionary:
	var resolved_paths := {}
	if path_templates == null:
		return resolved_paths

	for body_type in path_templates.keys():
		var path_template := String(path_templates[body_type])
		if path_template.is_empty():
			continue
		resolved_paths[String(body_type)] = _resolve_tier_path(path_template, tier)
	return resolved_paths


static func _definition_description(
	tier_descriptions: PackedStringArray,
	tier_index: int,
	roman: String,
	family_id: String,
	usage_text: String
) -> String:
	if tier_index < tier_descriptions.size():
		var custom_description := tier_descriptions[tier_index].strip_edges()
		if not custom_description.is_empty():
			return custom_description

	return "Tier %s %s used for %s prototypes." % [roman, family_id, usage_text]
