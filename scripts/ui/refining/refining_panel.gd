## Prototype refining menu.
##
## The panel reads recipes from a world station and uses PlayerInventory to
## consume selected recipe inputs and grant outputs. It does not own item storage.
class_name RefiningPanel
extends CanvasLayer

const InventoryItemIconScript := preload("res://scripts/ui/inventory/inventory_item_icon.gd")
const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"

## Inventory node used for recipe costs and outputs.
@export var inventory_path: NodePath
## Shows the menu at scene start for isolated UI previews.
@export var start_visible := false
## Fallback seconds each selected station action takes when a recipe does not override it.
@export_range(0.1, 10.0, 0.1) var default_seconds_per_action := 1.0

var _inventory: Node
var _station: Node
var _recipe := {}
var _recipes := []
var _selected_recipe_index := 0
var _root: Control
var _title_label: Label
var _recipe_selector: HBoxContainer
var _recipe_dropdown: OptionButton
var _inputs_container: VBoxContainer
var _input_rows := []
var _output_icon: Control
var _output_name_label: Label
var _output_count_label: Label
var _channel_row: Control
var _channel_label: Label
var _channel_progress: ProgressBar
var _status_label: Label
var _quantity_slider: HSlider
var _quantity_value_label: Label
var _refine_button: Button
var _block_world_input_until_mouse_release := false
var _requested_quantity := 1
var _current_action_quantity := 1
var _is_refining := false
var _refine_elapsed := 0.0
var _refine_duration := 0.0
var _pending_refine := {}


func _ready() -> void:
	add_to_group("refining_panel")
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	visible = start_visible
	_build_window()
	_bind_inventory()
	_refresh_recipe()


func _process(delta: float) -> void:
	if not _is_refining:
		return

	_refine_elapsed = minf(_refine_elapsed + maxf(delta, 0.0), _refine_duration)
	_refresh_channel_progress()
	if _refine_elapsed >= _refine_duration:
		_complete_refining_channel()


## Opens this menu for a clicked refining station.
func open_for_station(station: Node) -> void:
	_cancel_refining_channel("Cancelled", false)
	_station = station
	_recipes = _station_recipes(station)
	_selected_recipe_index = clampi(_selected_recipe_index, 0, maxi(_recipes.size() - 1, 0))
	_recipe = _selected_recipe()
	_bind_inventory()
	visible = true
	_block_world_input_until_mouse_release = false
	_refresh_recipe()


func close() -> void:
	_cancel_refining_channel("Cancelled", false)
	visible = false
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


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _bind_inventory() -> void:
	var next_inventory := _find_inventory()
	if next_inventory == _inventory:
		return

	if _inventory != null and _inventory.has_signal("slots_changed"):
		var callable := Callable(self, "_on_inventory_slots_changed")
		if _inventory.is_connected("slots_changed", callable):
			_inventory.disconnect("slots_changed", callable)

	_inventory = next_inventory
	if _inventory != null and _inventory.has_signal("slots_changed"):
		var callable := Callable(self, "_on_inventory_slots_changed")
		if not _inventory.is_connected("slots_changed", callable):
			_inventory.connect("slots_changed", callable)


func _on_inventory_slots_changed() -> void:
	_refresh_recipe()


func _build_window() -> void:
	if _root != null:
		return

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.18)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "Window"
	panel.custom_minimum_size = Vector2(500.0, 480.0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250.0
	panel.offset_top = -240.0
	panel.offset_right = 250.0
	panel.offset_bottom = 240.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	layout.add_child(_build_header())
	layout.add_child(_build_recipe_rows())
	layout.add_child(_build_footer())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 38.0)
	header.add_theme_constant_override("separation", 10)

	_title_label = Label.new()
	_title_label.text = "Sawmill"
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


func _build_recipe_rows() -> Control:
	var rows := VBoxContainer.new()
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)

	_recipe_selector = HBoxContainer.new()
	_recipe_selector.name = "RecipeSelector"
	_recipe_selector.custom_minimum_size = Vector2(0.0, 36.0)
	_recipe_selector.add_theme_constant_override("separation", 10)
	rows.add_child(_recipe_selector)

	var recipe_label := Label.new()
	recipe_label.text = "Recipe"
	recipe_label.custom_minimum_size = Vector2(64.0, 0.0)
	recipe_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recipe_label.add_theme_font_size_override("font_size", 16)
	recipe_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 1.0))
	_recipe_selector.add_child(recipe_label)

	_recipe_dropdown = OptionButton.new()
	_recipe_dropdown.name = "TierDropdown"
	_recipe_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_dropdown.custom_minimum_size = Vector2(0.0, 34.0)
	_recipe_dropdown.item_selected.connect(_on_recipe_dropdown_item_selected)
	_recipe_selector.add_child(_recipe_dropdown)

	_inputs_container = VBoxContainer.new()
	_inputs_container.name = "Inputs"
	_inputs_container.add_theme_constant_override("separation", 8)
	rows.add_child(_inputs_container)

	var arrow_label := Label.new()
	arrow_label.text = "=>"
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_label.add_theme_font_size_override("font_size", 22)
	arrow_label.add_theme_color_override("font_color", Color(0.84, 0.68, 0.36, 1.0))
	rows.add_child(arrow_label)

	var output_row := _build_item_row("Output")
	_output_icon = output_row.get_node("Icon")
	_output_name_label = output_row.get_node("Name")
	_output_count_label = output_row.get_node("Count")
	rows.add_child(output_row)

	_channel_row = _build_channel_row()
	rows.add_child(_channel_row)
	return rows


func _build_item_row(row_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.custom_minimum_size = Vector2(0.0, 76.0)
	row.add_theme_constant_override("separation", 12)

	var icon := InventoryItemIconScript.new() as Control
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(72.0, 72.0)
	row.add_child(icon)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 1.0))
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.name = "Count"
	count_label.custom_minimum_size = Vector2(90.0, 0.0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.43, 1.0))
	row.add_child(count_label)
	return row


func _build_channel_row() -> Control:
	var row := VBoxContainer.new()
	row.name = "Channel"
	row.visible = false
	row.add_theme_constant_override("separation", 4)

	_channel_label = Label.new()
	_channel_label.text = ""
	_channel_label.add_theme_font_size_override("font_size", 14)
	_channel_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.72, 1.0))
	row.add_child(_channel_label)

	_channel_progress = ProgressBar.new()
	_channel_progress.custom_minimum_size = Vector2(0.0, 14.0)
	_channel_progress.min_value = 0.0
	_channel_progress.max_value = 1.0
	_channel_progress.value = 0.0
	_channel_progress.show_percentage = false
	_channel_progress.add_theme_stylebox_override("background", _progress_background_style())
	_channel_progress.add_theme_stylebox_override("fill", _progress_fill_style())
	row.add_child(_channel_progress)
	return row


func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0.0, 48.0)
	footer.add_theme_constant_override("separation", 12)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74, 1.0))
	footer.add_child(_status_label)

	var quantity_label := Label.new()
	quantity_label.text = "Qty"
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.add_theme_font_size_override("font_size", 14)
	quantity_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 1.0))
	footer.add_child(quantity_label)

	_quantity_slider = HSlider.new()
	_quantity_slider.custom_minimum_size = Vector2(132.0, 40.0)
	_quantity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quantity_slider.min_value = 1.0
	_quantity_slider.max_value = 1.0
	_quantity_slider.step = 1.0
	_quantity_slider.value = 1.0
	_quantity_slider.value_changed.connect(_on_quantity_slider_value_changed)
	footer.add_child(_quantity_slider)

	_quantity_value_label = Label.new()
	_quantity_value_label.custom_minimum_size = Vector2(44.0, 0.0)
	_quantity_value_label.text = "1"
	_quantity_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quantity_value_label.add_theme_font_size_override("font_size", 16)
	_quantity_value_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.43, 1.0))
	footer.add_child(_quantity_value_label)

	_refine_button = Button.new()
	_refine_button.text = "Refine"
	_refine_button.custom_minimum_size = Vector2(118.0, 40.0)
	_refine_button.pressed.connect(_on_refine_pressed)
	footer.add_child(_refine_button)
	return footer


func _refresh_recipe() -> void:
	if _title_label == null:
		return

	if _recipes.is_empty() and _station != null:
		_recipes = _station_recipes(_station)
	_selected_recipe_index = clampi(_selected_recipe_index, 0, maxi(_recipes.size() - 1, 0))
	_recipe = _selected_recipe()
	_sync_recipe_dropdown()

	var station_name := String(_recipe.get("station_name", "Sawmill"))
	var inputs := _recipe_inputs()
	var output_item_id := String(_recipe.get("output_item_id", ""))
	var output_quantity := maxi(int(_recipe.get("output_quantity", 1)), 1)
	var max_action_quantity := _max_action_quantity(inputs, output_item_id, output_quantity)
	_sync_quantity_slider(max_action_quantity)
	_current_action_quantity = _requested_action_quantity(max_action_quantity)
	var display_action_quantity := maxi(_current_action_quantity, 1)
	var total_output_quantity := output_quantity * display_action_quantity
	var has_inputs := _has_all_inputs(inputs, _current_action_quantity)
	var has_output_space := _has_output_space(output_item_id, total_output_quantity)
	var can_refine := (
		_inventory != null
		and not output_item_id.is_empty()
		and not inputs.is_empty()
		and has_inputs
		and has_output_space
		and not _is_refining
	)

	_title_label.text = station_name
	_sync_input_rows(inputs.size())
	for index in range(inputs.size()):
		_set_input_row(_input_rows[index], inputs[index], display_action_quantity)
	_set_icon_item(_output_icon, output_item_id, total_output_quantity)
	_output_name_label.text = _item_name(output_item_id)
	_output_count_label.text = "+%d" % total_output_quantity
	_refine_button.text = String(_recipe.get("action_text", "Refine"))
	_refine_button.disabled = not can_refine

	if _inventory == null:
		_status_label.text = "Inventory unavailable."
	elif _is_refining:
		_status_label.text = "Channeling..."
	elif can_refine:
		_status_label.text = "Ready."
	elif not has_inputs:
		_status_label.text = "Need %s." % _missing_input_name(inputs, _current_action_quantity)
	else:
		_status_label.text = "No inventory space."


func _on_refine_pressed() -> void:
	var inputs := _recipe_inputs()
	var output_item_id := String(_recipe.get("output_item_id", ""))
	var action_quantity := _current_action_quantity
	var output_quantity := maxi(int(_recipe.get("output_quantity", 1)), 1) * action_quantity
	if _inventory == null or inputs.is_empty() or output_item_id.is_empty():
		_refresh_recipe()
		return

	if action_quantity <= 0 or not _has_all_inputs(inputs, action_quantity):
		_refresh_recipe()
		return
	if not _has_output_space(output_item_id, output_quantity):
		_refresh_recipe()
		_status_label.text = "No inventory space."
		return

	_start_refining_channel(inputs, output_item_id, output_quantity, action_quantity)


func _start_refining_channel(
	inputs: Array,
	output_item_id: String,
	output_quantity: int,
	action_quantity: int
) -> void:
	_is_refining = true
	_refine_elapsed = 0.0
	_refine_duration = maxf(float(action_quantity) * _recipe_seconds_per_action(), 0.1)
	_pending_refine = {
		"inputs": inputs.duplicate(true),
		"output_item_id": output_item_id,
		"output_quantity": output_quantity,
		"action_quantity": action_quantity,
		"action_text": String(_recipe.get("action_text", "Refine")),
	}
	_refresh_channel_progress()
	_refresh_recipe()


func _complete_refining_channel() -> void:
	var pending := _pending_refine.duplicate(true)
	_is_refining = false
	_refine_elapsed = 0.0
	_refine_duration = 0.0
	_pending_refine = {}
	_set_channel_visible(false)

	if pending.is_empty():
		_refresh_recipe()
		return

	_complete_refining_action(pending)


func _complete_refining_action(refine_data: Dictionary) -> void:
	var inputs: Array = refine_data.get("inputs", [])
	var output_item_id := String(refine_data.get("output_item_id", ""))
	var output_quantity := maxi(int(refine_data.get("output_quantity", 0)), 0)
	var action_quantity := maxi(int(refine_data.get("action_quantity", 1)), 1)
	if _inventory == null or inputs.is_empty() or output_item_id.is_empty() or output_quantity <= 0:
		_refresh_recipe()
		return

	if not _has_all_inputs(inputs, action_quantity):
		_refresh_recipe()
		_status_label.text = "Need %s." % _missing_input_name(inputs, action_quantity)
		return
	if not _has_output_space(output_item_id, output_quantity):
		_refresh_recipe()
		_status_label.text = "No inventory space."
		return

	var removed_inputs := []
	for input in inputs:
		var input_item_id := String(input.get("item_id", ""))
		var input_quantity := maxi(int(input.get("quantity", 1)), 1) * action_quantity
		var missing_input := int(_inventory.call("remove_item", input_item_id, input_quantity))
		var removed_quantity := input_quantity - missing_input
		if removed_quantity > 0:
			removed_inputs.append({
				"item_id": input_item_id,
				"quantity": removed_quantity,
			})
		if missing_input > 0:
			_restore_inputs(removed_inputs)
			_refresh_recipe()
			_status_label.text = "Need %s." % _item_name(input_item_id)
			return

	var output_remainder := int(_inventory.call("add_item", output_item_id, output_quantity))
	if output_remainder > 0:
		var output_added := output_quantity - output_remainder
		if output_added > 0:
			_inventory.call("remove_item", output_item_id, output_added)
		_restore_inputs(removed_inputs)
		_refresh_recipe()
		_status_label.text = "No inventory space."
		return

	_refresh_recipe()
	_status_label.text = "Created %d x %s." % [output_quantity, _item_name(output_item_id)]


func _cancel_refining_channel(status_text: String = "", should_refresh := true) -> void:
	if not _is_refining:
		return

	_is_refining = false
	_refine_elapsed = 0.0
	_refine_duration = 0.0
	_pending_refine = {}
	_set_channel_visible(false)
	if should_refresh:
		_refresh_recipe()
	if not status_text.is_empty() and _status_label != null:
		_status_label.text = status_text


func _refresh_channel_progress() -> void:
	if not _is_refining:
		_set_channel_visible(false)
		return

	var progress := 0.0
	if _refine_duration > 0.0:
		progress = clampf(_refine_elapsed / _refine_duration, 0.0, 1.0)

	_set_channel_visible(true)
	if _channel_progress != null:
		_channel_progress.value = progress
	if _channel_label != null:
		var action_text := String(_pending_refine.get("action_text", "Refine"))
		var remaining := maxf(_refine_duration - _refine_elapsed, 0.0)
		_channel_label.text = "%s %d... %.1fs" % [
			action_text,
			maxi(int(_pending_refine.get("action_quantity", 1)), 1),
			remaining,
		]


func _set_channel_visible(is_visible: bool) -> void:
	if _channel_row != null:
		_channel_row.visible = is_visible


func _sync_recipe_dropdown() -> void:
	if _recipe_dropdown == null:
		return

	_recipe_dropdown.clear()
	_recipe_dropdown.disabled = _is_refining or _recipes.size() <= 1
	for index in range(_recipes.size()):
		var recipe := _recipes[index] as Dictionary
		_recipe_dropdown.add_item(_recipe_dropdown_label(recipe, index), index)

	if not _recipes.is_empty():
		_recipe_dropdown.select(_selected_recipe_index)


func _on_recipe_dropdown_item_selected(recipe_index: int) -> void:
	_selected_recipe_index = clampi(recipe_index, 0, maxi(_recipes.size() - 1, 0))
	_refresh_recipe()


func _on_quantity_slider_value_changed(value: float) -> void:
	_requested_quantity = maxi(roundi(value), 1)
	_refresh_recipe()


func _recipe_dropdown_label(recipe: Dictionary, recipe_index: int) -> String:
	var explicit_label := String(recipe.get("recipe_label", ""))
	if not explicit_label.is_empty():
		return explicit_label

	var output_item_id := String(recipe.get("output_item_id", ""))
	if not output_item_id.is_empty():
		return _item_name(output_item_id)

	var tier_text := String(recipe.get("tier_roman", ""))
	if tier_text.is_empty():
		tier_text = str(recipe_index + 1)
	return "Tier %s" % tier_text


func _sync_quantity_slider(max_action_quantity: int) -> void:
	if _quantity_slider == null:
		return

	var slider_max := maxi(max_action_quantity, 1)
	_requested_quantity = clampi(_requested_quantity, 1, slider_max)
	_quantity_slider.editable = max_action_quantity > 0 and not _is_refining
	_quantity_slider.min_value = 1.0
	_quantity_slider.max_value = float(slider_max)
	_quantity_slider.step = 1.0
	_quantity_slider.set_value_no_signal(float(_requested_quantity))
	if _quantity_value_label != null:
		_quantity_value_label.text = "%d" % (_requested_quantity if max_action_quantity > 0 else 0)


func _requested_action_quantity(max_action_quantity: int) -> int:
	return clampi(_requested_quantity, 1, maxi(max_action_quantity, 1))


func _sync_input_rows(row_count: int) -> void:
	while _input_rows.size() < row_count:
		var row := _build_item_row("Input%d" % _input_rows.size())
		_inputs_container.add_child(row)
		_input_rows.append({
			"row": row,
			"icon": row.get_node("Icon"),
			"name": row.get_node("Name"),
			"count": row.get_node("Count"),
		})

	while _input_rows.size() > row_count:
		var row_data: Dictionary = _input_rows.pop_back()
		var row := row_data.get("row") as Node
		if row != null:
			row.queue_free()


func _set_input_row(row_data: Dictionary, input_data: Dictionary, action_quantity: int) -> void:
	var item_id := String(input_data.get("item_id", ""))
	var unit_quantity := maxi(int(input_data.get("quantity", 1)), 1)
	var quantity := unit_quantity * maxi(action_quantity, 1)
	var owned_quantity := _get_item_count(item_id)

	_set_icon_item(row_data.get("icon") as Control, item_id, quantity)

	var name_label := row_data.get("name") as Label
	if name_label != null:
		name_label.text = _item_name(item_id)

	var count_label := row_data.get("count") as Label
	if count_label != null:
		count_label.text = "%d / %d" % [owned_quantity, quantity]
		count_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.36, 0.28, 1.0) if owned_quantity < quantity else Color(1.0, 0.86, 0.43, 1.0)
		)


func _set_icon_item(icon: Control, item_id: String, quantity: int) -> void:
	if icon == null:
		return

	var definition := _get_definition(item_id)
	if definition == null:
		icon.call("clear_item")
		return

	icon.call("set_item", definition.call("to_display_dict", quantity))


func _station_recipes(station: Node) -> Array:
	if station == null:
		return []

	if station.has_method("get_refining_recipes"):
		var recipes: Variant = station.call("get_refining_recipes")
		if recipes is Array and not recipes.is_empty():
			return _normalize_recipes(recipes)

	if station.has_method("get_refining_recipe"):
		var recipe: Variant = station.call("get_refining_recipe")
		if recipe is Dictionary:
			return [recipe]

	return []


func _normalize_recipes(recipes: Array) -> Array:
	var normalized := []
	for recipe in recipes:
		if recipe is Dictionary:
			normalized.append((recipe as Dictionary).duplicate(true))

	return normalized


func _selected_recipe() -> Dictionary:
	if _recipes.is_empty():
		return {}

	return (_recipes[_selected_recipe_index] as Dictionary).duplicate(true)


func _recipe_inputs() -> Array:
	var recipe_inputs: Variant = _recipe.get("inputs", [])
	if recipe_inputs is Array and not recipe_inputs.is_empty():
		return _normalize_inputs(recipe_inputs)

	var legacy_input_item_id := String(_recipe.get("input_item_id", ""))
	if legacy_input_item_id.is_empty():
		return []

	return [{
		"item_id": legacy_input_item_id,
		"quantity": maxi(int(_recipe.get("input_quantity", 1)), 1),
	}]


func _recipe_seconds_per_action() -> float:
	return maxf(float(_recipe.get("seconds_per_action", default_seconds_per_action)), 0.1)


func _normalize_inputs(recipe_inputs: Array) -> Array:
	var normalized := []
	for recipe_input in recipe_inputs:
		if not (recipe_input is Dictionary):
			continue

		var input := recipe_input as Dictionary
		var item_id := String(input.get("item_id", ""))
		if item_id.is_empty():
			continue

		normalized.append({
			"item_id": item_id,
			"quantity": maxi(int(input.get("quantity", 1)), 1),
		})

	return normalized


func _has_all_inputs(inputs: Array, action_quantity: int = 1) -> bool:
	for input in inputs:
		var item_id := String(input.get("item_id", ""))
		var quantity := maxi(int(input.get("quantity", 1)), 1) * maxi(action_quantity, 1)
		if _get_item_count(item_id) < quantity:
			return false

	return true


func _missing_input_name(inputs: Array, action_quantity: int = 1) -> String:
	for input in inputs:
		var item_id := String(input.get("item_id", ""))
		var quantity := maxi(int(input.get("quantity", 1)), 1) * maxi(action_quantity, 1)
		if _get_item_count(item_id) < quantity:
			return _item_name(item_id)

	return "required materials"


func _max_action_quantity(inputs: Array, output_item_id: String = "", output_quantity: int = 1) -> int:
	if _inventory == null or inputs.is_empty():
		return 0

	var max_quantity := 999
	for input in inputs:
		var item_id := String(input.get("item_id", ""))
		var quantity := maxi(int(input.get("quantity", 1)), 1)
		if item_id.is_empty():
			continue

		max_quantity = mini(max_quantity, int(floor(float(_get_item_count(item_id)) / float(quantity))))

	if not output_item_id.is_empty() and _inventory.has_method("get_addable_count"):
		var addable_count := int(_inventory.call("get_addable_count", output_item_id))
		max_quantity = mini(max_quantity, int(floor(float(addable_count) / float(maxi(output_quantity, 1)))))

	return maxi(max_quantity, 0)


func _has_output_space(output_item_id: String, output_quantity: int) -> bool:
	if output_item_id.is_empty():
		return false
	if _inventory == null or not _inventory.has_method("get_addable_count"):
		return true

	return int(_inventory.call("get_addable_count", output_item_id)) >= output_quantity


func _restore_inputs(inputs: Array) -> void:
	for input in inputs:
		var item_id := String(input.get("item_id", ""))
		var quantity := maxi(int(input.get("quantity", 0)), 0)
		if not item_id.is_empty() and quantity > 0:
			_inventory.call("add_item", item_id, quantity)


func _item_name(item_id: String) -> String:
	var definition := _get_definition(item_id)
	if definition == null:
		return item_id if not item_id.is_empty() else "Unknown Item"

	return String(definition.get("display_name"))


func _get_item_count(item_id: String) -> int:
	if _inventory == null or item_id.is_empty() or not _inventory.has_method("get_item_count"):
		return 0

	return int(_inventory.call("get_item_count", item_id))


func _get_definition(item_id: String) -> Resource:
	if _inventory == null or item_id.is_empty() or not _inventory.has_method("get_definition"):
		return null

	return _inventory.call("get_definition", item_id) as Resource


func _find_inventory() -> Node:
	if inventory_path != NodePath(""):
		var inventory := get_node_or_null(inventory_path)
		if inventory != null:
			return inventory

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("player_inventory")


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


func _progress_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.03, 1.0)
	style.border_color = Color(0.0, 0.0, 0.0, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	return style


func _progress_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.68, 0.25, 1.0)
	style.border_color = Color(1.0, 0.86, 0.43, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	return style
