## Bag slot button that forwards drag-and-drop events to InventoryPanel.
##
## The slot button owns only UI interaction plumbing. InventoryPanel remains the
## source of truth for item data, slot swapping, selection, and previews.
class_name InventorySlotButton
extends Button

var _inventory_panel: Node
var _slot_index := -1


## Connects this UI slot to its owning inventory panel and slot index.
func setup(inventory_panel: Node, slot_index: int) -> void:
	_inventory_panel = inventory_panel
	_slot_index = slot_index


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _inventory_panel == null:
		return null

	var drag_data: Variant = _inventory_panel.call("get_slot_drag_data", _slot_index)
	if drag_data == null:
		return null

	var preview := _inventory_panel.call("create_slot_drag_preview", _slot_index) as Control
	if preview != null:
		set_drag_preview(preview)

	return drag_data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _inventory_panel == null:
		return false

	return bool(_inventory_panel.call("can_drop_slot_data", _slot_index, data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _inventory_panel == null:
		return

	_inventory_panel.call("drop_slot_data", _slot_index, data)
