## In-game chat panel for the multiplayer playtest.
##
## The panel owns only UI behavior: focusing, typing, and rendering messages.
## Multiplayer delivery stays in `MultiplayerTestManager`, which lets the
## server validate and relay messages before players see them.
class_name ChatPanel
extends CanvasLayer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")
const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"
const EXPANDED_TAB_RECT := Rect2(16.0, -274.0, 62.0, 28.0)
const COLLAPSED_TAB_RECT := Rect2(8.0, -44.0, 62.0, 28.0)

@export var network_manager_path: NodePath = NodePath("../Network")
@export_range(20, 250, 1) var max_visible_lines := 80
@export_range(0.25, 10.0, 0.25, "suffix:s") var auto_hide_delay_seconds := 2.0
@export var reveal_on_new_message := true
@export var default_channel := "local"

var _network_manager: Node
var _root: Control
var _frame: PanelContainer
var _toggle_tab: Button
var _auto_hide_timer: Timer
var _messages: RichTextLabel
var _input: LineEdit
var _history: Array[String] = []
var _is_expanded := true
var _block_world_input_until_mouse_release := false


func _ready() -> void:
	layer = UiStyle.LAYER_CHAT
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	_build_ui()
	_schedule_auto_hide()
	call_deferred("_connect_network_manager")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		if _input != null and not _input.has_focus():
			_set_expanded(true)
			_input.grab_focus()
			_stop_auto_hide()
			get_viewport().set_input_as_handled()


## PlayerController checks this group method before reading world input.
func blocks_world_input() -> bool:
	if visible and _is_expanded and _input != null and _input.has_focus():
		return true

	if _block_world_input_until_mouse_release:
		if _is_world_move_mouse_button_down():
			return true
		_block_world_input_until_mouse_release = false

	return false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "ChatRoot"
	_root.anchor_left = 0.0
	_root.anchor_top = 1.0
	_root.anchor_right = 0.0
	_root.anchor_bottom = 1.0
	_root.offset_left = 16.0
	_root.offset_top = -246.0
	_root.offset_right = 456.0
	_root.offset_bottom = -18.0
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	_frame = PanelContainer.new()
	_frame.name = "ChatFrame"
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_frame.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	margin.add_child(rows)

	_messages = RichTextLabel.new()
	_messages.name = "Messages"
	_messages.bbcode_enabled = false
	_messages.fit_content = false
	_messages.scroll_active = true
	_messages.scroll_following = true
	_messages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_messages.mouse_filter = Control.MOUSE_FILTER_PASS
	rows.add_child(_messages)

	_input = LineEdit.new()
	_input.name = "Input"
	_input.placeholder_text = "Say..."
	_input.max_length = 180
	_input.clear_button_enabled = true
	_input.text_submitted.connect(_on_input_submitted)
	_input.gui_input.connect(_on_input_gui_input)
	_input.focus_entered.connect(_on_input_focus_entered)
	_input.focus_exited.connect(_on_input_focus_exited)
	rows.add_child(_input)

	_toggle_tab = Button.new()
	_toggle_tab.name = "ChatTab"
	_toggle_tab.anchor_left = 0.0
	_toggle_tab.anchor_top = 1.0
	_toggle_tab.anchor_right = 0.0
	_toggle_tab.anchor_bottom = 1.0
	_toggle_tab.focus_mode = Control.FOCUS_NONE
	_toggle_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_tab.add_theme_stylebox_override("normal", _tab_style(false))
	_toggle_tab.add_theme_stylebox_override("hover", _tab_style(true))
	_toggle_tab.add_theme_stylebox_override("pressed", _tab_style(true))
	_toggle_tab.gui_input.connect(_on_toggle_tab_gui_input)
	_toggle_tab.pressed.connect(_on_toggle_tab_pressed)
	add_child(_toggle_tab)

	_auto_hide_timer = Timer.new()
	_auto_hide_timer.name = "AutoHideTimer"
	_auto_hide_timer.one_shot = true
	_auto_hide_timer.timeout.connect(_on_auto_hide_timeout)
	add_child(_auto_hide_timer)

	_refresh_toggle_tab()


func _panel_style() -> StyleBoxFlat:
	return UiStyle.chat_panel_style()


func _tab_style(is_hovered: bool) -> StyleBoxFlat:
	return UiStyle.tab_style(is_hovered)


func _connect_network_manager() -> void:
	_network_manager = get_node_or_null(network_manager_path)
	if _network_manager == null:
		_append_system_message("Chat offline.")
		return

	if _network_manager.has_signal("chat_message_received"):
		var message_callback := Callable(self, "_on_chat_message_received")
		if not _network_manager.is_connected("chat_message_received", message_callback):
			_network_manager.connect("chat_message_received", message_callback)

	if _network_manager.has_signal("chat_system_message_received"):
		var system_callback := Callable(self, "_on_chat_system_message_received")
		if not _network_manager.is_connected("chat_system_message_received", system_callback):
			_network_manager.connect("chat_system_message_received", system_callback)


func _on_input_submitted(text: String) -> void:
	var clean_message := text.strip_edges()
	if clean_message.is_empty():
		return

	if _network_manager != null and _network_manager.has_method("submit_chat_message"):
		var was_sent := bool(_network_manager.call("submit_chat_message", clean_message, default_channel))
		if was_sent:
			_input.clear()
			_input.release_focus()
			_schedule_auto_hide()
		return

	_append_system_message("Message not sent.")


func _on_input_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		_input.release_focus()
		_set_expanded(false)
		_input.accept_event()


func _on_input_focus_entered() -> void:
	_set_expanded(true)
	_stop_auto_hide()


func _on_input_focus_exited() -> void:
	_schedule_auto_hide()


func _on_toggle_tab_pressed() -> void:
	_set_expanded(not _is_expanded)


func _on_toggle_tab_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return

	_block_world_input_until_mouse_release = true


func _on_chat_message_received(
	_sender_peer_id: int,
	sender_name: String,
	channel: String,
	message: String
) -> void:
	var channel_label := channel.strip_edges().capitalize()
	if channel_label.is_empty():
		channel_label = "Local"

	var clean_name := sender_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Player"

	_append_line("[%s] %s: %s" % [channel_label, clean_name, message])


func _on_chat_system_message_received(message: String) -> void:
	_append_system_message(message)


func _append_system_message(message: String) -> void:
	_append_line("[System] %s" % message)


func _append_line(line: String) -> void:
	var clean_line := line.strip_edges()
	if clean_line.is_empty():
		return

	var time_data := Time.get_time_dict_from_system()
	var timestamp := "%02d:%02d" % [int(time_data.get("hour", 0)), int(time_data.get("minute", 0))]
	_history.append("%s  %s" % [timestamp, clean_line])
	while _history.size() > max_visible_lines:
		_history.pop_front()

	if _messages != null:
		_messages.text = "\n".join(_history)
		call_deferred("_scroll_to_bottom")

	if reveal_on_new_message:
		_set_expanded(true)
	_schedule_auto_hide()


func _scroll_to_bottom() -> void:
	if _messages == null:
		return

	_messages.scroll_to_line(maxi(_history.size() - 1, 0))


func _set_expanded(is_expanded: bool) -> void:
	_is_expanded = is_expanded
	if _root != null:
		_root.visible = _is_expanded
	if not _is_expanded and _input != null:
		_input.release_focus()
	if _is_expanded:
		_schedule_auto_hide()
	else:
		_stop_auto_hide()
	_refresh_toggle_tab()


func _refresh_toggle_tab() -> void:
	if _toggle_tab == null:
		return

	_toggle_tab.text = "Hide" if _is_expanded else "Chat"
	var tab_rect := EXPANDED_TAB_RECT if _is_expanded else COLLAPSED_TAB_RECT
	_toggle_tab.offset_left = tab_rect.position.x
	_toggle_tab.offset_top = tab_rect.position.y
	_toggle_tab.offset_right = tab_rect.position.x + tab_rect.size.x
	_toggle_tab.offset_bottom = tab_rect.position.y + tab_rect.size.y


func _schedule_auto_hide() -> void:
	if _auto_hide_timer == null or not _is_expanded:
		return
	if _input != null and _input.has_focus():
		return
	if auto_hide_delay_seconds <= 0.0:
		return

	_auto_hide_timer.start(auto_hide_delay_seconds)


func _stop_auto_hide() -> void:
	if _auto_hide_timer != null:
		_auto_hide_timer.stop()


func _on_auto_hide_timeout() -> void:
	if _input != null and _input.has_focus():
		return

	_set_expanded(false)


func _is_world_move_mouse_button_down() -> bool:
	return (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)
