## Top-right HUD button strip for game-wide UI shortcuts.
##
## Buttons in this strip open common player UI without coupling those windows
## to movement, combat, or networking code.
class_name TopRightHudMenu
extends CanvasLayer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")
const INVENTORY_ICON: Texture2D = preload("res://assets/ui/hud/inventory_button_icon.png")
const MENU_ICON: Texture2D = preload("res://assets/ui/hud/menu_button_icon.png")
const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"
const ROOT_WIDTH := 320.0

@export var screen_margin := Vector2(10.0, 6.0)
@export var button_size := Vector2(26.0, 26.0)
@export_range(0, 32, 1) var button_spacing := 3
## Optional inventory panel path. Playable scenes point this at InventoryPanel.
@export var inventory_panel_path: NodePath
## Optional master menu path. Playable scenes point this at MasterMenu.
@export var master_menu_path: NodePath

var _root: Control
var _inventory_button: Button
var _menu_button: Button
var _block_world_input_until_mouse_release := false


func _ready() -> void:
	layer = UiStyle.LAYER_HUD_ACTIONS
	add_to_group(WORLD_INPUT_BLOCKER_GROUP)
	_build_ui()


## PlayerController checks this group method before reading world input.
func blocks_world_input() -> bool:
	if _block_world_input_until_mouse_release:
		if _is_world_move_mouse_button_down():
			return true
		_block_world_input_until_mouse_release = false

	return false


func _build_ui() -> void:
	_create_root()

	var row := _create_button_row()
	_inventory_button = Button.new()
	_configure_icon_button(_inventory_button, "InventoryButton", "Inventory", INVENTORY_ICON)
	_inventory_button.pressed.connect(_on_inventory_button_pressed)
	row.add_child(_inventory_button)

	_menu_button = Button.new()
	_configure_icon_button(_menu_button, "MenuButton", "Menu", MENU_ICON)
	_menu_button.pressed.connect(_on_master_menu_button_pressed)
	row.add_child(_menu_button)


func _create_root() -> void:
	_root = Control.new()
	_root.name = "TopRightHudMenuRoot"
	_root.anchor_left = 1.0
	_root.anchor_top = 0.0
	_root.anchor_right = 1.0
	_root.anchor_bottom = 0.0
	_root.offset_left = -screen_margin.x - ROOT_WIDTH
	_root.offset_top = screen_margin.y
	_root.offset_right = -screen_margin.x
	_root.offset_bottom = screen_margin.y + button_size.y
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)


func _create_button_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ButtonRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", button_spacing)
	_root.add_child(row)
	return row


func _configure_icon_button(button: Button, button_name: String, tooltip: String, icon: Texture2D) -> void:
	button.name = button_name
	button.text = ""
	button.tooltip_text = tooltip
	button.icon = icon
	button.expand_icon = true
	button.custom_minimum_size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.gui_input.connect(_on_icon_button_gui_input)
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.add_theme_stylebox_override("pressed", _button_style(true))


func _find_inventory_panel() -> Node:
	if inventory_panel_path != NodePath(""):
		var panel := get_node_or_null(inventory_panel_path)
		if panel != null:
			return panel

	var panels := get_tree().get_nodes_in_group("inventory_panel")
	if panels.is_empty():
		return null

	return panels[0]


func _on_inventory_button_pressed() -> void:
	var panel := _find_inventory_panel()
	if panel == null:
		push_warning("Inventory button could not find an InventoryPanel.")
		return

	_toggle_panel(panel)
	get_viewport().set_input_as_handled()


func _find_master_menu() -> Node:
	if master_menu_path != NodePath(""):
		var menu := get_node_or_null(master_menu_path)
		if menu != null:
			return menu

	var menus := get_tree().get_nodes_in_group("master_menu")
	if menus.is_empty():
		return null

	return menus[0]


func _on_master_menu_button_pressed() -> void:
	var menu := _find_master_menu()
	if menu == null:
		push_warning("Menu button could not find a MasterMenu.")
		return

	if menu.has_method("toggle"):
		menu.call("toggle")
	else:
		menu.set("visible", not bool(menu.get("visible")))
	get_viewport().set_input_as_handled()


func _toggle_panel(panel: Node) -> void:
	if panel.has_method("toggle"):
		panel.call("toggle")
	else:
		panel.set("visible", not bool(panel.get("visible")))


func _on_icon_button_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return

	_block_world_input_until_mouse_release = true


func _is_world_move_mouse_button_down() -> bool:
	return (
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	)


func _button_style(is_hovered: bool) -> StyleBoxFlat:
	return UiStyle.hud_button_style(is_hovered)
