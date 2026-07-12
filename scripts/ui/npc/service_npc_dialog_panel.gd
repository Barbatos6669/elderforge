## Small interaction window for NPC-backed service stations.
##
## The world station still owns recipes and interaction range. This panel only
## gives the player a human-facing choice: use the service, talk, or close.
class_name ServiceNpcDialogPanel
extends CanvasLayer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")
const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"

## Shows this panel at scene start for isolated UI previews.
@export var start_visible := false

var _station: Node
var _root: Control
var _title_label: Label
var _subtitle_label: Label
var _body_label: Label
var _service_button: Button
var _talk_button: Button
var _close_button: Button
var _block_world_input_until_mouse_release := false


func _ready() -> void:
	add_to_group("service_npc_dialog_panel")
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	visible = start_visible
	_build_window()
	_refresh()


## Opens the dialogue for a service NPC station.
func open_for_station(station: Node) -> void:
	_station = station
	visible = true
	_block_world_input_until_mouse_release = false
	_refresh()


func close(block_until_release := true) -> void:
	visible = false
	if block_until_release:
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
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.08)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "Window"
	panel.custom_minimum_size = Vector2(460.0, 210.0)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -230.0
	panel.offset_top = -250.0
	panel.offset_right = 230.0
	panel.offset_bottom = -40.0
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)

	_title_label = Label.new()
	_title_label.text = "Service NPC"
	UiStyle.label_primary(_title_label, 22, 1)
	title_stack.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Town service"
	UiStyle.label_muted(_subtitle_label, 13)
	title_stack.add_child(_subtitle_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(36.0, 34.0)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_body_label = Label.new()
	_body_label.text = ""
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiStyle.label_muted(_body_label, 14)
	layout.add_child(_body_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	layout.add_child(actions)

	_service_button = _build_action_button("Service")
	_service_button.pressed.connect(_on_service_pressed)
	actions.add_child(_service_button)

	_talk_button = _build_action_button("Talk")
	_talk_button.pressed.connect(_on_talk_pressed)
	actions.add_child(_talk_button)

	var close_action := _build_action_button("Close")
	close_action.pressed.connect(close)
	actions.add_child(close_action)


func _build_action_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(132.0, 42.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_PRIMARY)
	button.add_theme_stylebox_override("normal", UiStyle.master_menu_submenu_button_style(false))
	button.add_theme_stylebox_override("hover", UiStyle.master_menu_submenu_button_style(true))
	button.add_theme_stylebox_override("pressed", UiStyle.master_menu_submenu_button_style(true))
	return button


func _refresh() -> void:
	if _title_label == null:
		return

	var data := _station_dialog_data()
	_title_label.text = String(data.get("title", "Service NPC")).to_upper()
	_subtitle_label.text = String(data.get("subtitle", "Town service"))
	_body_label.text = String(data.get("description", "Choose a service."))
	_service_button.text = String(data.get("action_label", "Service"))
	_service_button.disabled = _station == null or not _station.has_method("open_service_menu")
	_talk_button.disabled = _station == null


func _station_dialog_data() -> Dictionary:
	if _station != null and _station.has_method("get_service_dialog_data"):
		var data: Variant = _station.call("get_service_dialog_data")
		if data is Dictionary:
			return data

	return {
		"title": "Service NPC",
		"subtitle": "Town service",
		"action_label": "Service",
		"description": "Choose a service.",
		"talk_text": "Nothing to say yet.",
	}


func _on_service_pressed() -> void:
	if _station == null or not _station.has_method("open_service_menu"):
		return

	close(false)
	_station.call("open_service_menu")


func _on_talk_pressed() -> void:
	var data := _station_dialog_data()
	_body_label.text = String(data.get("talk_text", "Nothing to say yet."))


func _is_world_move_mouse_button_down() -> bool:
	return (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)
