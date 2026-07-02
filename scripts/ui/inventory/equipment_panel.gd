## Reusable equipped-gear display used by the inventory window.
##
## This panel owns gear-slot presentation and drag/drop plumbing. PlayerInventory
## still owns the authoritative equipped item state.
class_name EquipmentPanel
extends PanelContainer

signal gear_slot_selected(slot_id: String, slot_data: Dictionary)

const EMPTY_SLOT := {}
const EquipmentSlotButtonScript := preload("res://scripts/ui/inventory/equipment_slot_button.gd")
const EquipmentSlotIconScript := preload("res://scripts/ui/inventory/equipment_slot_icon.gd")
const InventoryItemIconScript := preload("res://scripts/ui/inventory/inventory_item_icon.gd")
const SLOT_DEFINITIONS := [
	{"id": "bag", "label": "Bag", "abbr": "BG"},
	{"id": "head", "label": "Helmet", "abbr": "HM"},
	{"id": "cape", "label": "Cape", "abbr": "CP"},
	{"id": "main_hand", "label": "Main Hand", "abbr": "MH"},
	{"id": "chest", "label": "Chest", "abbr": "CH"},
	{"id": "off_hand", "label": "Off Hand", "abbr": "OH"},
	{"id": "potion", "label": "Potion", "abbr": "PT"},
	{"id": "shoes", "label": "Shoes", "abbr": "SH"},
	{"id": "food", "label": "Food", "abbr": "FD"},
]

var _slot_buttons := {}
var _slot_icon_rects := {}
var _slot_item_icons := {}
var _equipped_slots := {}
var _selected_slot_id := ""
var _drop_handler: Node


func _ready() -> void:
	add_theme_stylebox_override("panel", _section_style())
	_build_panel()
	_refresh_all_slots()


## Replaces the displayed equipped gear slots.
##
## The expected shape is a Dictionary keyed by slot id. Each filled slot value is
## an item Dictionary with fields such as name, category, color, and description.
func set_equipped_slots(new_equipped_slots: Dictionary) -> void:
	_equipped_slots = new_equipped_slots.duplicate(true)
	_refresh_all_slots()


## Sets the owner that answers equip/unequip drag-and-drop questions.
func set_drop_handler(drop_handler: Node) -> void:
	_drop_handler = drop_handler


## Clears the visual selection when the player selects a backpack slot.
func clear_selection() -> void:
	_selected_slot_id = ""
	_refresh_all_slots()


## Returns the player-facing label for a slot id.
func get_slot_label(slot_id: String) -> String:
	for definition in SLOT_DEFINITIONS:
		if String(definition.get("id", "")) == slot_id:
			return String(definition.get("label", slot_id.capitalize()))

	return slot_id.capitalize()


func _build_panel() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Equipped Gear"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.76, 1.0))
	layout.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(grid)

	for definition in SLOT_DEFINITIONS:
		grid.add_child(_build_slot_cell(definition))


func _build_slot_cell(definition: Dictionary) -> Control:
	var slot_id := String(definition.get("id", ""))
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(72.0, 84.0)
	cell.add_theme_constant_override("separation", 3)

	var button: Button = EquipmentSlotButtonScript.new()
	button.name = "%sSlot" % slot_id.capitalize().replace(" ", "")
	button.custom_minimum_size = Vector2(64.0, 64.0)
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.94, 0.94, 0.88, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.call("setup", self, slot_id)
	button.pressed.connect(_on_slot_pressed.bind(slot_id))
	cell.add_child(button)
	_slot_buttons[slot_id] = button

	var icon_rect := Control.new()
	icon_rect.name = "DefaultIcon"
	icon_rect.set_script(EquipmentSlotIconScript)
	icon_rect.call("set_icon_id", slot_id)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = 8.0
	icon_rect.offset_top = 8.0
	icon_rect.offset_right = -8.0
	icon_rect.offset_bottom = -8.0
	icon_rect.visible = false
	button.add_child(icon_rect)
	_slot_icon_rects[slot_id] = icon_rect

	var item_icon := Control.new()
	item_icon.name = "ItemIcon"
	item_icon.set_script(InventoryItemIconScript)
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_icon.visible = false
	button.add_child(item_icon)
	_slot_item_icons[slot_id] = item_icon

	var label := Label.new()
	label.text = String(definition.get("label", "Slot"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.66, 1.0))
	cell.add_child(label)

	return cell


func _refresh_all_slots() -> void:
	for definition in SLOT_DEFINITIONS:
		_refresh_slot(String(definition.get("id", "")), String(definition.get("abbr", "")))


func _refresh_slot(slot_id: String, slot_abbreviation: String) -> void:
	if not _slot_buttons.has(slot_id):
		return

	var button := _slot_buttons[slot_id] as Button
	var icon_rect := _slot_icon_rects.get(slot_id) as Control
	var item_icon := _slot_item_icons.get(slot_id) as Control
	var slot := _slot_at(slot_id)
	var is_selected := slot_id == _selected_slot_id

	if slot.is_empty():
		button.text = ""
		button.tooltip_text = get_slot_label(slot_id)
		if icon_rect != null:
			icon_rect.visible = true
		if item_icon != null:
			item_icon.visible = false
			item_icon.call("clear_item")
		button.add_theme_stylebox_override("normal", _slot_style(Color(0.09, 0.1, 0.09, 1.0), false, is_selected))
		button.add_theme_stylebox_override("hover", _slot_style(Color(0.13, 0.15, 0.13, 1.0), true, is_selected))
		button.add_theme_stylebox_override("pressed", _slot_style(Color(0.07, 0.08, 0.07, 1.0), true, is_selected))
		return

	if icon_rect != null:
		icon_rect.visible = false
	if item_icon != null:
		item_icon.visible = true
		item_icon.call("set_item", slot)
	var item_name := String(slot.get("name", "Item"))
	button.text = ""
	button.tooltip_text = "%s: %s" % [get_slot_label(slot_id), item_name]

	var item_color := slot.get("color", Color(0.28, 0.32, 0.28, 1.0)) as Color
	button.add_theme_stylebox_override("normal", _slot_style(item_color.darkened(0.35), false, is_selected))
	button.add_theme_stylebox_override("hover", _slot_style(item_color.darkened(0.2), true, is_selected))
	button.add_theme_stylebox_override("pressed", _slot_style(item_color.darkened(0.45), true, is_selected))


func _on_slot_pressed(slot_id: String) -> void:
	_selected_slot_id = slot_id
	_refresh_all_slots()
	gear_slot_selected.emit(slot_id, _slot_at(slot_id))


func _slot_at(slot_id: String) -> Dictionary:
	var slot := _equipped_slots.get(slot_id, EMPTY_SLOT) as Dictionary
	return slot if slot != null else EMPTY_SLOT


## Returns drag payload for a filled equipped slot.
func get_gear_slot_drag_data(slot_id: String) -> Variant:
	if _slot_at(slot_id).is_empty():
		return null

	if _drop_handler != null and _drop_handler.has_method("get_equipment_slot_drag_data"):
		return _drop_handler.call("get_equipment_slot_drag_data", slot_id)

	return null


## Builds the small item preview shown under the cursor while dragging gear.
func create_gear_slot_drag_preview(slot_id: String) -> Control:
	var slot := _slot_at(slot_id)
	if slot.is_empty():
		return null

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(64.0, 64.0)
	preview.size = Vector2(64.0, 64.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1.0, 1.0, 1.0, 0.88)

	var item_icon := Control.new()
	item_icon.name = "DraggedGearIcon"
	item_icon.set_script(InventoryItemIconScript)
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_icon.call("set_item", slot)
	preview.add_child(item_icon)
	return preview


## Returns true when the external inventory owner accepts this drop.
func can_drop_gear_slot_data(slot_id: String, data: Variant) -> bool:
	if _drop_handler == null or not _drop_handler.has_method("can_drop_equipment_slot_data"):
		return false

	return bool(_drop_handler.call("can_drop_equipment_slot_data", slot_id, data))


## Applies a validated gear-slot drop through the external inventory owner.
func drop_gear_slot_data(slot_id: String, data: Variant) -> void:
	if _drop_handler == null or not _drop_handler.has_method("drop_equipment_slot_data"):
		return

	_drop_handler.call("drop_equipment_slot_data", slot_id, data)


func _item_abbreviation(item_name: String) -> String:
	var words := item_name.strip_edges().split(" ", false)
	if words.size() >= 2:
		return "%s%s" % [words[0].substr(0, 1).to_upper(), words[1].substr(0, 1).to_upper()]

	return item_name.substr(0, 2).to_upper()


func _section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.07, 0.92)
	style.border_color = Color(0.29, 0.31, 0.25, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _slot_style(background: Color, is_hovered: bool, is_selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.86, 0.72, 0.25, 1.0) if is_selected else Color(0.34, 0.36, 0.3, 1.0)
	if is_hovered and not is_selected:
		style.border_color = Color(0.58, 0.62, 0.48, 1.0)
	style.set_border_width_all(2 if is_selected else 1)
	style.set_corner_radius_all(6)
	return style
