## Drag source for one loot item row.
##
## The row delegates data and preview creation back to LootPanel so the panel
## remains the only UI class that knows which container is currently open.
class_name LootItemRow
extends HBoxContainer

var _loot_panel: Node
var _item_index := -1


func setup(loot_panel: Node, item_index: int) -> void:
	_loot_panel = loot_panel
	_item_index = item_index
	mouse_filter = Control.MOUSE_FILTER_STOP


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _loot_panel == null or not _loot_panel.has_method("get_item_drag_data"):
		return null

	var drag_data: Variant = _loot_panel.call("get_item_drag_data", _item_index)
	if drag_data == null:
		return null

	if _loot_panel.has_method("create_item_drag_preview"):
		var preview := _loot_panel.call("create_item_drag_preview", _item_index) as Control
		if preview != null:
			set_drag_preview(preview)

	return drag_data
