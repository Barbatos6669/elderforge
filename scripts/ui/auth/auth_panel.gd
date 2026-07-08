## First-pass sign-in and account creation screen.
##
## The panel owns UI state only. PrototypeAuthSession owns the local mock
## account data, and gameplay nodes receive only the signed-in display name.
class_name AuthPanel
extends CanvasLayer

signal authentication_succeeded(display_name: String)

const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"
const PLAYTEST_CONFIG_FILE := "playtest_server.cfg"

@export var start_visible := true
@export var default_display_name := "Barabtos6669"
@export var player_path: NodePath
@export var status_hud_path: NodePath
@export var network_manager_path: NodePath
@export var auto_join_after_sign_in := true
@export var playtest_server_address := "127.0.0.1"
@export_range(1024, 65535, 1) var playtest_server_port := 24566

var _session: Node
var _root: Control
var _window: PanelContainer
var _title_label: Label
var _account_field: LineEdit
var _password_field: LineEdit
var _display_name_field: LineEdit
var _status_label: Label
var _sign_in_button: Button
var _create_button: Button
var _guest_button: Button


func _ready() -> void:
	layer = 120
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	_session = get_node_or_null("/root/PrototypeAuthSession")
	_apply_sidecar_playtest_target()
	_apply_command_line_playtest_target()
	_build_ui()
	visible = start_visible and not _is_command_line_server()
	if visible:
		call_deferred("_focus_first_field")


func blocks_world_input() -> bool:
	return visible


func open() -> void:
	visible = true
	_set_status("")
	call_deferred("_focus_first_field")


func close() -> void:
	visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "AuthRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	_window = PanelContainer.new()
	_window.name = "Window"
	_window.custom_minimum_size = Vector2(430.0, 0.0)
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -215.0
	_window.offset_top = -190.0
	_window.offset_right = 215.0
	_window.offset_bottom = 190.0
	_window.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_window)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_window.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	_title_label = Label.new()
	_title_label.text = "Elderforge"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(0.97, 0.86, 0.42, 1.0))
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_title_label.add_theme_constant_override("outline_size", 2)
	layout.add_child(_title_label)

	_account_field = _build_field(layout, "Account", false)
	_password_field = _build_field(layout, "Password", true)
	_display_name_field = _build_field(layout, "Character Name", false)
	_display_name_field.text = default_display_name

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	layout.add_child(button_row)

	_sign_in_button = _build_button("Sign In")
	_sign_in_button.pressed.connect(_on_sign_in_pressed)
	button_row.add_child(_sign_in_button)

	_create_button = _build_button("Create")
	_create_button.pressed.connect(_on_create_pressed)
	button_row.add_child(_create_button)

	_guest_button = _build_button("Guest")
	_guest_button.pressed.connect(_on_guest_pressed)
	button_row.add_child(_guest_button)

	_status_label = Label.new()
	_status_label.custom_minimum_size = Vector2(0.0, 30.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62, 1.0))
	layout.add_child(_status_label)

	_account_field.text_submitted.connect(_on_text_submitted)
	_password_field.text_submitted.connect(_on_text_submitted)
	_display_name_field.text_submitted.connect(_on_text_submitted)


func _build_field(parent: Control, placeholder: String, is_secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = is_secret
	field.custom_minimum_size = Vector2(0.0, 34.0)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_stylebox_override("normal", _field_style(false))
	field.add_theme_stylebox_override("focus", _field_style(true))
	field.add_theme_font_size_override("font_size", 15)
	parent.add_child(field)
	return field


func _build_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 36.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _button_style(Color(0.16, 0.18, 0.15, 1.0), Color(0.52, 0.45, 0.2, 1.0)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.23, 0.25, 0.2, 1.0), Color(0.9, 0.73, 0.26, 1.0)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.1, 0.11, 0.1, 1.0), Color(0.9, 0.73, 0.26, 1.0)))
	button.add_theme_color_override("font_color", Color(0.95, 0.9, 0.76, 1.0))
	return button


func _on_sign_in_pressed() -> void:
	if _session == null:
		_set_status("Auth session not available.")
		return
	_handle_auth_result(_session.sign_in(_account_field.text, _password_field.text))


func _on_create_pressed() -> void:
	if _session == null:
		_set_status("Auth session not available.")
		return
	_handle_auth_result(_session.create_account(_account_field.text, _display_name_field.text, _password_field.text))


func _on_guest_pressed() -> void:
	if _session == null:
		_set_status("Auth session not available.")
		return
	_handle_auth_result(_session.play_as_guest(_display_name_field.text))


func _on_text_submitted(_submitted_text: String) -> void:
	_on_sign_in_pressed()


func _handle_auth_result(result: Dictionary) -> void:
	_set_status(String(result.get("message", "")))
	if not bool(result.get("ok", false)):
		return

	if _session.has_method("set_playtest_server"):
		_session.call(
			"set_playtest_server",
			playtest_server_address,
			playtest_server_port,
			auto_join_after_sign_in
		)
	_apply_signed_in_display_name(_session.display_name)
	authentication_succeeded.emit(String(_session.display_name))
	close()


func _apply_signed_in_display_name(new_display_name: String) -> void:
	var clean_name := new_display_name.strip_edges()
	if clean_name.is_empty():
		clean_name = default_display_name

	var player := get_node_or_null(player_path)
	var nameplate := player.get_node_or_null("Nameplate") if player != null else null
	if nameplate != null and nameplate.has_method("set_player_name"):
		nameplate.call("set_player_name", clean_name)

	var status_hud := get_node_or_null(status_hud_path)
	if status_hud != null and status_hud.has_method("set_player_name"):
		status_hud.call("set_player_name", clean_name)

	var network_manager := get_node_or_null(network_manager_path)
	if network_manager != null and network_manager.has_method("set_local_player_name"):
		network_manager.call("set_local_player_name", clean_name)


func _focus_first_field() -> void:
	if _account_field != null:
		_account_field.grab_focus()


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _is_command_line_server() -> bool:
	for argument in _all_command_line_arguments():
		var normalized_argument := argument.strip_edges().to_lower()
		if normalized_argument == "--server" or normalized_argument == "--dedicated-server":
			return true

	return false


func _apply_command_line_playtest_target() -> void:
	for argument in _all_command_line_arguments():
		var clean_argument := argument.strip_edges()
		var normalized_argument := clean_argument.to_lower()
		if normalized_argument.begins_with("--connect="):
			_apply_connect_argument(clean_argument.get_slice("=", 1))
		elif normalized_argument.begins_with("--playtest-server="):
			_apply_connect_argument(clean_argument.get_slice("=", 1))
		elif normalized_argument.begins_with("--connect-port="):
			playtest_server_port = _parse_port(clean_argument.get_slice("=", 1), playtest_server_port)
		elif normalized_argument.begins_with("--playtest-port="):
			playtest_server_port = _parse_port(clean_argument.get_slice("=", 1), playtest_server_port)


func _apply_sidecar_playtest_target() -> void:
	for config_path in _playtest_config_paths():
		var config := ConfigFile.new()
		var error := config.load(config_path)
		if error != OK:
			continue

		var configured_address := String(config.get_value("server", "address", "")).strip_edges()
		if not configured_address.is_empty():
			playtest_server_address = configured_address

		playtest_server_port = _parse_port(
			str(config.get_value("server", "port", playtest_server_port)),
			playtest_server_port
		)
		return


func _playtest_config_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	paths.append("res://%s" % PLAYTEST_CONFIG_FILE)

	var executable_path := OS.get_executable_path()
	var executable_dir := executable_path.get_base_dir()
	if not executable_dir.is_empty():
		paths.append(executable_dir.path_join(PLAYTEST_CONFIG_FILE))

	return paths


func _apply_connect_argument(raw_value: String) -> void:
	var clean_value := raw_value.strip_edges()
	if clean_value.is_empty():
		return

	var separator_index := clean_value.rfind(":")
	if separator_index > 0 and separator_index < clean_value.length() - 1:
		playtest_server_address = clean_value.substr(0, separator_index)
		playtest_server_port = _parse_port(clean_value.substr(separator_index + 1), playtest_server_port)
	else:
		playtest_server_address = clean_value


func _parse_port(raw_value: String, fallback: int) -> int:
	var clean_value := raw_value.strip_edges()
	if not clean_value.is_valid_int():
		return fallback

	return clampi(int(clean_value), 1024, 65535)


func _all_command_line_arguments() -> PackedStringArray:
	var arguments := PackedStringArray()
	arguments.append_array(OS.get_cmdline_args())
	arguments.append_array(OS.get_cmdline_user_args())
	return arguments


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.085, 0.075, 0.98)
	style.border_color = Color(0.67, 0.56, 0.22, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _field_style(is_focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.04, 0.035, 1.0)
	style.border_color = Color(0.88, 0.72, 0.28, 1.0) if is_focused else Color(0.34, 0.35, 0.28, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style
