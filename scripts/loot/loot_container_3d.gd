## Interactable world loot holder.
##
## LootContainer3D stores the items/currency dropped into a loot bag and exposes
## a small command surface for the UI. The container does not know how inventory
## is drawn; it only transfers loot into an inventory-like node.
class_name LootContainer3D
extends Node3D

signal loot_changed
signal emptied

## Name shown in the loot window title.
@export var display_name := "Loot Bag"
## Distance from the bag center where the player can open it.
@export_range(0.1, 6.0, 0.05) var interaction_radius := 1.0
## Optional specific panel path. Empty means use the first node in `loot_panel`.
@export var loot_panel_path: NodePath
## Removes the bag once all loot has been claimed.
@export var despawn_when_empty := true
## Safety cleanup for forgotten bags.
@export_range(0.0, 600.0, 1.0) var despawn_after_seconds := 120.0

var _items: Array[Dictionary] = []
var _silver := 0
var _gold := 0


func _ready() -> void:
	add_to_group("loot_container")
	_sync_selectable_display_name()
	if despawn_after_seconds > 0.0:
		_start_despawn_timer()


## Replaces the bag contents with normalized drop data.
func configure_loot(loot_data: Dictionary) -> void:
	_silver = maxi(int(loot_data.get("silver", 0)), 0)
	_gold = maxi(int(loot_data.get("gold", 0)), 0)
	_items = _normalize_items(loot_data.get("items", []))
	loot_changed.emit()
	if is_empty():
		_handle_empty()


## Opens the loot panel if the actor is close enough.
func open_loot_menu(actor: Node = null) -> bool:
	if actor != null and not can_interact_from(actor):
		return false

	var panel := _find_loot_panel()
	if panel == null or not panel.has_method("open_for_loot_container"):
		push_warning("No LootPanel found for container: %s" % name)
		return false

	panel.call("open_for_loot_container", self)
	return true


## Returns true when an actor can loot this bag now.
func can_interact_from(actor: Node) -> bool:
	var actor_3d := actor as Node3D
	if actor_3d == null:
		return false

	var offset := actor_3d.global_position - global_position
	offset.y = 0.0
	return offset.length() <= interaction_radius


## Returns a world position close enough to open this bag.
func get_interaction_destination(actor: Node) -> Vector3:
	var actor_3d := actor as Node3D
	if actor_3d == null:
		return global_position

	var direction := actor_3d.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	else:
		direction = direction.normalized()

	var destination := global_position + direction * maxf(interaction_radius * 0.75, 0.05)
	destination.y = actor_3d.global_position.y
	return destination


## Returns a UI-safe snapshot of this bag's contents.
func get_loot_data() -> Dictionary:
	return {
		"display_name": display_name,
		"silver": _silver,
		"gold": _gold,
		"items": _items.duplicate(true),
	}


func is_empty() -> bool:
	return _silver <= 0 and _gold <= 0 and _items.is_empty()


## Transfers all currency to the target inventory.
func take_currency(inventory: Node) -> bool:
	if inventory == null or not inventory.has_method("set_currency"):
		return false
	if _silver <= 0 and _gold <= 0:
		return false

	var current_silver := int(inventory.call("get_silver")) if inventory.has_method("get_silver") else 0
	var current_gold := int(inventory.call("get_gold")) if inventory.has_method("get_gold") else 0
	inventory.call("set_currency", current_silver + _silver, current_gold + _gold)
	_silver = 0
	_gold = 0
	loot_changed.emit()
	_check_empty_after_transfer()
	return true


## Transfers one item row into the target inventory.
func take_item_at(item_index: int, inventory: Node) -> bool:
	if inventory == null or not inventory.has_method("add_item"):
		return false
	if item_index < 0 or item_index >= _items.size():
		return false

	var item := _items[item_index]
	var item_id := String(item.get("item_id", ""))
	var quantity := maxi(int(item.get("quantity", 0)), 0)
	if item_id.is_empty() or quantity <= 0:
		_items.remove_at(item_index)
		loot_changed.emit()
		_check_empty_after_transfer()
		return false

	var remainder := int(inventory.call("add_item", item_id, quantity))
	var moved_quantity := quantity - remainder
	if moved_quantity <= 0:
		return false

	if remainder > 0:
		item["quantity"] = remainder
		_items[item_index] = item
	else:
		_items.remove_at(item_index)

	loot_changed.emit()
	_check_empty_after_transfer()
	return true


## Transfers currency and as many items as will fit.
func take_all(inventory: Node) -> bool:
	var moved_any := take_currency(inventory)
	for item_index in range(_items.size() - 1, -1, -1):
		if take_item_at(item_index, inventory):
			moved_any = true

	_check_empty_after_transfer()
	return moved_any


func _normalize_items(raw_items: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if not (raw_items is Array):
		return normalized

	for raw_item in raw_items:
		if not (raw_item is Dictionary):
			continue

		var item := raw_item as Dictionary
		var item_id := String(item.get("item_id", ""))
		var quantity := maxi(int(item.get("quantity", 0)), 0)
		if item_id.is_empty() or quantity <= 0:
			continue

		normalized.append({
			"item_id": item_id,
			"quantity": quantity,
		})

	return normalized


func _find_loot_panel() -> Node:
	if loot_panel_path != NodePath(""):
		var panel := get_node_or_null(loot_panel_path)
		if panel != null:
			return panel

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("loot_panel")


func _sync_selectable_display_name() -> void:
	var selectable := get_node_or_null("Selectable")
	if selectable != null and selectable.has_method("get_relationship"):
		selectable.set("display_name", display_name)


func _check_empty_after_transfer() -> void:
	if is_empty():
		_handle_empty()


func _handle_empty() -> void:
	emptied.emit()
	if despawn_when_empty:
		queue_free()


func _start_despawn_timer() -> void:
	await get_tree().create_timer(despawn_after_seconds).timeout
	if is_inside_tree():
		queue_free()
