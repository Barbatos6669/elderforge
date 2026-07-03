## Local prototype inventory storage for the player.
##
## This node owns item slots and currency state. UI panels observe it through
## signals and call narrow commands such as `move_or_swap_slots()`.
class_name PlayerInventory
extends Node

const ItemStackScript := preload("res://scripts/inventory/item_stack.gd")
const PrototypeItemCatalogScript := preload("res://scripts/inventory/prototype_item_catalog.gd")
const MAX_SLOT_COUNT := 42

signal slots_changed
signal slot_changed(slot_index: int)
signal currency_changed(silver: int, gold: int)
signal equipped_slots_changed

## Number of bag slots owned by this inventory.
@export_range(1, MAX_SLOT_COUNT, 1) var slot_count := MAX_SLOT_COUNT
## Seeds resource placeholder stacks during `_ready()` when a debug/demo scene needs them.
@export var seed_prototype_resources := false
## Optional item ids to seed for focused debug/demo previews.
@export var debug_seed_item_ids: PackedStringArray = []
## Quantity used for each `debug_seed_item_ids` stack.
@export_range(1, 999, 1) var debug_seed_quantity := 1
## Optional debug item id to equip into the main-hand slot during startup.
@export var debug_main_hand_item_id := ""
## Prototype silver amount until wallet/economy state exists.
@export var starting_silver := 0
## Prototype gold amount until wallet/economy state exists.
@export var starting_gold := 0

var _slots: Array = []
var _equipped_slots := {}
var _prototype_definitions: Array = []
var _definitions_by_id := {}
var _silver := 0
var _gold := 0
var _initialized := false


func _ready() -> void:
	add_to_group("player_inventory")
	if _initialized:
		return

	initialize(slot_count, starting_silver, starting_gold, seed_prototype_resources)


## Rebuilds the inventory with optional prototype seed stacks.
func initialize(new_slot_count: int, silver: int, gold: int, seed_resources: bool) -> void:
	slot_count = clampi(new_slot_count, 1, MAX_SLOT_COUNT)
	_silver = maxi(silver, 0)
	_gold = maxi(gold, 0)
	_equipped_slots = {}
	_slots = []
	_normalize_slot_count()
	if seed_resources:
		_seed_gathering_resources()
	_seed_debug_items()
	_seed_debug_equipment()
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
	var display_slots := {}
	for slot_id in _equipped_slots:
		var stack := _equipped_slots[slot_id] as Resource
		if stack != null and not stack.is_empty():
			display_slots[slot_id] = stack.to_display_dict()
	return display_slots


## Returns one equipped slot in the same UI-facing dictionary format as `get_equipped_slots()`.
func get_equipped_slot(equipment_slot_id: String) -> Dictionary:
	var stack := _equipped_stack_at(equipment_slot_id)
	return stack.to_display_dict() if stack != null and not stack.is_empty() else {}


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
	if definition == null:
		return remaining

	for slot_index in range(_slots.size()):
		if remaining <= 0:
			break

		var slot_stack := _slots[slot_index] as Resource
		if slot_stack == null or not _is_same_definition(slot_stack.definition, definition):
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


## Adds a quantity of an item definition by id. Returns the amount that did not fit.
func add_item(item_id: String, quantity: int) -> int:
	var definition := get_definition(item_id)
	if definition == null:
		return quantity

	var stack := _create_stack(definition, quantity)
	return add_stack(stack)


## Counts all bag-slot quantity for a specific item id.
func get_item_count(item_id: String) -> int:
	if item_id.is_empty():
		return 0

	var total := 0
	for slot in _slots:
		var stack := slot as Resource
		if stack == null or stack.is_empty():
			continue

		var definition := stack.get("definition") as Resource
		if definition != null and String(definition.get("id")) == item_id:
			total += int(stack.get("quantity"))
	return total


## Returns how many more of an item can fit in the current bag slots.
func get_addable_count(item_id: String) -> int:
	var definition := get_definition(item_id)
	if definition == null:
		return 0

	var available_count := 0
	for slot in _slots:
		var stack := slot as Resource
		if stack == null:
			available_count += int(definition.max_stack)
			continue

		if stack.is_empty():
			available_count += int(definition.max_stack)
			continue

		if _is_same_definition(stack.get("definition") as Resource, definition):
			available_count += maxi(int(definition.max_stack) - int(stack.get("quantity")), 0)

	return available_count


## Removes as many matching items as possible from bag slots.
## Returns the amount that could not be removed, mirroring `add_item()`.
func remove_item(item_id: String, quantity: int) -> int:
	var remaining := maxi(quantity, 0)
	if item_id.is_empty() or remaining <= 0:
		return 0

	var removed_any := false
	for slot_index in range(_slots.size()):
		if remaining <= 0:
			break

		var stack := _slots[slot_index] as Resource
		if stack == null or stack.is_empty():
			continue

		var definition := stack.get("definition") as Resource
		if definition == null or String(definition.get("id")) != item_id:
			continue

		var removed := mini(int(stack.get("quantity")), remaining)
		stack.set("quantity", int(stack.get("quantity")) - removed)
		remaining -= removed
		removed_any = true

		if stack.is_empty():
			_slots[slot_index] = null

		slot_changed.emit(slot_index)

	if removed_any:
		slots_changed.emit()

	return remaining


func get_definition(item_id: String) -> Resource:
	_ensure_prototype_definitions()
	return _definitions_by_id.get(item_id) as Resource


func set_currency(silver: int, gold: int) -> void:
	_silver = maxi(silver, 0)
	_gold = maxi(gold, 0)
	currency_changed.emit(_silver, _gold)


## Returns true if a bag slot can be equipped into the requested gear slot.
func can_equip_from_slot(source_index: int, equipment_slot_id: String) -> bool:
	if not _is_valid_slot_index(source_index):
		return false

	var source_stack := _slots[source_index] as Resource
	return _can_equip_stack_to_slot(source_stack, equipment_slot_id)


## Moves a bag slot into an equipment slot, swapping back any existing gear.
func equip_from_slot(source_index: int, equipment_slot_id: String) -> bool:
	if not can_equip_from_slot(source_index, equipment_slot_id):
		return false

	var source_stack := _slots[source_index] as Resource
	var equipped_stack := _equipped_stack_at(equipment_slot_id)
	_equipped_slots[equipment_slot_id] = source_stack
	_slots[source_index] = equipped_stack

	slot_changed.emit(source_index)
	slots_changed.emit()
	equipped_slots_changed.emit()
	return true


## Returns true if equipped gear can be moved into the requested bag slot.
func can_unequip_to_slot(equipment_slot_id: String, target_index: int) -> bool:
	if not _is_valid_slot_index(target_index):
		return false

	var equipped_stack := _equipped_stack_at(equipment_slot_id)
	if equipped_stack == null:
		return false

	var target_stack := _slots[target_index] as Resource
	return target_stack == null or _can_equip_stack_to_slot(target_stack, equipment_slot_id)


## Moves equipped gear into a bag slot, swapping back compatible gear if present.
func unequip_to_slot(equipment_slot_id: String, target_index: int) -> bool:
	if not can_unequip_to_slot(equipment_slot_id, target_index):
		return false

	var equipped_stack := _equipped_stack_at(equipment_slot_id)
	var target_stack := _slots[target_index] as Resource
	_slots[target_index] = equipped_stack
	if target_stack == null:
		_equipped_slots.erase(equipment_slot_id)
	else:
		_equipped_slots[equipment_slot_id] = target_stack

	slot_changed.emit(target_index)
	slots_changed.emit()
	equipped_slots_changed.emit()
	return true


## Returns true if one equipped slot can be moved or swapped into another slot.
func can_move_equipped_slot(source_slot_id: String, target_slot_id: String) -> bool:
	if source_slot_id == target_slot_id:
		return false

	var source_stack := _equipped_stack_at(source_slot_id)
	if source_stack == null or not _can_equip_stack_to_slot(source_stack, target_slot_id):
		return false

	var target_stack := _equipped_stack_at(target_slot_id)
	return target_stack == null or _can_equip_stack_to_slot(target_stack, source_slot_id)


## Moves or swaps items between two equipped slots.
func move_or_swap_equipped_slots(source_slot_id: String, target_slot_id: String) -> bool:
	if not can_move_equipped_slot(source_slot_id, target_slot_id):
		return false

	var source_stack := _equipped_stack_at(source_slot_id)
	var target_stack := _equipped_stack_at(target_slot_id)
	if target_stack == null:
		_equipped_slots.erase(source_slot_id)
	else:
		_equipped_slots[source_slot_id] = target_stack
	_equipped_slots[target_slot_id] = source_stack

	equipped_slots_changed.emit()
	return true


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


func _seed_debug_items() -> void:
	for item_id in debug_seed_item_ids:
		if String(item_id).is_empty():
			continue

		add_item(String(item_id), debug_seed_quantity)


func _seed_debug_equipment() -> void:
	if debug_main_hand_item_id.is_empty():
		return

	var definition := get_definition(debug_main_hand_item_id)
	if definition == null:
		push_warning("Debug main-hand item id is unknown: %s" % debug_main_hand_item_id)
		return

	var stack := _create_stack(definition, 1)
	if not _can_equip_stack_to_slot(stack, "main_hand"):
		push_warning("Debug main-hand item cannot equip to main_hand: %s" % debug_main_hand_item_id)
		return

	_equipped_slots["main_hand"] = stack


func _get_prototype_definitions() -> Array:
	_ensure_prototype_definitions()
	return _prototype_definitions


func _ensure_prototype_definitions() -> void:
	if not _definitions_by_id.is_empty():
		return

	_prototype_definitions = []
	for definition in PrototypeItemCatalogScript.create_prototype_definitions():
		var item_definition := definition as Resource
		if item_definition != null and not String(item_definition.id).is_empty():
			_prototype_definitions.append(item_definition)
			_definitions_by_id[item_definition.id] = item_definition


func _create_stack(definition: Resource, quantity: int) -> Resource:
	var stack: Resource = ItemStackScript.new() as Resource
	stack.call("configure", definition, quantity)
	return stack


func _is_same_definition(left_definition: Resource, right_definition: Resource) -> bool:
	if left_definition == right_definition:
		return true
	if left_definition == null or right_definition == null:
		return false

	var left_id := String(left_definition.get("id"))
	var right_id := String(right_definition.get("id"))
	return not left_id.is_empty() and left_id == right_id


func _equipped_stack_at(equipment_slot_id: String) -> Resource:
	return _equipped_slots.get(equipment_slot_id) as Resource


func _can_equip_stack_to_slot(stack: Resource, equipment_slot_id: String) -> bool:
	if stack == null or stack.is_empty() or equipment_slot_id.is_empty():
		return false

	var definition: Resource = stack.get("definition") as Resource
	if definition == null:
		return false

	return String(definition.get("equip_slot")) == equipment_slot_id


func _prototype_quantity(family_id: String, tier: int) -> int:
	var quantity_step := 53
	match family_id:
		"logs":
			quantity_step = 83
		"planks":
			quantity_step = 79
		"blocks":
			quantity_step = 67
		"ingots":
			quantity_step = 61
		"cloth":
			quantity_step = 73
		"worked_leather":
			quantity_step = 57
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
