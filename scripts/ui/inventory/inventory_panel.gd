## Toggleable inventory window for the current local prototype.
##
## This script owns only presentation state: placeholder slots, selected slot UI,
## and the keyboard toggle. A later PlayerInventory module should become the
## authoritative item source and call set_slots() when its data changes.
class_name InventoryPanel
extends CanvasLayer

const EMPTY_SLOT := {}
const EquipmentPanelScene := preload("res://scenes/ui/inventory/EquipmentPanel.tscn")
const InventoryItemIconScript := preload("res://scripts/ui/inventory/inventory_item_icon.gd")
const InventorySlotButtonScript := preload("res://scripts/ui/inventory/inventory_slot_button.gd")
const SLOT_DRAG_TYPE := "elderforge_inventory_slot"

## Keyboard key used to open and close the inventory.
@export var toggle_key: Key = KEY_I
## Number of visible inventory slots.
@export_range(1, 80, 1) var slot_count: int = 42
## Number of columns used by the slot grid.
@export_range(1, 10, 1) var columns: int = 6
## Shows the panel when the scene starts. Keep off for normal gameplay.
@export var start_visible: bool = false
## Prototype silver amount until currency data is wired in.
@export var starting_silver: int = 0
## Prototype gold amount until currency data is wired in.
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
var _equipment_panel: Node
var _slot_buttons: Array[Button] = []
var _slot_item_icons: Array[Control] = []
var _slots: Array = []
var _equipped_slots := {}
var _silver_amount := 0
var _gold_amount := 0
var _selected_index := -1
var _selected_equipment_slot_id := ""


func _ready() -> void:
	visible = start_visible
	_silver_amount = maxi(starting_silver, 0)
	_gold_amount = maxi(starting_gold, 0)
	_create_placeholder_slots()
	_create_placeholder_equipment()
	_build_window()
	_refresh_currency_display()
	_refresh_all_slots()
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


## Closes the inventory window.
func close() -> void:
	visible = false


## Swaps between open and closed states.
func toggle() -> void:
	visible = not visible


## Replaces the displayed slots with external inventory data.
##
## Each filled slot should be a Dictionary with keys such as:
## name, quantity, max_stack, category, color, and description.
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
## The expected shape is a Dictionary keyed by equipment slot id.
func set_equipped_slots(new_equipped_slots: Dictionary) -> void:
	_equipped_slots = new_equipped_slots.duplicate(true)
	if _equipment_panel != null:
		_equipment_panel.call("set_equipped_slots", _equipped_slots)
	_refresh_details()


## Updates the displayed currency totals.
func set_currency(silver: int, gold: int) -> void:
	_silver_amount = maxi(silver, 0)
	_gold_amount = maxi(gold, 0)
	_refresh_currency_display()


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
	if String(drag_data.get("type", "")) != SLOT_DRAG_TYPE:
		return false

	var source_index := int(drag_data.get("source_index", -1))
	return _is_valid_slot_index(source_index) and source_index != target_index


## Moves or swaps item stacks when a dragged item is released over a bag slot.
func drop_slot_data(target_index: int, data: Variant) -> void:
	if not can_drop_slot_data(target_index, data):
		return

	var drag_data := data as Dictionary
	var source_index := int(drag_data.get("source_index", -1))
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
	layout.add_child(_build_body())


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
	body.add_theme_constant_override("separation", 14)

	_equipment_panel = EquipmentPanelScene.instantiate()
	_equipment_panel.custom_minimum_size = Vector2(250.0, 0.0)
	_equipment_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment_panel.connect("gear_slot_selected", Callable(self, "_on_equipment_slot_selected"))
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


func _normalize_slot_count() -> void:
	while _slots.size() < slot_count:
		_slots.append(EMPTY_SLOT.duplicate())

	if _slots.size() > slot_count:
		_slots.resize(slot_count)


func _create_placeholder_slots() -> void:
	_slots = []
	_normalize_slot_count()
	var log_names := [
		"Crude Logs",
		"Rough Logs",
		"Sturdy Logs",
		"Seasoned Logs",
		"Hardened Logs",
		"Emberwood Logs",
		"Sunheart Logs",
		"Kingswood Logs",
	]
	var rock_names := [
		"Crude Stone",
		"Rough Stone",
		"Sturdy Stone",
		"Dense Stone",
		"Hardened Stone",
		"Runed Stone",
		"Sunstone",
		"Kingsstone",
	]
	var ore_names := [
		"Crude Ore",
		"Rough Ore",
		"Sturdy Ore",
		"Dense Ore",
		"Hardened Ore",
		"Runed Ore",
		"Star Ore",
		"Kingsmetal Ore",
	]
	var cotton_names := [
		"Crude Cotton",
		"Rough Cotton",
		"Coarse Cotton",
		"Soft Cotton",
		"Fine Cotton",
		"Lustrous Cotton",
		"Sunspun Cotton",
		"Kingsweave Cotton",
	]
	var hide_names := [
		"Crude Hide",
		"Rough Hide",
		"Thick Hide",
		"Cured Hide",
		"Hardened Hide",
		"Pristine Hide",
		"Royal Hide",
		"Elder Hide",
	]

	for tier_index in range(log_names.size()):
		var tier := tier_index + 1
		_slots[tier_index] = _create_log_stack(log_names[tier_index], tier, 999 - tier_index * 83)

	for tier_index in range(rock_names.size()):
		var tier := tier_index + 1
		_slots[log_names.size() + tier_index] = _create_rock_stack(rock_names[tier_index], tier, 999 - tier_index * 71)

	for tier_index in range(ore_names.size()):
		var tier := tier_index + 1
		var slot_index := log_names.size() + rock_names.size() + tier_index
		_slots[slot_index] = _create_ore_stack(ore_names[tier_index], tier, 999 - tier_index * 59)

	for tier_index in range(cotton_names.size()):
		var tier := tier_index + 1
		var slot_index := log_names.size() + rock_names.size() + ore_names.size() + tier_index
		_slots[slot_index] = _create_cotton_stack(cotton_names[tier_index], tier, 999 - tier_index * 47)

	for tier_index in range(hide_names.size()):
		var tier := tier_index + 1
		var slot_index := log_names.size() + rock_names.size() + ore_names.size() + cotton_names.size() + tier_index
		_slots[slot_index] = _create_hide_stack(hide_names[tier_index], tier, 999 - tier_index * 53)


func _create_placeholder_equipment() -> void:
	_equipped_slots = {}


func _create_log_stack(display_name: String, tier: int, quantity: int) -> Dictionary:
	var tier_roman := _to_roman(tier)
	return {
		"id": "logs_t%d" % tier,
		"name": "%s %s" % [display_name, tier_roman],
		"quantity": quantity,
		"max_stack": 999,
		"category": "Resource",
		"tier": tier,
		"tier_roman": tier_roman,
		"icon": "logs",
		"unit_weight": 0.03 + float(tier - 1) * 0.01,
		"color": _tier_color(tier),
		"description": "Tier %s timber used for woodworking, crafting, and construction prototypes." % tier_roman,
	}


func _create_rock_stack(display_name: String, tier: int, quantity: int) -> Dictionary:
	var tier_roman := _to_roman(tier)
	return {
		"id": "stone_t%d" % tier,
		"name": "%s %s" % [display_name, tier_roman],
		"quantity": quantity,
		"max_stack": 999,
		"category": "Resource",
		"tier": tier,
		"tier_roman": tier_roman,
		"icon": "rocks",
		"unit_weight": 0.06 + float(tier - 1) * 0.015,
		"color": _tier_color(tier),
		"description": "Tier %s stone used for masonry, construction, and refining prototypes." % tier_roman,
	}


func _create_ore_stack(display_name: String, tier: int, quantity: int) -> Dictionary:
	var tier_roman := _to_roman(tier)
	return {
		"id": "ore_t%d" % tier,
		"name": "%s %s" % [display_name, tier_roman],
		"quantity": quantity,
		"max_stack": 999,
		"category": "Resource",
		"tier": tier,
		"tier_roman": tier_roman,
		"icon": "ores",
		"unit_weight": 0.08 + float(tier - 1) * 0.02,
		"color": _tier_color(tier),
		"description": "Tier %s ore used for smelting, weapon crafting, and refining prototypes." % tier_roman,
	}


func _create_cotton_stack(display_name: String, tier: int, quantity: int) -> Dictionary:
	var tier_roman := _to_roman(tier)
	return {
		"id": "cotton_t%d" % tier,
		"name": "%s %s" % [display_name, tier_roman],
		"quantity": quantity,
		"max_stack": 999,
		"category": "Resource",
		"tier": tier,
		"tier_roman": tier_roman,
		"icon": "cotton",
		"unit_weight": 0.02 + float(tier - 1) * 0.006,
		"color": _tier_color(tier),
		"description": "Tier %s cotton used for tailoring, cloth crafting, and refining prototypes." % tier_roman,
	}


func _create_hide_stack(display_name: String, tier: int, quantity: int) -> Dictionary:
	var tier_roman := _to_roman(tier)
	return {
		"id": "hide_t%d" % tier,
		"name": "%s %s" % [display_name, tier_roman],
		"quantity": quantity,
		"max_stack": 999,
		"category": "Resource",
		"tier": tier,
		"tier_roman": tier_roman,
		"icon": "hide",
		"unit_weight": 0.04 + float(tier - 1) * 0.012,
		"color": _tier_color(tier),
		"description": "Tier %s hide used for leatherworking, armor crafting, and refining prototypes." % tier_roman,
	}


func _item_abbreviation(item_name: String) -> String:
	var words := item_name.strip_edges().split(" ", false)
	if words.size() >= 2:
		return "%s%s" % [words[0].substr(0, 1).to_upper(), words[1].substr(0, 1).to_upper()]

	return item_name.substr(0, 2).to_upper()


func _quantity_text(quantity: int) -> String:
	return str(quantity) if quantity > 1 else ""


func _to_roman(value: int) -> String:
	var roman_values := {
		1: "I",
		2: "II",
		3: "III",
		4: "IV",
		5: "V",
		6: "VI",
		7: "VII",
		8: "VIII",
	}
	return String(roman_values.get(value, str(value)))


func _tier_color(tier: int) -> Color:
	match tier:
		1:
			return Color(0.72, 0.72, 0.72, 1.0)
		2:
			return Color(0.72, 0.50, 0.30, 1.0)
		3:
			return Color(0.20, 0.62, 0.25, 1.0)
		4:
			return Color(0.20, 0.42, 0.82, 1.0)
		5:
			return Color(0.78, 0.18, 0.16, 1.0)
		6:
			return Color(0.92, 0.48, 0.14, 1.0)
		7:
			return Color(0.95, 0.82, 0.18, 1.0)
		8:
			return Color(0.94, 0.94, 0.9, 1.0)
		_:
			return Color(0.72, 0.72, 0.72, 1.0)


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
