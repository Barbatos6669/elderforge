## Top-left player status HUD.
##
## Shows the local player's portrait placeholder, name, health, and mana. Health
## is read from CombatHealth. Mana is read from a ResourcePool.
class_name PlayerStatusHud
extends CanvasLayer

const HudProfilePortraitScript := preload("res://scripts/ui/hud/hud_profile_portrait.gd")

## Player name shown beside the profile image.
@export var player_name := "Player"
## Health component to observe.
@export var health_path: NodePath
## Mana/energy ResourcePool to observe.
@export var mana_path: NodePath
## Top-left offset from the viewport.
@export var screen_offset := Vector2(8.0, 8.0)

var _root: Control
var _name_label: Label
var _health_bar: ProgressBar
var _health_label: Label
var _mana_bar: ProgressBar
var _mana_label: Label
var _health: Node
var _mana: Node


func _ready() -> void:
	layer = 10
	_build_ui()
	call_deferred("_connect_sources")


func _connect_sources() -> void:
	_health = get_node_or_null(health_path) if health_path != NodePath("") else null
	_mana = get_node_or_null(mana_path) if mana_path != NodePath("") else null

	if _health != null and _health.has_signal("health_changed"):
		_health.health_changed.connect(_on_health_changed)
	if _mana != null and _mana.has_signal("resource_changed"):
		_mana.resource_changed.connect(_on_mana_changed)

	_refresh_health_from_source()
	_refresh_mana_from_source()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "PlayerStatusRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.anchor_left = 0.0
	_root.anchor_top = 0.0
	_root.anchor_right = 0.0
	_root.anchor_bottom = 0.0
	_root.offset_left = screen_offset.x
	_root.offset_top = screen_offset.y
	_root.offset_right = screen_offset.x + 260.0
	_root.offset_bottom = screen_offset.y + 78.0
	add_child(_root)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	var portrait := HudProfilePortraitScript.new() as Control
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(58.0, 58.0)
	row.add_child(portrait)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 3)
	row.add_child(stack)

	_name_label = Label.new()
	_name_label.text = player_name
	_name_label.custom_minimum_size = Vector2(0.0, 18.0)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.82, 1.0))
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(_name_label)

	stack.add_child(_build_bar_row(true))
	stack.add_child(_build_bar_row(false))


## Updates the HUD name after the auth flow chooses a character name.
func set_player_name(new_player_name: String) -> void:
	player_name = new_player_name.strip_edges()
	if player_name.is_empty():
		player_name = "Player"
	if _name_label != null:
		_name_label.text = player_name


func _build_bar_row(is_health: bool) -> Control:
	var holder := Control.new()
	holder.name = "HealthRow" if is_health else "ManaRow"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(0.0, 16.0)

	var bar := ProgressBar.new()
	bar.name = "HealthBar" if is_health else "ManaBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_theme_stylebox_override("background", _bar_background_style())
	bar.add_theme_stylebox_override("fill", _health_fill_style() if is_health else _mana_fill_style())
	holder.add_child(bar)

	var label := Label.new()
	label.name = "HealthText" if is_health else "ManaText"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	holder.add_child(label)

	if is_health:
		_health_bar = bar
		_health_label = label
	else:
		_mana_bar = bar
		_mana_label = label

	return holder


func _refresh_health_from_source() -> void:
	if _health == null:
		_set_health_display(1.0, 0.0, 0.0)
		return

	var current := float(_health.get("current_health"))
	var max_value := float(_health.get("max_health"))
	var ratio := float(_health.call("get_health_ratio")) if _health.has_method("get_health_ratio") else _safe_ratio(current, max_value)
	_set_health_display(ratio, current, max_value)


func _refresh_mana_from_source() -> void:
	if _mana == null:
		_set_mana_display(1.0, 0.0, 0.0)
		return

	var current := float(_mana.get("current_resource"))
	var max_value := float(_mana.get("max_resource"))
	var ratio := float(_mana.call("get_resource_ratio")) if _mana.has_method("get_resource_ratio") else _safe_ratio(current, max_value)
	_set_mana_display(ratio, current, max_value)


func _on_health_changed(current_health: float, max_health: float, health_ratio: float) -> void:
	_set_health_display(health_ratio, current_health, max_health)


func _on_mana_changed(current_resource: float, max_resource: float, resource_ratio: float) -> void:
	_set_mana_display(resource_ratio, current_resource, max_resource)


func _set_health_display(ratio: float, current: float, max_value: float) -> void:
	if _health_bar != null:
		_health_bar.value = clampf(ratio, 0.0, 1.0)
	if _health_label != null:
		_health_label.text = _format_value_pair(current, max_value)


func _set_mana_display(ratio: float, current: float, max_value: float) -> void:
	if _mana_bar != null:
		_mana_bar.value = clampf(ratio, 0.0, 1.0)
	if _mana_label != null:
		_mana_label.text = _format_value_pair(current, max_value)


func _safe_ratio(current: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0

	return clampf(current / max_value, 0.0, 1.0)


func _format_value_pair(current: float, max_value: float) -> String:
	return "%d / %d" % [roundi(current), roundi(max_value)]


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.062, 0.055, 0.90)
	style.border_color = Color(0.56, 0.47, 0.22, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _bar_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.027, 0.025, 1.0)
	style.border_color = Color(0.0, 0.0, 0.0, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


func _health_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.78, 0.12, 0.08, 1.0)
	style.border_color = Color(0.95, 0.32, 0.18, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


func _mana_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.36, 0.86, 1.0)
	style.border_color = Color(0.25, 0.62, 1.0, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style
