## Center-screen death and respawn message.
##
## This HUD listens to the local player's PlayerRespawn module. It does not
## decide when the player dies or respawns; it only mirrors that lifecycle state
## with a readable message and countdown.
class_name DeathMessageHud
extends CanvasLayer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")

## PlayerRespawn node to observe.
@export var respawn_path: NodePath
## Main text shown while the player is dead.
@export var title_text := "YOU DIED"
## Smaller text shown above the countdown.
@export var subtitle_text := "Respawning"

var _root: Control
var _title_label: Label
var _countdown_label: Label
var _respawn: Node
var _remaining_time := 0.0
var _is_showing := false


func _ready() -> void:
	layer = UiStyle.LAYER_MODAL_NOTICE
	_build_ui()
	hide_message()
	call_deferred("_connect_respawn")


func _process(delta: float) -> void:
	if not _is_showing:
		return

	_remaining_time = maxf(_remaining_time - maxf(delta, 0.0), 0.0)
	_update_countdown_text()


func show_message(respawn_delay: float) -> void:
	_remaining_time = maxf(respawn_delay, 0.0)
	_is_showing = true
	if _root != null:
		_root.visible = true
	_update_countdown_text()


func hide_message() -> void:
	_is_showing = false
	_remaining_time = 0.0
	if _root != null:
		_root.visible = false


func _connect_respawn() -> void:
	_respawn = get_node_or_null(respawn_path) if respawn_path != NodePath("") else null
	if _respawn == null:
		push_warning("DeathMessageHud could not find PlayerRespawn at %s." % respawn_path)
		return

	if _respawn.has_signal("death_started"):
		_respawn.death_started.connect(_on_death_started)
	if _respawn.has_signal("respawned"):
		_respawn.respawned.connect(_on_respawned)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "DeathMessageRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "MessagePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(360.0, 128.0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	_title_label = Label.new()
	_title_label.text = title_text
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(0.92, 0.14, 0.10, 1.0))
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_title_label.add_theme_constant_override("outline_size", 3)
	stack.add_child(_title_label)

	_countdown_label = Label.new()
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_primary(_countdown_label, 17, 2)
	stack.add_child(_countdown_label)


func _update_countdown_text() -> void:
	if _countdown_label == null:
		return

	_countdown_label.text = "%s in %ds" % [subtitle_text, ceili(_remaining_time)]


func _on_death_started(respawn_delay: float) -> void:
	show_message(respawn_delay)


func _on_respawned() -> void:
	hide_message()


func _panel_style() -> StyleBoxFlat:
	return UiStyle.death_panel_style()
