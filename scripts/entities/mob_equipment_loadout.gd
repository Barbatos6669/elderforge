## Lightweight equipment source for NPCs and hostile mobs.
##
## Mobs do not use PlayerInventory because that node joins player-facing groups
## and persistence paths. This component exposes the same equipped-slot display
## dictionaries so combat AI can read item-authored abilities.
class_name MobEquipmentLoadout
extends Node

const PrototypeItemCatalogScript := preload("res://scripts/inventory/prototype_item_catalog.gd")

signal equipped_slots_changed

## Prototype item ids equipped by this mob, such as `one_handed_sword_t1`.
@export var equipped_item_ids: PackedStringArray = PackedStringArray()

var _definitions_by_id := {}
var _equipped_slots := {}


func _ready() -> void:
	refresh_loadout()


func set_equipped_item_ids(item_ids: PackedStringArray) -> void:
	equipped_item_ids = item_ids.duplicate()
	refresh_loadout()


func refresh_loadout() -> void:
	_ensure_definitions()
	_equipped_slots.clear()

	for raw_item_id in equipped_item_ids:
		var item_id := String(raw_item_id).strip_edges()
		if item_id.is_empty():
			continue

		var definition := _definitions_by_id.get(item_id) as Resource
		if definition == null:
			push_warning("MobEquipmentLoadout could not resolve item id: %s" % item_id)
			continue

		var equip_slot := String(definition.get("equip_slot")).strip_edges()
		if equip_slot.is_empty():
			continue
		_equipped_slots[equip_slot] = definition

	equipped_slots_changed.emit()


func get_equipped_slots() -> Dictionary:
	var display_slots := {}
	for slot_id in _equipped_slots:
		var definition := _equipped_slots[slot_id] as Resource
		if definition != null and definition.has_method("to_display_dict"):
			display_slots[String(slot_id)] = definition.call("to_display_dict", 1)
	return display_slots


func get_equipped_slot(equipment_slot_id: String) -> Dictionary:
	var definition := _equipped_slots.get(equipment_slot_id) as Resource
	if definition == null or not definition.has_method("to_display_dict"):
		return {}
	return definition.call("to_display_dict", 1)


func has_equipped_item(item_id: String) -> bool:
	return equipped_item_ids.has(item_id)


func _ensure_definitions() -> void:
	if not _definitions_by_id.is_empty():
		return

	for definition_variant in PrototypeItemCatalogScript.create_prototype_definitions():
		var definition := definition_variant as Resource
		if definition == null:
			continue
		var item_id := String(definition.get("id"))
		if item_id.is_empty():
			continue
		_definitions_by_id[item_id] = definition
