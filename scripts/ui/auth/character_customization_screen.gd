## Character customization screen shown after sign-in and before world entry.
##
## The screen stores appearance choices in PrototypeAuthSession. The preview is a
## real 3D SubViewport, so changes here should closely match the spawned player.
class_name CharacterCustomizationScreen
extends CanvasLayer

const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"
const COLOR_PANEL := Color(0.045, 0.055, 0.058, 0.96)
const COLOR_PANEL_ALT := Color(0.075, 0.085, 0.078, 0.96)
const COLOR_PANEL_DARK := Color(0.025, 0.03, 0.032, 1.0)
const COLOR_PANEL_BORDER := Color(0.54, 0.45, 0.2, 1.0)
const COLOR_PANEL_BORDER_HOT := Color(0.9, 0.73, 0.26, 1.0)
const COLOR_TEXT := Color(0.95, 0.9, 0.76, 1.0)
const COLOR_TEXT_DIM := Color(0.68, 0.72, 0.66, 1.0)
const COLOR_GOLD := Color(0.97, 0.86, 0.42, 1.0)
const DEFAULT_SKIN_COLOR := Color(0.74, 0.86, 0.92, 1.0)
const DEFAULT_HAIR_COLOR := Color(0.16, 0.11, 0.08, 1.0)
const CharacterAppearancePreviewScript := preload("res://scripts/ui/auth/character_appearance_preview.gd")

const BODY_TYPES: Array[Dictionary] = [
	{"id": "male", "label": "Male"},
	{"id": "female", "label": "Female"},
]

const SKIN_OPTIONS: Array[Dictionary] = [
	{"id": "moonlit", "label": "Moonlit", "color": Color(0.74, 0.86, 0.92, 1.0)},
	{"id": "fair", "label": "Fair", "color": Color(0.86, 0.68, 0.54, 1.0)},
	{"id": "rose", "label": "Rose", "color": Color(0.76, 0.53, 0.43, 1.0)},
	{"id": "tan", "label": "Tan", "color": Color(0.64, 0.45, 0.31, 1.0)},
	{"id": "deep", "label": "Deep", "color": Color(0.34, 0.22, 0.16, 1.0)},
	{"id": "ember", "label": "Ember", "color": Color(0.72, 0.42, 0.32, 1.0)},
	{"id": "ashen", "label": "Ashen", "color": Color(0.52, 0.56, 0.58, 1.0)},
]

const HAIR_STYLES: Array[Dictionary] = [
	{"id": "short", "label": "Short"},
	{"id": "buzzed", "label": "Buzzed"},
	{"id": "long", "label": "Long"},
	{"id": "buns", "label": "Buns"},
	{"id": "none", "label": "None"},
]

const HAIR_COLOR_OPTIONS: Array[Dictionary] = [
	{"id": "black", "label": "Black", "color": Color(0.035, 0.028, 0.025, 1.0)},
	{"id": "brown", "label": "Brown", "color": Color(0.16, 0.11, 0.08, 1.0)},
	{"id": "auburn", "label": "Auburn", "color": Color(0.42, 0.18, 0.09, 1.0)},
	{"id": "gold", "label": "Gold", "color": Color(0.86, 0.62, 0.22, 1.0)},
	{"id": "silver", "label": "Silver", "color": Color(0.72, 0.76, 0.78, 1.0)},
]

const CUSTOMIZATION_STEPS: Array[Dictionary] = [
	{"id": "body", "label": "Body"},
	{"id": "skin", "label": "Skin"},
	{"id": "hair", "label": "Hair"},
]

@export_file("*.tscn") var game_scene_path := "res://scenes/world/starting_city/StartingCity.tscn"
@export_file("*.tscn") var sign_in_scene_path := "res://scenes/bootstrap/SignInGateway.tscn"
@export_file("*.tscn") var character_selection_scene_path := "res://scenes/ui/auth/CharacterSelectionScreen.tscn"

var _session: Node
var _current_step_index := 0
var _selected_body_type := "male"
var _selected_skin_color := DEFAULT_SKIN_COLOR
var _selected_hair_style := "short"
var _selected_hair_color := DEFAULT_HAIR_COLOR
var _body_buttons := {}
var _hair_buttons := {}
var _step_buttons := {}
var _option_pages := {}
var _skin_buttons: Array[Button] = []
var _hair_color_buttons: Array[Button] = []
var _preview: Control
var _character_name_field: LineEdit
var _step_status_label: Label
var _status_label: Label
var _zoom_slider: HSlider
var _previous_step_button: Button
var _next_step_button: Button


func _ready() -> void:
	layer = 120
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	_session = get_node_or_null("/root/PrototypeAuthSession")
	_load_session_appearance()
	_build_ui()
	_refresh_controls()
	if _character_name_field != null:
		_character_name_field.call_deferred("grab_focus")


func blocks_world_input() -> bool:
	return visible


func _build_ui() -> void:
	var root := Control.new()
	root.name = "CharacterCustomizationRoot"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var workspace := HBoxContainer.new()
	workspace.name = "Workspace"
	workspace.mouse_filter = Control.MOUSE_FILTER_STOP
	workspace.add_theme_constant_override("separation", 10)
	workspace.set_anchors_preset(Control.PRESET_FULL_RECT)
	workspace.offset_left = 10
	workspace.offset_top = 10
	workspace.offset_right = -10
	workspace.offset_bottom = -10
	root.add_child(workspace)

	workspace.add_child(_build_options_panel())
	workspace.add_child(_build_preview_panel())


func _build_options_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "OptionsPanel"
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 2))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := _make_label("%s's Account" % _account_name(), 14, COLOR_TEXT_DIM)
	layout.add_child(title)

	var heading := _make_label("Create Character", 30, COLOR_GOLD)
	layout.add_child(heading)

	var divider := HSeparator.new()
	layout.add_child(divider)

	_character_name_field = _make_text_field("Character Name")
	_character_name_field.text_changed.connect(_on_character_name_changed)
	layout.add_child(_character_name_field)

	layout.add_child(_build_step_selector())
	_step_status_label = _make_label("", 13, COLOR_TEXT_DIM)
	layout.add_child(_step_status_label)

	var options := VBoxContainer.new()
	options.name = "StepOptions"
	options.add_theme_constant_override("separation", 10)
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(options)
	_build_step_pages(options)

	layout.add_child(_build_step_navigation())

	return panel


func _build_step_selector() -> Control:
	var row := HBoxContainer.new()
	row.name = "StepSelector"
	row.add_theme_constant_override("separation", 6)

	for index in range(CUSTOMIZATION_STEPS.size()):
		var step_data: Dictionary = CUSTOMIZATION_STEPS[index]
		var button := _make_button(String(step_data["label"]))
		button.custom_minimum_size = Vector2(0.0, 32.0)
		button.toggle_mode = true
		button.pressed.connect(_on_step_selected.bind(index))
		row.add_child(button)
		_step_buttons[index] = button

	return row


func _build_step_pages(parent: Control) -> void:
	var body_page := _make_step_page("BodyPage")
	parent.add_child(body_page)
	_option_pages["body"] = body_page
	_add_body_type_controls(body_page)

	var skin_page := _make_step_page("SkinPage")
	parent.add_child(skin_page)
	_option_pages["skin"] = skin_page
	_add_skin_controls(skin_page)

	var hair_page := _make_step_page("HairPage")
	parent.add_child(hair_page)
	_option_pages["hair"] = hair_page
	_add_hair_controls(hair_page)
	_add_hair_color_controls(hair_page)


func _make_step_page(page_name: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = page_name
	page.add_theme_constant_override("separation", 10)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return page


func _build_step_navigation() -> Control:
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)

	var flow_buttons := HBoxContainer.new()
	flow_buttons.add_theme_constant_override("separation", 8)
	layout.add_child(flow_buttons)

	_previous_step_button = _make_button("Back")
	_previous_step_button.pressed.connect(_on_previous_step_pressed)
	flow_buttons.add_child(_previous_step_button)

	_next_step_button = _make_button("Next")
	_next_step_button.pressed.connect(_on_next_step_pressed)
	flow_buttons.add_child(_next_step_button)

	var reset_button := _make_button("Reset")
	reset_button.custom_minimum_size = Vector2(0.0, 34.0)
	reset_button.pressed.connect(_on_reset_pressed)
	layout.add_child(reset_button)

	return layout


func _build_preview_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PreviewPanel"
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, COLOR_PANEL_BORDER, 2))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)

	var icon := Label.new()
	icon.text = "O"
	icon.custom_minimum_size = Vector2(40.0, 40.0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 24)
	icon.add_theme_color_override("font_color", COLOR_GOLD)
	icon.add_theme_stylebox_override("normal", _panel_style(COLOR_PANEL_DARK, COLOR_PANEL_BORDER_HOT, 2))
	header.add_child(icon)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	title_box.add_child(_make_label("Character Preview", 24, COLOR_GOLD))
	_status_label = _make_label(_display_name(), 13, COLOR_TEXT_DIM)
	title_box.add_child(_status_label)

	_preview = CharacterAppearancePreviewScript.new()
	_preview.name = "CharacterAppearancePreview"
	_preview.custom_minimum_size = Vector2(320.0, 300.0)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_preview)

	layout.add_child(_build_preview_controls())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	layout.add_child(buttons)

	var back_button := _make_button("Back")
	back_button.pressed.connect(_on_back_pressed)
	buttons.add_child(back_button)

	var enter_button := _make_button("Enter World")
	enter_button.pressed.connect(_on_enter_world_pressed)
	buttons.add_child(enter_button)

	return panel


func _build_preview_controls() -> Control:
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)

	var rotation_row := HBoxContainer.new()
	rotation_row.add_theme_constant_override("separation", 8)
	controls.add_child(rotation_row)

	var rotate_left := _make_button("<")
	rotate_left.custom_minimum_size = Vector2(48.0, 38.0)
	rotate_left.pressed.connect(_on_rotate_left_pressed)
	rotation_row.add_child(rotate_left)

	var reset_rotation := _make_button("Reset View")
	reset_rotation.pressed.connect(_on_reset_view_pressed)
	rotation_row.add_child(reset_rotation)

	var rotate_right := _make_button(">")
	rotate_right.custom_minimum_size = Vector2(48.0, 38.0)
	rotate_right.pressed.connect(_on_rotate_right_pressed)
	rotation_row.add_child(rotate_right)

	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 8)
	controls.add_child(zoom_row)

	zoom_row.add_child(_make_label("Zoom", 14, COLOR_TEXT))
	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = 0.0
	_zoom_slider.max_value = 1.0
	_zoom_slider.step = 0.01
	_zoom_slider.value = 0.35
	_zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom_slider.value_changed.connect(_on_zoom_changed)
	zoom_row.add_child(_zoom_slider)

	return controls


func _add_body_type_controls(parent: Control) -> void:
	parent.add_child(_make_section_label("Gender"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	for body_data: Dictionary in BODY_TYPES:
		var body_id := String(body_data["id"])
		var button := _make_button(String(body_data["label"]))
		button.toggle_mode = true
		button.pressed.connect(_on_body_type_selected.bind(body_id))
		row.add_child(button)
		_body_buttons[body_id] = button


func _add_skin_controls(parent: Control) -> void:
	parent.add_child(_make_section_label("Skin Color"))

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)

	_skin_buttons.clear()
	for skin_data: Dictionary in SKIN_OPTIONS:
		var color := skin_data["color"] as Color
		var button := _make_swatch_button(color, String(skin_data["label"]))
		button.pressed.connect(_on_skin_color_selected.bind(color))
		grid.add_child(button)
		_skin_buttons.append(button)


func _add_hair_controls(parent: Control) -> void:
	parent.add_child(_make_section_label("Hairstyle"))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)

	for hair_data: Dictionary in HAIR_STYLES:
		var hair_id := String(hair_data["id"])
		var button := _make_button(String(hair_data["label"]))
		button.toggle_mode = true
		button.pressed.connect(_on_hair_style_selected.bind(hair_id))
		grid.add_child(button)
		_hair_buttons[hair_id] = button


func _add_hair_color_controls(parent: Control) -> void:
	parent.add_child(_make_section_label("Hair Color"))

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)

	_hair_color_buttons.clear()
	for hair_color_data: Dictionary in HAIR_COLOR_OPTIONS:
		var color := hair_color_data["color"] as Color
		var button := _make_swatch_button(color, String(hair_color_data["label"]))
		button.pressed.connect(_on_hair_color_selected.bind(color))
		grid.add_child(button)
		_hair_color_buttons.append(button)


func _on_body_type_selected(body_type: String) -> void:
	_selected_body_type = body_type
	_refresh_controls()


func _on_skin_color_selected(skin_color: Color) -> void:
	_selected_skin_color = skin_color
	_refresh_controls()


func _on_hair_style_selected(hair_style: String) -> void:
	_selected_hair_style = hair_style
	_refresh_controls()


func _on_hair_color_selected(hair_color: Color) -> void:
	_selected_hair_color = hair_color
	_refresh_controls()


func _on_character_name_changed(_new_text: String) -> void:
	if _status_label != null:
		_status_label.text = _display_name()


func _on_step_selected(step_index: int) -> void:
	_current_step_index = clampi(step_index, 0, CUSTOMIZATION_STEPS.size() - 1)
	_refresh_controls()


func _on_previous_step_pressed() -> void:
	if _current_step_index <= 0:
		_on_back_pressed()
		return

	_current_step_index -= 1
	_refresh_controls()


func _on_next_step_pressed() -> void:
	if _current_step_index >= CUSTOMIZATION_STEPS.size() - 1:
		_on_enter_world_pressed()
		return

	_current_step_index += 1
	_refresh_controls()


func _on_rotate_left_pressed() -> void:
	if _preview != null and _preview.has_method("rotate_preview_degrees"):
		_preview.call("rotate_preview_degrees", -18.0)


func _on_rotate_right_pressed() -> void:
	if _preview != null and _preview.has_method("rotate_preview_degrees"):
		_preview.call("rotate_preview_degrees", 18.0)


func _on_reset_view_pressed() -> void:
	if _preview != null and _preview.has_method("reset_rotation"):
		_preview.call("reset_rotation")
	if _zoom_slider != null:
		_zoom_slider.value = 0.35


func _on_zoom_changed(value: float) -> void:
	if _preview != null and _preview.has_method("set_zoom_ratio"):
		_preview.call("set_zoom_ratio", value)


func _on_reset_pressed() -> void:
	_current_step_index = 0
	_selected_body_type = "male"
	_selected_skin_color = DEFAULT_SKIN_COLOR
	_selected_hair_style = "short"
	_selected_hair_color = DEFAULT_HAIR_COLOR
	_refresh_controls()


func _on_back_pressed() -> void:
	if _session != null and _session.has_method("has_characters") and bool(_session.call("has_characters")):
		get_tree().change_scene_to_file(character_selection_scene_path)
		return

	if _session != null and _session.has_method("sign_out"):
		_session.call("sign_out")
	get_tree().change_scene_to_file(sign_in_scene_path)


func _on_enter_world_pressed() -> void:
	var character_name := _character_name()
	if character_name.is_empty():
		_set_status("Enter a character name.")
		return

	var appearance := _current_appearance()
	if _session != null and _session.has_method("create_character"):
		var result: Dictionary = _session.call("create_character", character_name, appearance)
		if not bool(result.get("ok", false)):
			_set_status(String(result.get("message", "Could not create character.")))
			return
	elif _session != null and _session.has_method("set_character_appearance"):
		_save_session_appearance()

	get_tree().change_scene_to_file(game_scene_path)


func _load_session_appearance() -> void:
	if _session == null or not _session.has_method("get_character_appearance"):
		return

	var appearance: Dictionary = _session.call("get_character_appearance")
	_selected_body_type = _sanitize_body_type(String(appearance.get("body_type", _selected_body_type)))
	_selected_skin_color = _color_from_html(String(appearance.get("skin_color", "")), _selected_skin_color)
	_selected_hair_style = _sanitize_hair_style(String(appearance.get("hair_style", _selected_hair_style)))
	_selected_hair_color = _color_from_html(String(appearance.get("hair_color", "")), _selected_hair_color)


func _save_session_appearance() -> void:
	if _session == null or not _session.has_method("set_character_appearance"):
		return

	_session.call(
		"set_character_appearance",
		_selected_body_type,
		_selected_skin_color,
		_selected_hair_style,
		_selected_hair_color
	)


func _current_appearance() -> Dictionary:
	return {
		"body_type": _selected_body_type,
		"skin_color": _selected_skin_color.to_html(true),
		"hair_style": _selected_hair_style,
		"hair_color": _selected_hair_color.to_html(true),
	}


func _refresh_controls() -> void:
	for body_id in _body_buttons.keys():
		var button := _body_buttons[body_id] as Button
		if button != null:
			var is_selected: bool = String(body_id) == _selected_body_type
			button.set_pressed_no_signal(is_selected)
			_apply_option_button_style(button, is_selected)

	for hair_id in _hair_buttons.keys():
		var button := _hair_buttons[hair_id] as Button
		if button != null:
			var is_selected: bool = String(hair_id) == _selected_hair_style
			button.set_pressed_no_signal(is_selected)
			_apply_option_button_style(button, is_selected)

	_refresh_step_state()
	_apply_swatch_selection_styles(_skin_buttons, _selected_skin_color)
	_apply_swatch_selection_styles(_hair_color_buttons, _selected_hair_color)

	if _preview != null:
		_preview.call(
			"set_appearance",
			_selected_body_type,
			_selected_skin_color,
			_selected_hair_style,
			_selected_hair_color
		)

	if _status_label != null:
		_status_label.text = _display_name()


func _refresh_step_state() -> void:
	_current_step_index = clampi(_current_step_index, 0, CUSTOMIZATION_STEPS.size() - 1)
	var current_step_data: Dictionary = CUSTOMIZATION_STEPS[_current_step_index]
	var current_step_id := String(current_step_data["id"])

	for step_index in _step_buttons.keys():
		var button := _step_buttons[step_index] as Button
		if button == null:
			continue

		var is_selected := int(step_index) == _current_step_index
		button.set_pressed_no_signal(is_selected)
		_apply_option_button_style(button, is_selected)

	for page_id in _option_pages.keys():
		var page := _option_pages[page_id] as Control
		if page != null:
			page.visible = String(page_id) == current_step_id

	if _step_status_label != null:
		_step_status_label.text = "Step %d of %d" % [_current_step_index + 1, CUSTOMIZATION_STEPS.size()]

	if _previous_step_button != null:
		_previous_step_button.text = "Sign In" if _current_step_index == 0 else "Back"

	if _next_step_button != null:
		_next_step_button.text = "Enter World" if _current_step_index == CUSTOMIZATION_STEPS.size() - 1 else "Next"


func _apply_swatch_selection_styles(buttons: Array[Button], selected_color: Color) -> void:
	for button in buttons:
		var color := button.get_meta("swatch_color") as Color
		var is_selected := _colors_match(color, selected_color)
		button.add_theme_stylebox_override("normal", _swatch_style(color, is_selected))
		button.add_theme_stylebox_override("hover", _swatch_style(color, true))
		button.add_theme_stylebox_override("pressed", _swatch_style(color.darkened(0.08), true))


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _character_name() -> String:
	if _character_name_field == null:
		return ""

	return _character_name_field.text.strip_edges()


func _display_name() -> String:
	var character_name := _character_name()
	if not character_name.is_empty():
		return character_name

	return "New Character"


func _account_name() -> String:
	if _session == null:
		return "Account"

	var account_name := String(_session.get("account_name")).strip_edges()
	return account_name if not account_name.is_empty() else "Account"


func _sanitize_body_type(body_type: String) -> String:
	return "female" if body_type.strip_edges().to_lower() == "female" else "male"


func _sanitize_hair_style(hair_style: String) -> String:
	var normalized := hair_style.strip_edges().to_lower()
	for hair_data: Dictionary in HAIR_STYLES:
		if String(hair_data["id"]) == normalized:
			return normalized

	return "short"


func _color_from_html(raw_value: String, fallback: Color) -> Color:
	var clean_value := raw_value.strip_edges()
	if clean_value.is_empty() or not Color.html_is_valid(clean_value):
		return fallback

	return Color.html(clean_value)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.035, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _make_section_label(text: String) -> Label:
	var label := _make_label(text, 17, COLOR_TEXT)
	label.custom_minimum_size = Vector2(0.0, 30.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", _panel_style(Color(0.09, 0.1, 0.09, 0.92), COLOR_PANEL_BORDER, 1))
	return label


func _make_text_field(placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(0.0, 36.0)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", 15)
	field.add_theme_color_override("font_color", COLOR_TEXT)
	field.add_theme_color_override("font_placeholder_color", COLOR_TEXT_DIM)
	field.add_theme_stylebox_override("normal", _input_style(false))
	field.add_theme_stylebox_override("focus", _input_style(true))
	return field


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 38.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_option_button_style(button, false)
	return button


func _make_swatch_button(color: Color, tooltip: String) -> Button:
	var button := Button.new()
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(44.0, 44.0)
	button.set_meta("swatch_color", color)
	button.add_theme_stylebox_override("normal", _swatch_style(color, false))
	button.add_theme_stylebox_override("hover", _swatch_style(color, true))
	button.add_theme_stylebox_override("pressed", _swatch_style(color.darkened(0.08), true))
	return button


func _apply_option_button_style(button: Button, is_selected: bool) -> void:
	if is_selected:
		button.add_theme_stylebox_override("normal", _button_style(Color(0.23, 0.2, 0.11, 1.0), COLOR_PANEL_BORDER_HOT, 2))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.29, 0.25, 0.14, 1.0), COLOR_GOLD, 2))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.13, 0.12, 0.08, 1.0), COLOR_GOLD, 2))
		button.add_theme_color_override("font_color", COLOR_GOLD)
	else:
		button.add_theme_stylebox_override("normal", _button_style(Color(0.16, 0.18, 0.15, 1.0), COLOR_PANEL_BORDER))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.23, 0.25, 0.2, 1.0), COLOR_PANEL_BORDER_HOT))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.1, 0.11, 0.1, 1.0), COLOR_PANEL_BORDER_HOT))
		button.add_theme_color_override("font_color", COLOR_TEXT)
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
	style.set_corner_radius_all(5)
	return style


func _input_style(is_focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL_DARK
	style.border_color = COLOR_PANEL_BORDER_HOT if is_focused else COLOR_PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _swatch_style(color: Color, is_selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1.0, 0.84, 0.22, 1.0) if is_selected else Color(0.18, 0.13, 0.09, 1.0)
	style.set_border_width_all(3 if is_selected else 1)
	style.set_corner_radius_all(4)
	return style


func _colors_match(left: Color, right: Color) -> bool:
	return (
		is_equal_approx(left.r, right.r)
		and is_equal_approx(left.g, right.g)
		and is_equal_approx(left.b, right.b)
		and is_equal_approx(left.a, right.a)
	)
