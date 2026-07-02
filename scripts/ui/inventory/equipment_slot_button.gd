## Equipped gear slot button that forwards drag-and-drop to EquipmentPanel.
##
## The button owns only Godot UI event hooks. EquipmentPanel and PlayerInventory
## decide what can be equipped, unequipped, or swapped.
class_name EquipmentSlotButton
extends Button

var _equipment_panel: Node
var _slot_id := ""


## Connects this button to its owning equipment panel and slot id.
func setup(equipment_panel: Node, slot_id: String) -> void:
	_equipment_panel = equipment_panel
	_slot_id = slot_id


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _equipment_panel == null:
		return null

	var drag_data: Variant = _equipment_panel.call("get_gear_slot_drag_data", _slot_id)
	if drag_data == null:
		return null

	var preview := _equipment_panel.call("create_gear_slot_drag_preview", _slot_id) as Control
	if preview != null:
		set_drag_preview(preview)

	return drag_data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _equipment_panel == null:
		return false

	return bool(_equipment_panel.call("can_drop_gear_slot_data", _slot_id, data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _equipment_panel == null:
		return

	_equipment_panel.call("drop_gear_slot_data", _slot_id, data)
