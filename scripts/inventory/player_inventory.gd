## Local prototype inventory storage for the player.
##
## This node owns item slots and currency state. UI panels observe it through
## signals and call narrow commands such as `move_or_swap_slots()`.
class_name PlayerInventory
extends Node

const ItemStackScript := preload("res://scripts/inventory/item_stack.gd")
const PrototypeItemCatalogScript := preload("res://scripts/inventory/prototype_item_catalog.gd")

signal slots_changed
signal slot_changed(slot_index: int)
signal currency_changed(silver: int, gold: int)
signal equipped_slots_changed

## Number of bag slots owned by this inventory.
@export_range(1, 120, 1) var slot_count := 42
## Seeds the current resource placeholder stacks during `_ready()`.
@export var seed_prototype_resources := true
## Prototype silver amount until wallet/economy state exists.
@export var starting_silver := 0
## Prototype gold amount until wallet/economy state exists.
@export var starting_gold := 0

var _slots: Array = []
var _equipped_slots := {}
var _silver := 0
var _gold := 0
var _initialized := false


func _ready() -> void:
	if _initialized:
		return

	initialize(slot_count, starting_silver, starting_gold, seed_prototype_resources)


## Rebuilds the inventory with optional prototype seed stacks.
func initialize(new_slot_count: int, silver: int, gold: int, seed_resources: bool) -> void:
	slot_count = maxi(new_slot_count, 1)
	_silver = maxi(silver, 0)
	_gold = maxi(gold, 0)
	_equipped_slots = {}
	_slots = []
	_normalize_slot_count()
	if seed_resources:
		_seed_gathering_resources()
	_initialized = true
	slots_changed.emit()
	currency_changed.emit(_silver, _gold)
	equipped_slots_changed.emit()


## Convenience initializer for standalone UI previews.
func initialize_default_resources(new_slot_count: int, silver: int, gold: int) -> void:
	initialize(new_slot_count, silver, gold, true)


func get_slot_count() -> int:
	return slot_count


func get_silver() -> int:
	return _silver


func get_gold() -> int:
	return _gold


func get_equipped_slots() -> Dictionary:
	return _equipped_slots.duplicate(true)


func get_slot(slot_index: int) -> Resource:
	if not _is_valid_slot_index(slot_index):
		return null

	return _slots[slot_index] as Resource


## Returns the display dictionaries expected by the prototype inventory UI.
func get_display_slots() -> Array:
	var display_slots := []
	for slot in _slots:
		var stack := slot as Resource
		display_slots.append(stack.to_display_dict() if stack != null and not stack.is_empty() else {})
	return display_slots


func get_display_slot(slot_index: int) -> Dictionary:
	var stack := get_slot(slot_index)
	return stack.to_display_dict() if stack != null and not stack.is_empty() else {}


## Replaces one slot with a stack resource or clears it with null.
func set_slot(slot_index: int, stack: Resource) -> void:
	if not _is_valid_slot_index(slot_index):
		return

	_slots[slot_index] = stack
	slot_changed.emit(slot_index)
	slots_changed.emit()


## Swaps stacks between two existing bag slots.
func move_or_swap_slots(source_index: int, target_index: int) -> bool:
	if not _is_valid_slot_index(source_index) or not _is_valid_slot_index(target_index):
		return false
	if source_index == target_index:
		return false

	var source_stack: Variant = _slots[source_index]
	if source_stack == null:
		return false

	_slots[source_index] = _slots[target_index]
	_slots[target_index] = source_stack
	slot_changed.emit(source_index)
	slot_changed.emit(target_index)
	slots_changed.emit()
	return true


## Adds as many items as possible to existing matching stacks, then empty slots.
func add_stack(stack_to_add: Resource) -> int:
	if stack_to_add == null or stack_to_add.is_empty():
		return 0

	var remaining: int = int(stack_to_add.quantity)
	var definition: Resource = stack_to_add.definition as Resource
	for slot_index in range(_slots.size()):
		if remaining <= 0:
			break

		var slot_stack := _slots[slot_index] as Resource
		if slot_stack == null or slot_stack.definition != definition:
			continue

		var available: int = int(definition.max_stack) - int(slot_stack.quantity)
		if available <= 0:
			continue

		var moved := mini(available, remaining)
		slot_stack.quantity += moved
		remaining -= moved
		slot_changed.emit(slot_index)

	for slot_index in range(_slots.size()):
		if remaining <= 0:
			break
		if _slots[slot_index] != null:
			continue

		var moved := mini(definition.max_stack, remaining)
		_slots[slot_index] = _create_stack(definition, moved)
		remaining -= moved
		slot_changed.emit(slot_index)

	if remaining != stack_to_add.quantity:
		slots_changed.emit()

	return remaining


func set_currency(silver: int, gold: int) -> void:
	_silver = maxi(silver, 0)
	_gold = maxi(gold, 0)
	currency_changed.emit(_silver, _gold)


func set_equipped_slots(new_equipped_slots: Dictionary) -> void:
	_equipped_slots = new_equipped_slots.duplicate(true)
	equipped_slots_changed.emit()


func _normalize_slot_count() -> void:
	while _slots.size() < slot_count:
		_slots.append(null)

	if _slots.size() > slot_count:
		_slots.resize(slot_count)


func _seed_gathering_resources() -> void:
	var definitions: Array = PrototypeItemCatalogScript.create_gathering_definitions()
	for index in range(mini(definitions.size(), _slots.size())):
		var definition: Resource = definitions[index] as Resource
		_slots[index] = _create_stack(definition, _prototype_quantity(definition.family_id, definition.tier))


func _create_stack(definition: Resource, quantity: int) -> Resource:
	var stack: Resource = ItemStackScript.new() as Resource
	stack.call("configure", definition, quantity)
	return stack


func _prototype_quantity(family_id: String, tier: int) -> int:
	var quantity_step := 53
	match family_id:
		"logs":
			quantity_step = 83
		"stone":
			quantity_step = 71
		"ore":
			quantity_step = 59
		"cotton":
			quantity_step = 47
		"hide":
			quantity_step = 53

	return clampi(999 - (tier - 1) * quantity_step, 1, 999)


func _is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < _slots.size()
