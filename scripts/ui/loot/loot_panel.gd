## Prototype loot window.
##
## This panel reads from a LootContainer3D and transfers rewards into the player
## inventory. The container owns loot state; this class owns only presentation.
class_name LootPanel
extends CanvasLayer

const InventoryItemIconScript := preload("res://scripts/ui/inventory/inventory_item_icon.gd")
const LootItemRowScript := preload("res://scripts/ui/loot/loot_item_row.gd")
const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"
const LOOT_DRAG_TYPE := "elderforge_loot_item"

## Inventory that receives claimed loot. Empty means first `player_inventory`.
@export var inventory_path: NodePath
## Inventory panel shown next to the loot window for drag-and-drop looting.
@export var inventory_panel_path: NodePath
## Shows the window at scene start for isolated UI previews.
@export var start_visible := false

var _inventory: Node
var _inventory_panel: Node
var _inventory_panel_was_visible := false
var _container: Node
var _root: Control
var _window: PanelContainer
var _title_label: Label
var _rows_container: VBoxContainer
var _status_label: Label
var _take_all_button: Button
var _block_world_input_until_mouse_release := false


func _ready() -> void:
	layer = 30
	add_to_group("loot_panel")
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	visible = start_visible
	_build_window()
	_bind_inventory()
	_refresh()


## Opens this panel for one world loot container.
func open_for_loot_container(container: Node) -> void:
	_disconnect_container()
	_container = container
	if _container != null and _container.has_signal("loot_changed"):
		_container.loot_changed.connect(_on_container_loot_changed)
	if _container != null and _container.has_signal("emptied"):
		_container.emptied.connect(_on_container_emptied)

	_bind_inventory()
	visible = true
	_block_world_input_until_mouse_release = false
	_refresh()
	_open_inventory_companion()


func close() -> void:
	_disconnect_container()
	_container = null
	visible = false
	_block_world_input_until_mouse_release = _is_world_move_mouse_button_down()
	_close_inventory_companion()


## Returns true while this window should prevent world clicks and movement.
func blocks_world_input() -> bool:
	if visible:
		return true

	if _block_world_input_until_mouse_release:
		if _is_world_move_mouse_button_down():
			return true
		_block_world_input_until_mouse_release = false

	return false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_window() -> void:
	if _root != null:
		return

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	_window = PanelContainer.new()
	_window.name = "Window"
	_window.custom_minimum_size = Vector2(430.0, 350.0)
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -215.0
	_window.offset_top = -175.0
	_window.offset_right = 215.0
	_window.offset_bottom = 175.0
	_window.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_window)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_window.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	layout.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	_rows_container = VBoxContainer.new()
	_rows_container.name = "Rows"
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows_container)

	layout.add_child(_build_footer())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 38.0)
	header.add_theme_constant_override("separation", 10)

	_title_label = Label.new()
	_title_label.text = "Loot"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.38, 1.0))
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_title_label.add_theme_constant_override("outline_size", 2)
	header.add_child(_title_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(36.0, 32.0)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	return header


func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0.0, 44.0)
	footer.add_theme_constant_override("separation", 12)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74, 1.0))
	footer.add_child(_status_label)

	_take_all_button = Button.new()
	_take_all_button.text = "Take All"
	_take_all_button.custom_minimum_size = Vector2(112.0, 38.0)
	_take_all_button.pressed.connect(_on_take_all_pressed)
	footer.add_child(_take_all_button)
	return footer


func _refresh() -> void:
	if _title_label == null:
		return

	_clear_rows()
	var loot_data := _loot_data()
	_title_label.text = String(loot_data.get("display_name", "Loot"))

	if _inventory == null:
		_status_label.text = "Inventory unavailable."
		_take_all_button.disabled = true
		return

	var silver := maxi(int(loot_data.get("silver", 0)), 0)
	var gold := maxi(int(loot_data.get("gold", 0)), 0)
	var items: Array = loot_data.get("items", [])

	if silver > 0:
		_rows_container.add_child(_build_currency_row("Silver", silver, Color(0.78, 0.76, 0.70, 1.0)))
	if gold > 0:
		_rows_container.add_child(_build_currency_row("Gold", gold, Color(1.0, 0.82, 0.28, 1.0)))

	for index in range(items.size()):
		var item := items[index] as Dictionary
		_rows_container.add_child(_build_item_row(index, item))

	var has_loot := silver > 0 or gold > 0 or not items.is_empty()
	_take_all_button.disabled = not has_loot
	_status_label.text = "Ready." if has_loot else "Empty."


func _build_currency_row(currency_name: String, amount: int, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 58.0)
	row.add_theme_constant_override("separation", 12)

	var icon := ColorRect.new()
	icon.color = color
	icon.custom_minimum_size = Vector2(46.0, 46.0)
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = currency_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 1.0))
	row.add_child(name_label)

	var amount_label := Label.new()
	amount_label.text = "%d" % amount
	amount_label.custom_minimum_size = Vector2(92.0, 0.0)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", 17)
	amount_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.43, 1.0))
	row.add_child(amount_label)

	var take_button := Button.new()
	take_button.text = "Take"
	take_button.custom_minimum_size = Vector2(70.0, 34.0)
	take_button.pressed.connect(_on_take_currency_pressed)
	row.add_child(take_button)
	return row


func _build_item_row(item_index: int, item: Dictionary) -> Control:
	var row := LootItemRowScript.new() as HBoxContainer
	row.custom_minimum_size = Vector2(0.0, 66.0)
	row.add_theme_constant_override("separation", 12)
	row.call("setup", self, item_index)

	var item_id := String(item.get("item_id", ""))
	var quantity := maxi(int(item.get("quantity", 0)), 0)

	var icon := InventoryItemIconScript.new() as Control
	icon.custom_minimum_size = Vector2(58.0, 58.0)
	_set_icon_item(icon, item_id, quantity)
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = _item_name(item_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 1.0))
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "%d" % quantity
	count_label.custom_minimum_size = Vector2(64.0, 0.0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 17)
	count_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.43, 1.0))
	row.add_child(count_label)

	var take_button := Button.new()
	take_button.text = "Take"
	take_button.custom_minimum_size = Vector2(70.0, 34.0)
	take_button.disabled = not _can_fit_item(item_id, quantity)
	take_button.pressed.connect(_on_take_item_pressed.bind(item_index))
	row.add_child(take_button)
	return row


## Returns drag payload for one loot row.
func get_item_drag_data(item_index: int) -> Variant:
	var item := _loot_item_at(item_index)
	if item.is_empty() or _container == null:
		return null

	return {
		"type": LOOT_DRAG_TYPE,
		"source_container": _container,
		"item_index": item_index,
	}


## Builds the small item preview shown under the cursor while dragging loot.
func create_item_drag_preview(item_index: int) -> Control:
	var item := _loot_item_at(item_index)
	if item.is_empty():
		return null

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(64.0, 64.0)
	preview.size = Vector2(64.0, 64.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.88)

	var item_icon := InventoryItemIconScript.new() as Control
	item_icon.name = "DraggedLootIcon"
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_set_icon_item(item_icon, String(item.get("item_id", "")), int(item.get("quantity", 1)))
	preview.add_child(item_icon)
	return preview


func _on_take_currency_pressed() -> void:
	if _container != null and _container.has_method("take_currency"):
		_container.call("take_currency", _inventory)
	_refresh_or_close_if_empty()


func _on_take_item_pressed(item_index: int) -> void:
	if _container == null or not _container.has_method("take_item_at"):
		return

	if not bool(_container.call("take_item_at", item_index, _inventory)):
		_status_label.text = "No inventory space."
	_refresh_or_close_if_empty()


func _on_take_all_pressed() -> void:
	if _container == null or not _container.has_method("take_all"):
		return

	if not bool(_container.call("take_all", _inventory)):
		_status_label.text = "No inventory space."
	_refresh_or_close_if_empty()


func _refresh_or_close_if_empty() -> void:
	if _container != null and _container.has_method("is_empty") and bool(_container.call("is_empty")):
		close()
		return

	_refresh()


func _loot_data() -> Dictionary:
	if _container != null and _container.has_method("get_loot_data"):
		return _container.call("get_loot_data")

	return {}


func _loot_item_at(item_index: int) -> Dictionary:
	var loot_data := _loot_data()
	var items: Array = loot_data.get("items", [])
	if item_index < 0 or item_index >= items.size():
		return {}

	var item := items[item_index] as Dictionary
	return item if item != null else {}


func _set_icon_item(icon: Control, item_id: String, quantity: int) -> void:
	if icon == null:
		return

	var definition := _get_definition(item_id)
	if definition == null:
		icon.call("clear_item")
		return

	icon.call("set_item", definition.call("to_display_dict", quantity))


func _item_name(item_id: String) -> String:
	var definition := _get_definition(item_id)
	if definition == null:
		return item_id if not item_id.is_empty() else "Unknown Item"

	return String(definition.get("display_name"))


func _can_fit_item(item_id: String, quantity: int) -> bool:
	if _inventory == null or item_id.is_empty():
		return false
	if not _inventory.has_method("get_addable_count"):
		return true

	return int(_inventory.call("get_addable_count", item_id)) >= quantity


func _get_definition(item_id: String) -> Resource:
	if _inventory == null or item_id.is_empty() or not _inventory.has_method("get_definition"):
		return null

	return _inventory.call("get_definition", item_id) as Resource


func _bind_inventory() -> void:
	_inventory = _find_inventory()
	_inventory_panel = _find_inventory_panel()


func _find_inventory() -> Node:
	if inventory_path != NodePath(""):
		var inventory := get_node_or_null(inventory_path)
		if inventory != null:
			return inventory

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("player_inventory")


func _find_inventory_panel() -> Node:
	if inventory_panel_path != NodePath(""):
		var panel := get_node_or_null(inventory_panel_path)
		if panel != null:
			return panel

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("inventory_panel")


func _open_inventory_companion() -> void:
	if _window == null:
		return

	if _inventory_panel == null:
		_inventory_panel = _find_inventory_panel()
	if _inventory_panel == null:
		return

	_inventory_panel_was_visible = bool(_inventory_panel.get("visible"))
	if _inventory_panel.has_method("open_next_to"):
		_inventory_panel.call("open_next_to", _window.get_global_rect())
	elif _inventory_panel.has_method("open"):
		_inventory_panel.call("open")


func _close_inventory_companion() -> void:
	if _inventory_panel == null:
		return

	if not _inventory_panel_was_visible and _inventory_panel.has_method("close"):
		_inventory_panel.call("close")
	elif _inventory_panel.has_method("restore_default_layout"):
		_inventory_panel.call("restore_default_layout")


func _disconnect_container() -> void:
	if _container == null:
		return

	var loot_changed_callable := Callable(self, "_on_container_loot_changed")
	if _container.has_signal("loot_changed") and _container.is_connected("loot_changed", loot_changed_callable):
		_container.disconnect("loot_changed", loot_changed_callable)

	var emptied_callable := Callable(self, "_on_container_emptied")
	if _container.has_signal("emptied") and _container.is_connected("emptied", emptied_callable):
		_container.disconnect("emptied", emptied_callable)


func _on_container_loot_changed() -> void:
	_refresh()


func _on_container_emptied() -> void:
	close()


func _clear_rows() -> void:
	if _rows_container == null:
		return

	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()


func _is_world_move_mouse_button_down() -> bool:
	return (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.065, 0.96)
	style.border_color = Color(0.70, 0.52, 0.25, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style
