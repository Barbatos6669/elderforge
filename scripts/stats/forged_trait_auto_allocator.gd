## Prototype trait allocator for non-player entities.
##
## This gives mobs and creatures a simple way to spend trait points from the same
## catalog the player uses. Later this can be replaced with encounter templates,
## factions, biomes, rarity rolls, or server-authored builds.
class_name ForgedTraitAutoAllocator
extends Node

@export var loadout_path: NodePath = NodePath("../ForgedTraits")
@export var entity_type: StringName = ForgedTraitCatalog.ENTITY_MOB
@export_range(1, 100, 1) var level := 1
@export_range(0, 100, 1) var trait_budget := 1
@export var preferred_tags: Array[StringName] = []
@export var preferred_trait_ids: Array[StringName] = []
@export var allocate_on_ready := true

var _loadout: Node


func _ready() -> void:
	if allocate_on_ready:
		allocate()


func allocate() -> void:
	_loadout = get_node_or_null(loadout_path)
	if _loadout == null:
		push_warning("ForgedTraitAutoAllocator could not find loadout at %s." % loadout_path)
		return
	if not _loadout.has_method("set_character_level"):
		return

	_loadout.set("entity_type", entity_type)
	if _loadout.has_method("apply_progression_snapshot"):
		_loadout.call("apply_progression_snapshot", {
			"character_level": level,
			"current_xp": 0,
			"total_xp": 0,
			"unspent_trait_points": 0,
			"purchased_traits": {},
			"active_traits": [],
		})
	else:
		_loadout.call("set_character_level", level)
		if _loadout.has_method("clear_active_traits"):
			_loadout.call("clear_active_traits")
	if _loadout.has_method("grant_trait_points"):
		_loadout.call("grant_trait_points", trait_budget)

	for trait_id in _build_trait_order():
		if not _loadout.has_method("purchase_trait") or not _loadout.has_method("activate_trait"):
			return
		if int(_loadout.call("get_open_active_slots")) <= 0:
			return
		if int(_loadout.call("get_unspent_trait_points")) <= 0:
			return
		if bool(_loadout.call("purchase_trait", trait_id, 1)):
			_loadout.call("activate_trait", trait_id)


func _build_trait_order() -> Array[StringName]:
	var output: Array[StringName] = []
	for trait_id in preferred_trait_ids:
		_append_unique_trait(output, trait_id)

	for trait_id in ForgedTraitCatalog.get_trait_ids():
		if preferred_tags.is_empty():
			continue
		if ForgedTraitCatalog.trait_has_any_tag(trait_id, preferred_tags):
			_append_unique_trait(output, trait_id)

	for trait_id in ForgedTraitCatalog.get_trait_ids():
		_append_unique_trait(output, trait_id)

	return output


func _append_unique_trait(output: Array[StringName], trait_id: StringName) -> void:
	var clean_id := StringName(String(trait_id))
	if output.has(clean_id):
		return
	if not ForgedTraitCatalog.trait_allowed_for_entity(clean_id, entity_type):
		return
	if level < ForgedTraitCatalog.trait_unlock_level(clean_id):
		return

	output.append(clean_id)
