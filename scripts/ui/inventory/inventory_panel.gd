## Toggleable inventory window for the current local prototype.
##
## This script owns presentation state only: window visibility, selected slot UI,
## drag/drop forwarding, and details rendering. `PlayerInventory` owns item and
## currency state, then this panel mirrors that data through signals.
class_name InventoryPanel
extends CanvasLayer

const EMPTY_SLOT := {}
const EquipmentPanelScene := preload("res://scenes/ui/inventory/EquipmentPanel.tscn")
const InventoryItemIconScript := preload("res://scripts/ui/inventory/inventory_item_icon.gd")
const InventorySlotButtonScript := preload("res://scripts/ui/inventory/inventory_slot_button.gd")
const PlayerInventoryScript := preload("res://scripts/inventory/player_inventory.gd")
const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"
const MAX_VISIBLE_SLOTS := 42
const SLOT_DRAG_TYPE := "elderforge_inventory_slot"
const EQUIPMENT_DRAG_TYPE := "elderforge_equipment_slot"

## Optional external inventory node. Main.tscn points this at PlayerInventory.
@export var inventory_path: NodePath
## Optional player stats node. Main.tscn points this at Player/Stats.
@export var stats_path: NodePath
## Keyboard key used to open and close the inventory.
@export var toggle_key: Key = KEY_I
## Number of visible inventory slots.
@export_range(1, MAX_VISIBLE_SLOTS, 1) var slot_count: int = MAX_VISIBLE_SLOTS
## Number of columns used by the slot grid.
@export_range(1, 10, 1) var columns: int = 6
## Shows the panel when the scene starts. Keep off for normal gameplay.
@export var start_visible: bool = false
## Fallback silver amount when this panel creates a local preview inventory.
@export var starting_silver: int = 0
## Fallback gold amount when this panel creates a local preview inventory.
@export var starting_gold: int = 0

var _root: Control
var _grid: GridContainer
var _weight_label: Label
var _silver_label: Label
var _gold_label: Label
var _detail_name: Label
var _detail_category: Label
var _detail_stack: Label
var _detail_description: Label
var _stats_list: VBoxContainer
var _stats_empty_label: Label
var _equipment_panel: Node
var _inventory: Node
var _stats: Node
var _slot_buttons: Array[Button] = []
var _slot_item_icons: Array[Control] = []
var _slots: Array = []
var _equipped_slots := {}
var _silver_amount := 0
var _gold_amount := 0
var _selected_index := -1
var _selected_equipment_slot_id := ""
var _block_world_input_until_mouse_release := false


func _ready() -> void:
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	visible = start_visible
	_bind_inventory()
	_bind_stats()
	_create_placeholder_equipment()
	_build_window()
	_sync_from_inventory()
	_refresh_all_slots()
	_refresh_stats()
	_select_first_filled_slot()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null:
		return

	if key_event.pressed and not key_event.echo and key_event.keycode == toggle_key:
		toggle()
		get_viewport().set_input_as_handled()


## Opens the inventory window.
func open() -> void:
	visible = true
	_block_world_input_until_mouse_release = false


## Closes the inventory window.
func close() -> void:
	visible = false
	_block_world_input_until_mouse_release = _is_world_move_mouse_button_down()


## Swaps between open and closed states.
func toggle() -> void:
	visible = not visible
	if visible:
		_block_world_input_until_mouse_release = false
	else:
		_block_world_input_until_mouse_release = _is_world_move_mouse_button_down()


## Returns true while this window should prevent world clicks and movement.
func blocks_world_input() -> bool:
	if visible:
		return true

	if _block_world_input_until_mouse_release:
		if _is_world_move_mouse_button_down():
			return true
		_block_world_input_until_mouse_release = false

	return false


func _is_world_move_mouse_button_down() -> bool:
	return (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)


## Replaces the displayed slots with external inventory data.
##
## This remains for compatibility with simple UI previews. Normal gameplay
## should update PlayerInventory instead.
func set_slots(new_slots: Array) -> void:
	_slots = new_slots.duplicate(true)
	_normalize_slot_count()
	_selected_index = -1
	_selected_equipment_slot_id = ""
	if _equipment_panel != null:
		_equipment_panel.call("clear_selection")
	_refresh_all_slots()
	_select_first_filled_slot()


## Replaces the displayed equipped gear slots.
##
## Normal gameplay should update PlayerInventory once equipment storage exists.
func set_equipped_slots(new_equipped_slots: Dictionary) -> void:
	_equipped_slots = new_equipped_slots.duplicate(true)
	if _equipment_panel != null:
		_equipment_panel.call("set_equipped_slots", _equipped_slots)
	_refresh_details()


## Updates the displayed currency totals.
func set_currency(silver: int, gold: int) -> void:
	if _inventory != null and _inventory.has_method("set_currency"):
		_inventory.call("set_currency", silver, gold)
		return

	_silver_amount = maxi(silver, 0)
	_gold_amount = maxi(gold, 0)
	_refresh_currency_display()


## Binds this UI panel to the authoritative inventory node.
func set_inventory(inventory: Node) -> void:
	if _inventory == inventory:
		return

	_disconnect_inventory_signals()
	_inventory = inventory
	_connect_inventory_signals()
	if _inventory != null and _inventory.has_method("get_slot_count"):
		slot_count = clampi(int(_inventory.call("get_slot_count")), 1, MAX_VISIBLE_SLOTS)
	_sync_from_inventory()
	if _root != null:
		_rebuild_slot_grid()
		_refresh_all_slots()
		_select_first_filled_slot()


## Binds this UI panel to the authoritative player stats node.
func set_stats(stats: Node) -> void:
	if _stats == stats:
		return

	_disconnect_stats_signals()
	_stats = stats
	_connect_stats_signals()
	_refresh_stats()


func _bind_inventory() -> void:
	var target_inventory: Node = null
	if not inventory_path.is_empty():
		target_inventory = get_node_or_null(inventory_path)

	if target_inventory == null:
		target_inventory = _create_local_inventory()

	set_inventory(target_inventory)


func _bind_stats() -> void:
	set_stats(_find_stats())


func _create_local_inventory() -> Node:
	var inventory := Node.new()
	inventory.name = "LocalInventory"
	inventory.set_script(PlayerInventoryScript)
	add_child(inventory)
	inventory.call("initialize_default_resources", slot_count, starting_silver, starting_gold)
	return inventory


func _connect_inventory_signals() -> void:
	if _inventory == null:
		return

	if _inventory.has_signal("slots_changed") and not _inventory.is_connected("slots_changed", Callable(self, "_on_inventory_slots_changed")):
		_inventory.connect("slots_changed", Callable(self, "_on_inventory_slots_changed"))
	if _inventory.has_signal("currency_changed") and not _inventory.is_connected("currency_changed", Callable(self, "_on_inventory_currency_changed")):
		_inventory.connect("currency_changed", Callable(self, "_on_inventory_currency_changed"))
	if _inventory.has_signal("equipped_slots_changed") and not _inventory.is_connected("equipped_slots_changed", Callable(self, "_on_inventory_equipped_slots_changed")):
		_inventory.connect("equipped_slots_changed", Callable(self, "_on_inventory_equipped_slots_changed"))


func _connect_stats_signals() -> void:
	if _stats == null:
		return

	var stat_callable := Callable(self, "_on_player_stat_changed")
	if _stats.has_signal("stat_changed") and not _stats.is_connected("stat_changed", stat_callable):
		_stats.connect("stat_changed", stat_callable)


func _disconnect_inventory_signals() -> void:
	if _inventory == null:
		return

	var slots_callable := Callable(self, "_on_inventory_slots_changed")
	if _inventory.has_signal("slots_changed") and _inventory.is_connected("slots_changed", slots_callable):
		_inventory.disconnect("slots_changed", slots_callable)

	var currency_callable := Callable(self, "_on_inventory_currency_changed")
	if _inventory.has_signal("currency_changed") and _inventory.is_connected("currency_changed", currency_callable):
		_inventory.disconnect("currency_changed", currency_callable)

	var equipped_callable := Callable(self, "_on_inventory_equipped_slots_changed")
	if _inventory.has_signal("equipped_slots_changed") and _inventory.is_connected("equipped_slots_changed", equipped_callable):
		_inventory.disconnect("equipped_slots_changed", equipped_callable)


func _disconnect_stats_signals() -> void:
	if _stats == null:
		return

	var stat_callable := Callable(self, "_on_player_stat_changed")
	if _stats.has_signal("stat_changed") and _stats.is_connected("stat_changed", stat_callable):
		_stats.disconnect("stat_changed", stat_callable)


func _sync_from_inventory() -> void:
	if _inventory == null:
		_silver_amount = maxi(starting_silver, 0)
		_gold_amount = maxi(starting_gold, 0)
		_refresh_currency_display()
		return

	if _inventory.has_method("get_slot_count"):
		slot_count = clampi(int(_inventory.call("get_slot_count")), 1, MAX_VISIBLE_SLOTS)
	if _inventory.has_method("get_display_slots"):
		_slots = _inventory.call("get_display_slots")
		_normalize_slot_count()
	if _inventory.has_method("get_equipped_slots"):
		_equipped_slots = _inventory.call("get_equipped_slots")
		if _equipment_panel != null:
			_equipment_panel.call("set_equipped_slots", _equipped_slots)
	if _inventory.has_method("get_silver"):
		_silver_amount = int(_inventory.call("get_silver"))
	if _inventory.has_method("get_gold"):
		_gold_amount = int(_inventory.call("get_gold"))
	_refresh_currency_display()


func _on_inventory_slots_changed() -> void:
	_sync_from_inventory()
	_refresh_all_slots()


func _on_inventory_currency_changed(silver: int, gold: int) -> void:
	_silver_amount = maxi(silver, 0)
	_gold_amount = maxi(gold, 0)
	_refresh_currency_display()


func _on_inventory_equipped_slots_changed() -> void:
	if _inventory != null and _inventory.has_method("get_equipped_slots"):
		_equipped_slots = _inventory.call("get_equipped_slots")
	if _equipment_panel != null:
		_equipment_panel.call("set_equipped_slots", _equipped_slots)
	_refresh_details()


func _on_player_stat_changed(_stat_id: StringName, _value: float) -> void:
	_refresh_stats()


## Returns drag payload for a filled bag slot.
func get_slot_drag_data(slot_index: int) -> Variant:
	if not _is_valid_slot_index(slot_index):
		return null

	var slot := _slot_at(slot_index)
	if slot.is_empty():
		return null

	return {
		"type": SLOT_DRAG_TYPE,
		"source_index": slot_index,
	}


## Returns drag payload for a filled equipped slot.
func get_equipment_slot_drag_data(slot_id: String) -> Variant:
	var slot := _equipped_slot_at(slot_id)
	if slot.is_empty():
		return null

	return {
		"type": EQUIPMENT_DRAG_TYPE,
		"source_slot_id": slot_id,
	}


## Builds the small item preview shown under the cursor while dragging.
func create_slot_drag_preview(slot_index: int) -> Control:
	if not _is_valid_slot_index(slot_index):
		return null

	var slot := _slot_at(slot_index)
	if slot.is_empty():
		return null

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(64.0, 64.0)
	preview.size = Vector2(64.0, 64.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.88)

	var item_icon := Control.new()
	item_icon.name = "DraggedItemIcon"
	item_icon.set_script(InventoryItemIconScript)
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_icon.call("set_item", slot)
	preview.add_child(item_icon)

	return preview


## Accepts drops from another bag slot.
func can_drop_slot_data(target_index: int, data: Variant) -> bool:
	if not _is_valid_slot_index(target_index):
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var drag_data := data as Dictionary
	var drag_type := String(drag_data.get("type", ""))
	if drag_type == EQUIPMENT_DRAG_TYPE:
		var source_slot_id := String(drag_data.get("source_slot_id", ""))
		return (
			_inventory != null
			and _inventory.has_method("can_unequip_to_slot")
			and bool(_inventory.call("can_unequip_to_slot", source_slot_id, target_index))
		)
	if drag_type != SLOT_DRAG_TYPE:
		return false

	var source_index := int(drag_data.get("source_index", -1))
	return _is_valid_slot_index(source_index) and source_index != target_index


## Moves or swaps item stacks when a dragged item is released over a bag slot.
func drop_slot_data(target_index: int, data: Variant) -> void:
	if not can_drop_slot_data(target_index, data):
		return

	var drag_data := data as Dictionary
	var drag_type := String(drag_data.get("type", ""))
	if drag_type == EQUIPMENT_DRAG_TYPE:
		var source_slot_id := String(drag_data.get("source_slot_id", ""))
		if _inventory != null and _inventory.has_method("unequip_to_slot"):
			if bool(_inventory.call("unequip_to_slot", source_slot_id, target_index)):
				_selected_index = target_index
				_selected_equipment_slot_id = ""
				if _equipment_panel != null:
					_equipment_panel.call("clear_selection")
				_refresh_details()
		return

	var source_index := int(drag_data.get("source_index", -1))
	if _inventory != null and _inventory.has_method("move_or_swap_slots"):
		if bool(_inventory.call("move_or_swap_slots", source_index, target_index)):
			_selected_index = target_index
			_selected_equipment_slot_id = ""
			if _equipment_panel != null:
				_equipment_panel.call("clear_selection")
			_refresh_details()
		return

	var source_slot := _slot_at(source_index).duplicate(true)
	var target_slot := _slot_at(target_index).duplicate(true)
	if source_slot.is_empty():
		return

	_slots[target_index] = source_slot
	_slots[source_index] = target_slot
	_selected_index = target_index
	_selected_equipment_slot_id = ""
	if _equipment_panel != null:
		_equipment_panel.call("clear_selection")

	_refresh_all_slots()


func _build_window() -> void:
	_root = Control.new()
	_root.name = "InventoryRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.18)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "Window"
	panel.custom_minimum_size = Vector2(1020.0, 620.0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -510.0
	panel.offset_top = -310.0
	panel.offset_right = 510.0
	panel.offset_bottom = 310.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	layout.add_child(_build_header())
	layout.add_child(_build_tabs())


func _build_tabs() -> Control:
	var tabs := TabContainer.new()
	tabs.name = "InventoryTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var inventory_tab := _build_body()
	inventory_tab.name = "Inventory"
	tabs.add_child(inventory_tab)

	var stats_tab := _build_stats_tab()
	stats_tab.name = "Stats"
	tabs.add_child(stats_tab)
	return tabs


func _build_header() -> Control:
	var header := Control.new()
	header.custom_minimum_size = Vector2(0.0, 34.0)

	var title := Label.new()
	title.text = "Inventory"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_top = 0.0
	title.anchor_right = 0.0
	title.anchor_bottom = 1.0
	title.offset_left = 0.0
	title.offset_top = 0.0
	title.offset_right = 220.0
	title.offset_bottom = 0.0
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.76, 1.0))
	header.add_child(title)

	var currency_display := _build_currency_display()
	currency_display.anchor_left = 0.5
	currency_display.anchor_top = 0.0
	currency_display.anchor_right = 0.5
	currency_display.anchor_bottom = 1.0
	currency_display.offset_left = -235.0
	currency_display.offset_top = 2.0
	currency_display.offset_right = 235.0
	currency_display.offset_bottom = -2.0
	header.add_child(currency_display)

	var right_group := HBoxContainer.new()
	right_group.anchor_left = 1.0
	right_group.anchor_top = 0.0
	right_group.anchor_right = 1.0
	right_group.anchor_bottom = 1.0
	right_group.offset_left = -240.0
	right_group.offset_top = 2.0
	right_group.offset_right = 0.0
	right_group.offset_bottom = -2.0
	right_group.add_theme_constant_override("separation", 8)
	header.add_child(right_group)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_group.add_child(right_spacer)

	_weight_label = Label.new()
	_weight_label.custom_minimum_size = Vector2(96.0, 0.0)
	_weight_label.text = "0 / 50 kg"
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weight_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_weight_label.add_theme_font_size_override("font_size", 14)
	_weight_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.72, 1.0))
	right_group.add_child(_weight_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(34.0, 30.0)
	close_button.add_theme_stylebox_override("normal", _button_style(Color(0.17, 0.18, 0.17, 1.0), Color(0.45, 0.48, 0.42, 1.0)))
	close_button.add_theme_stylebox_override("hover", _button_style(Color(0.23, 0.25, 0.23, 1.0), Color(0.86, 0.72, 0.25, 1.0)))
	close_button.add_theme_stylebox_override("pressed", _button_style(Color(0.12, 0.13, 0.12, 1.0), Color(0.86, 0.72, 0.25, 1.0)))
	close_button.pressed.connect(close)
	right_group.add_child(close_button)

	return header


func _build_currency_display() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(470.0, 0.0)
	row.add_theme_constant_override("separation", 24)

	_silver_label = _make_currency_label(Color(0.78, 0.8, 0.78, 1.0), 230.0)
	_gold_label = _make_currency_label(Color(0.96, 0.78, 0.28, 1.0), 200.0)
	row.add_child(_silver_label)
	row.add_child(_gold_label)
	_refresh_currency_display()
	return row


func _build_body() -> Control:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)

	_equipment_panel = EquipmentPanelScene.instantiate()
	_equipment_panel.custom_minimum_size = Vector2(250.0, 0.0)
	_equipment_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment_panel.connect("gear_slot_selected", Callable(self, "_on_equipment_slot_selected"))
	if _equipment_panel.has_method("set_drop_handler"):
		_equipment_panel.call("set_drop_handler", self)
	body.add_child(_equipment_panel)
	_equipment_panel.call("set_equipped_slots", _equipped_slots)

	var grid_panel := PanelContainer.new()
	grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_panel.add_theme_stylebox_override("panel", _section_style())
	body.add_child(grid_panel)

	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left", 12)
	grid_margin.add_theme_constant_override("margin_top", 12)
	grid_margin.add_theme_constant_override("margin_right", 12)
	grid_margin.add_theme_constant_override("margin_bottom", 12)
	grid_panel.add_child(grid_margin)

	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	grid_margin.add_child(_grid)
	_create_slot_buttons()

	var details_panel := PanelContainer.new()
	details_panel.custom_minimum_size = Vector2(240.0, 0.0)
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_panel.add_theme_stylebox_override("panel", _section_style())
	body.add_child(details_panel)

	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	details_panel.add_child(_wrap_in_margin(details, 12))

	_detail_name = _make_detail_label("Empty Slot", 20, Color(0.96, 0.9, 0.74, 1.0))
	_detail_category = _make_detail_label("", 13, Color(0.6, 0.72, 0.66, 1.0))
	_detail_stack = _make_detail_label("", 13, Color(0.76, 0.78, 0.74, 1.0))
	_detail_description = _make_detail_label("", 14, Color(0.86, 0.86, 0.82, 1.0))
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	details.add_child(_detail_name)
	details.add_child(_detail_category)
	details.add_child(_detail_stack)
	details.add_child(_thin_rule())
	details.add_child(_detail_description)

	return body


func _build_stats_tab() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _section_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	_stats_list = VBoxContainer.new()
	_stats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_stats_list)

	_stats_empty_label = _make_detail_label("Player stats unavailable.", 16, Color(0.88, 0.84, 0.74, 1.0))
	_stats_empty_label.visible = false
	_stats_list.add_child(_stats_empty_label)
	_refresh_stats()
	return panel


func _wrap_in_margin(control: Control, margin_size: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", margin_size)
	margin.add_theme_constant_override("margin_top", margin_size)
	margin.add_theme_constant_override("margin_right", margin_size)
	margin.add_theme_constant_override("margin_bottom", margin_size)
	margin.add_child(control)
	return margin


func _create_slot_buttons() -> void:
	_slot_buttons.clear()
	_slot_item_icons.clear()
	for slot_index in range(slot_count):
		var button: Button = InventorySlotButtonScript.new()
		button.name = "Slot%02d" % (slot_index + 1)
		button.custom_minimum_size = Vector2(64.0, 64.0)
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", Color(0.94, 0.94, 0.88, 1.0))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.call("setup", self, slot_index)
		button.pressed.connect(_on_slot_pressed.bind(slot_index))
		_grid.add_child(button)
		_slot_buttons.append(button)

		var item_icon := Control.new()
		item_icon.name = "ItemIcon"
		item_icon.set_script(InventoryItemIconScript)
		item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		item_icon.visible = false
		button.add_child(item_icon)
		_slot_item_icons.append(item_icon)


func _rebuild_slot_grid() -> void:
	if _grid == null:
		return

	for child in _grid.get_children():
		child.queue_free()
	_slot_buttons.clear()
	_slot_item_icons.clear()
	_grid.columns = columns
	_create_slot_buttons()


func _refresh_all_slots() -> void:
	if _slot_buttons.is_empty():
		return

	_grid.columns = columns
	_normalize_slot_count()
	for slot_index in range(slot_count):
		_refresh_slot(slot_index)
	_update_weight()
	_refresh_details()


func _refresh_currency_display() -> void:
	if _silver_label != null:
		_silver_label.text = "Silver: %s" % _format_whole_number(_silver_amount)
	if _gold_label != null:
		_gold_label.text = "Gold: %s" % _format_whole_number(_gold_amount)


func _refresh_slot(slot_index: int) -> void:
	var button := _slot_buttons[slot_index]
	var item_icon := _slot_item_icons[slot_index]
	var slot := _slot_at(slot_index)
	var is_selected := slot_index == _selected_index

	if slot.is_empty():
		button.text = ""
		button.tooltip_text = ""
		item_icon.visible = false
		item_icon.call("clear_item")
		button.add_theme_stylebox_override("normal", _slot_style(Color(0.09, 0.1, 0.09, 1.0), false, is_selected))
		button.add_theme_stylebox_override("hover", _slot_style(Color(0.13, 0.15, 0.13, 1.0), true, is_selected))
		button.add_theme_stylebox_override("pressed", _slot_style(Color(0.07, 0.08, 0.07, 1.0), true, is_selected))
		return

	var item_name := String(slot.get("name", "Item"))
	button.text = ""
	button.tooltip_text = item_name
	item_icon.visible = true
	item_icon.call("set_item", slot)

	var item_color := slot.get("color", Color(0.28, 0.32, 0.28, 1.0)) as Color
	button.add_theme_stylebox_override("normal", _slot_style(item_color.darkened(0.35), false, is_selected))
	button.add_theme_stylebox_override("hover", _slot_style(item_color.darkened(0.2), true, is_selected))
	button.add_theme_stylebox_override("pressed", _slot_style(item_color.darkened(0.45), true, is_selected))


func _refresh_details() -> void:
	if not _selected_equipment_slot_id.is_empty():
		_refresh_equipment_details()
		return

	var slot := _slot_at(_selected_index)
	if slot.is_empty():
		_detail_name.text = "Empty Slot"
		_detail_category.text = ""
		_detail_stack.text = ""
		_detail_description.text = ""
		return

	var quantity := int(slot.get("quantity", 1))
	var max_stack := int(slot.get("max_stack", 1))
	_detail_name.text = String(slot.get("name", "Item"))
	_detail_category.text = String(slot.get("category", "Item"))
	_detail_stack.text = "Stack: %d / %d" % [quantity, max_stack]
	_detail_description.text = String(slot.get("description", ""))


func _refresh_stats() -> void:
	if _stats_list == null:
		return

	for child in _stats_list.get_children():
		if child != _stats_empty_label:
			_stats_list.remove_child(child)
			child.queue_free()

	var stat_ids: Array = []
	if _stats != null and _stats.has_method("get_stat_ids"):
		stat_ids = _stats.call("get_stat_ids")

	if stat_ids.is_empty():
		if _stats_empty_label != null:
			_stats_empty_label.visible = true
		return

	if _stats_empty_label != null:
		_stats_empty_label.visible = false

	for stat_id in stat_ids:
		_stats_list.add_child(_build_stat_row(stat_id))


func _build_stat_row(stat_id: StringName) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 24.0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text = _stat_display_name(stat_id)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74, 1.0))
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(90.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.text = _format_stat_value(_stat_value(stat_id), _stat_format(stat_id))
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.43, 1.0))
	row.add_child(value_label)
	return row


func _refresh_equipment_details() -> void:
	var slot_label := _equipment_slot_label(_selected_equipment_slot_id)
	var slot := _equipped_slot_at(_selected_equipment_slot_id)
	if slot.is_empty():
		_detail_name.text = "%s Slot" % slot_label
		_detail_category.text = "Equipped Gear"
		_detail_stack.text = ""
		_detail_description.text = ""
		return

	_detail_name.text = String(slot.get("name", "Item"))
	_detail_category.text = String(slot.get("category", "Equipment"))
	_detail_stack.text = "Slot: %s" % slot_label
	_detail_description.text = String(slot.get("description", ""))


func _update_weight() -> void:
	var carried_weight := 0.0
	for slot in _slots:
		var slot_data := slot as Dictionary
		if slot_data == null or slot_data.is_empty():
			continue

		var quantity := float(slot_data.get("quantity", 1))
		var unit_weight := float(slot_data.get("unit_weight", 0.0))
		carried_weight += quantity * unit_weight

	_weight_label.text = "%.1f / 50 kg" % carried_weight


func _on_slot_pressed(slot_index: int) -> void:
	_selected_index = slot_index
	_selected_equipment_slot_id = ""
	if _equipment_panel != null:
		_equipment_panel.call("clear_selection")
	for index in range(slot_count):
		_refresh_slot(index)
	_refresh_details()


func _on_equipment_slot_selected(slot_id: String, _slot_data: Dictionary) -> void:
	_selected_index = -1
	_selected_equipment_slot_id = slot_id
	for index in range(slot_count):
		_refresh_slot(index)
	_refresh_details()


## Returns true when the target gear slot can accept a dragged item.
func can_drop_equipment_slot_data(target_slot_id: String, data: Variant) -> bool:
	if target_slot_id.is_empty() or typeof(data) != TYPE_DICTIONARY:
		return false
	if _inventory == null:
		return false

	var drag_data := data as Dictionary
	var drag_type := String(drag_data.get("type", ""))
	if drag_type == SLOT_DRAG_TYPE:
		var source_index := int(drag_data.get("source_index", -1))
		return _inventory.has_method("can_equip_from_slot") and bool(_inventory.call("can_equip_from_slot", source_index, target_slot_id))
	if drag_type == EQUIPMENT_DRAG_TYPE:
		var source_slot_id := String(drag_data.get("source_slot_id", ""))
		return _inventory.has_method("can_move_equipped_slot") and bool(_inventory.call("can_move_equipped_slot", source_slot_id, target_slot_id))

	return false


## Equips or swaps a dragged item into the requested gear slot.
func drop_equipment_slot_data(target_slot_id: String, data: Variant) -> void:
	if not can_drop_equipment_slot_data(target_slot_id, data):
		return

	var drag_data := data as Dictionary
	var drag_type := String(drag_data.get("type", ""))
	var did_move := false
	if drag_type == SLOT_DRAG_TYPE:
		var source_index := int(drag_data.get("source_index", -1))
		if _inventory.has_method("equip_from_slot"):
			did_move = bool(_inventory.call("equip_from_slot", source_index, target_slot_id))
	elif drag_type == EQUIPMENT_DRAG_TYPE:
		var source_slot_id := String(drag_data.get("source_slot_id", ""))
		if _inventory.has_method("move_or_swap_equipped_slots"):
			did_move = bool(_inventory.call("move_or_swap_equipped_slots", source_slot_id, target_slot_id))

	if did_move:
		_selected_index = -1
		_selected_equipment_slot_id = target_slot_id
		_refresh_details()


func _select_first_filled_slot() -> void:
	for slot_index in range(slot_count):
		if not _slot_at(slot_index).is_empty():
			_on_slot_pressed(slot_index)
			return

	_selected_index = -1
	_refresh_details()


func _slot_at(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= _slots.size():
		return EMPTY_SLOT

	var slot := _slots[slot_index] as Dictionary
	return slot if slot != null else EMPTY_SLOT


func _is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slot_count and slot_index < _slots.size()


func _equipped_slot_at(slot_id: String) -> Dictionary:
	var slot := _equipped_slots.get(slot_id, EMPTY_SLOT) as Dictionary
	return slot if slot != null else EMPTY_SLOT


func _equipment_slot_label(slot_id: String) -> String:
	if _equipment_panel != null:
		return String(_equipment_panel.call("get_slot_label", slot_id))

	return slot_id.capitalize()


func _find_stats() -> Node:
	if not stats_path.is_empty():
		var explicit_stats := get_node_or_null(stats_path)
		if explicit_stats != null:
			return explicit_stats

	if not is_inside_tree():
		return null

	var grouped_stats := get_tree().get_first_node_in_group("player_stats")
	if grouped_stats != null:
		return grouped_stats

	return get_tree().root.find_child("Stats", true, false)


func _stat_display_name(stat_id: StringName) -> String:
	if _stats != null and _stats.has_method("get_display_name"):
		return String(_stats.call("get_display_name", stat_id))

	return String(stat_id).capitalize()


func _stat_format(stat_id: StringName) -> StringName:
	if _stats != null and _stats.has_method("get_format"):
		return _stats.call("get_format", stat_id)

	return &"number"


func _stat_value(stat_id: StringName) -> float:
	if _stats != null and _stats.has_method("get_stat"):
		return float(_stats.call("get_stat", stat_id))

	return 0.0


func _format_stat_value(value: float, format_id: StringName) -> String:
	match format_id:
		&"percent":
			return "%s%%" % _format_decimal(value)
		&"per_second":
			return "%s/s" % _format_decimal(value)
		&"kilogram":
			return "%skg" % _format_decimal(value)
		&"per_day":
			return "%s/d" % _format_decimal(value)
		_:
			return _format_decimal(value)


func _format_decimal(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))

	return "%.1f" % value


func _normalize_slot_count() -> void:
	slot_count = clampi(slot_count, 1, MAX_VISIBLE_SLOTS)
	while _slots.size() < slot_count:
		_slots.append(EMPTY_SLOT.duplicate())

	if _slots.size() > slot_count:
		_slots.resize(slot_count)


func _create_placeholder_equipment() -> void:
	_equipped_slots = {}


func _make_detail_label(text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _make_currency_label(font_color: Color, minimum_width: float) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(minimum_width, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", font_color)
	return label


func _format_whole_number(value: int) -> String:
	var digits := str(maxi(value, 0))
	var formatted := ""
	var group_count := 0

	for index in range(digits.length() - 1, -1, -1):
		if group_count > 0 and group_count % 3 == 0:
			formatted = ",%s" % formatted
		formatted = "%s%s" % [digits.substr(index, 1), formatted]
		group_count += 1

	return formatted


func _thin_rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(1.0, 1.0)
	rule.color = Color(0.42, 0.42, 0.34, 1.0)
	return rule


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.105, 0.96)
	style.border_color = Color(0.68, 0.58, 0.25, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.07, 0.92)
	style.border_color = Color(0.29, 0.31, 0.25, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _slot_style(background: Color, is_hovered: bool, is_selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.86, 0.72, 0.25, 1.0) if is_selected else Color(0.34, 0.36, 0.3, 1.0)
	if is_hovered and not is_selected:
		style.border_color = Color(0.58, 0.62, 0.48, 1.0)
	style.set_border_width_all(2 if is_selected else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style
