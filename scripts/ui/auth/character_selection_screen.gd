## Account character picker shown after a successful sign-in.
##
## Accounts can own up to three characters. This screen selects which character
## becomes active for the session before the playable world is loaded.
class_name CharacterSelectionScreen
extends CanvasLayer

const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"
const MAX_CHARACTER_SLOTS := 3
const COLOR_PANEL := Color(0.045, 0.055, 0.058, 0.96)
const COLOR_PANEL_DARK := Color(0.025, 0.03, 0.032, 1.0)
const COLOR_PANEL_BORDER := Color(0.54, 0.45, 0.2, 1.0)
const COLOR_PANEL_BORDER_HOT := Color(0.9, 0.73, 0.26, 1.0)
const COLOR_TEXT := Color(0.95, 0.9, 0.76, 1.0)
const COLOR_TEXT_DIM := Color(0.68, 0.72, 0.66, 1.0)
const COLOR_GOLD := Color(0.97, 0.86, 0.42, 1.0)

@export_file("*.tscn") var game_scene_path := "res://scenes/world/starting_city/StartingCity.tscn"
@export_file("*.tscn") var character_scene_path := "res://scenes/ui/auth/CharacterCustomizationScreen.tscn"
@export_file("*.tscn") var sign_in_scene_path := "res://scenes/bootstrap/SignInGateway.tscn"

var _session: Node
var _selected_character_id := ""
var _list_container: VBoxContainer
var _status_label: Label
var _enter_button: Button
var _create_button: Button


func _ready() -> void:
	layer = 120
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	_session = get_node_or_null("/root/PrototypeAuthSession")
	if _session == null or not bool(_session.get("is_signed_in")):
		call_deferred("_go_to_sign_in")
		return

	_selected_character_id = String(_session.get("active_character_id")).strip_edges()
	_build_ui()
	_refresh_character_slots()


func blocks_world_input() -> bool:
	return visible


func _build_ui() -> void:
	var root := Control.new()
	root.name = "CharacterSelectionRoot"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.64)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "Window"
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -230.0
	panel.offset_right = 280.0
	panel.offset_bottom = 230.0
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 2))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	layout.add_child(_make_label("Elderforge", 30, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	layout.add_child(_make_label("%s's Characters" % _account_label(), 14, COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	_list_container = VBoxContainer.new()
	_list_container.name = "CharacterSlots"
	_list_container.add_theme_constant_override("separation", 8)
	_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_list_container)

	_status_label = _make_label("", 13, COLOR_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_status_label.custom_minimum_size = Vector2(0.0, 26.0)
	layout.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	layout.add_child(buttons)

	var sign_out_button := _make_button("Sign Out")
	sign_out_button.pressed.connect(_on_sign_out_pressed)
	buttons.add_child(sign_out_button)

	_create_button = _make_button("Create New Character")
	_create_button.pressed.connect(_on_create_pressed)
	buttons.add_child(_create_button)

	_enter_button = _make_button("Enter World")
	_enter_button.pressed.connect(_on_enter_pressed)
	buttons.add_child(_enter_button)


func _refresh_character_slots() -> void:
	for child in _list_container.get_children():
		child.queue_free()

	var characters := _characters()
	if _selected_character_id.is_empty() and not characters.is_empty():
		_selected_character_id = String((characters[0] as Dictionary).get("character_id", ""))

	for character in characters:
		var character_data := character as Dictionary
		var character_id := String(character_data.get("character_id", ""))
		var display_name := String(character_data.get("display_name", "Unnamed")).strip_edges()
		if display_name.is_empty():
			display_name = "Unnamed"

		var button := _make_slot_button(display_name, "Slot %d" % int(character_data.get("slot_number", 1)))
		button.pressed.connect(_on_character_pressed.bind(character_id))
		_list_container.add_child(button)
		_apply_button_style(button, character_id == _selected_character_id)

	for empty_index in range(characters.size(), MAX_CHARACTER_SLOTS):
		var empty_slot := _make_empty_slot("Empty Slot %d" % (empty_index + 1))
		_list_container.add_child(empty_slot)

	if characters.is_empty():
		_set_status("Create your first character to enter the world.")
	else:
		_set_status("")

	_enter_button.disabled = _selected_character_id.is_empty()
	_apply_button_style(_enter_button, false)
	_create_button.visible = _can_create_character()


func _on_character_pressed(character_id: String) -> void:
	_selected_character_id = character_id
	if _session != null and _session.has_method("select_character"):
		var result: Dictionary = _session.call("select_character", character_id)
		if not bool(result.get("ok", false)):
			_set_status(String(result.get("message", "Could not select character.")))
			return

	_refresh_character_slots()


func _on_create_pressed() -> void:
	get_tree().change_scene_to_file(character_scene_path)


func _on_enter_pressed() -> void:
	if _selected_character_id.is_empty():
		_set_status("Select a character first.")
		return

	if _session != null and _session.has_method("select_character"):
		var result: Dictionary = _session.call("select_character", _selected_character_id)
		if not bool(result.get("ok", false)):
			_set_status(String(result.get("message", "Could not select character.")))
			return

	get_tree().change_scene_to_file(game_scene_path)


func _on_sign_out_pressed() -> void:
	if _session != null and _session.has_method("sign_out"):
		_session.call("sign_out")
	_go_to_sign_in()


func _go_to_sign_in() -> void:
	get_tree().change_scene_to_file(sign_in_scene_path)


func _characters() -> Array:
	if _session == null or not _session.has_method("get_characters"):
		return []

	var raw_characters: Variant = _session.call("get_characters")
	return (raw_characters as Array).duplicate(true) if raw_characters is Array else []


func _can_create_character() -> bool:
	if _session == null or not _session.has_method("can_create_character"):
		return _characters().size() < MAX_CHARACTER_SLOTS

	return bool(_session.call("can_create_character"))


func _account_label() -> String:
	if _session == null:
		return "Account"

	var account_name := String(_session.get("account_name")).strip_edges()
	return account_name if not account_name.is_empty() else "Account"


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _make_slot_button(character_name: String, slot_label: String) -> Button:
	var button := _make_button(character_name)
	button.custom_minimum_size = Vector2(0.0, 72.0)
	button.text = "%s\n%s" % [character_name, slot_label]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 20)
	return button


func _make_empty_slot(label_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 58.0)
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_DARK, Color(0.18, 0.16, 0.1, 0.72), 1))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	margin.add_child(_make_label(label_text, 16, COLOR_TEXT_DIM))
	return panel


func _make_label(
	text: String,
	font_size: int,
	color: Color,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 40.0)
	_apply_button_style(button, false)
	return button


func _apply_button_style(button: Button, selected: bool) -> void:
	if button == null:
		return

	var normal_color := Color(0.23, 0.2, 0.11, 1.0) if selected else Color(0.16, 0.18, 0.15, 1.0)
	var border_color := COLOR_PANEL_BORDER_HOT if selected else COLOR_PANEL_BORDER
	button.add_theme_stylebox_override("normal", _button_style(normal_color, border_color, 2 if selected else 1))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.26, 0.27, 0.2, 1.0), COLOR_PANEL_BORDER_HOT, 2))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.1, 0.11, 0.1, 1.0), COLOR_PANEL_BORDER_HOT, 2))
	button.add_theme_color_override("font_color", COLOR_GOLD if selected else COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _panel_style(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style


func _button_style(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style
