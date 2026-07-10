## HUD progress bar for the player's current channel.
##
## The bar only mirrors PlayerChanneling signals. It does not decide what the
## channel does when it completes.
class_name ChannelBar
extends CanvasLayer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")

## PlayerChanneling node to observe.
@export var channeling_path: NodePath
## Vertical offset from the bottom center of the viewport.
@export_range(24.0, 260.0, 1.0) var bottom_offset: float = 132.0
## Width of the visible channel bar.
@export_range(180.0, 520.0, 1.0) var bar_width: float = 360.0
## Height of the visible channel bar.
@export_range(20.0, 80.0, 1.0) var bar_height: float = 34.0

var _root: Control
var _action_label: Label
var _progress_bar: ProgressBar
var _time_label: Label
var _channeling: Node


func _ready() -> void:
	_build_ui()
	visible = false
	call_deferred("_connect_channeling")


func _connect_channeling() -> void:
	_channeling = get_node_or_null(channeling_path) if channeling_path != NodePath("") else null
	if _channeling == null:
		var parent_node := get_parent()
		if parent_node != null:
			_channeling = parent_node.get_node_or_null("Channeling")

	if _channeling == null:
		return

	if _channeling.has_signal("channel_started"):
		_channeling.connect("channel_started", Callable(self, "_on_channel_started"))
	if _channeling.has_signal("channel_progress_changed"):
		_channeling.connect("channel_progress_changed", Callable(self, "_on_channel_progress_changed"))
	if _channeling.has_signal("channel_completed"):
		_channeling.connect("channel_completed", Callable(self, "_on_channel_completed"))
	if _channeling.has_signal("channel_cancelled"):
		_channeling.connect("channel_cancelled", Callable(self, "_on_channel_cancelled"))


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "ChannelBarRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_root.offset_left = -bar_width * 0.5
	_root.offset_right = bar_width * 0.5
	_root.offset_top = -bottom_offset
	_root.offset_bottom = -bottom_offset + bar_height
	add_child(_root)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	var label_row := HBoxContainer.new()
	label_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(label_row)

	_action_label = Label.new()
	_action_label.text = ""
	_action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_primary(_action_label, 13)
	label_row.add_child(_action_label)

	_time_label = Label.new()
	_time_label.text = ""
	_time_label.custom_minimum_size = Vector2(58.0, 0.0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_muted(_time_label, 12)
	label_row.add_child(_time_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.add_theme_stylebox_override("background", _bar_background_style())
	_progress_bar.add_theme_stylebox_override("fill", _bar_fill_style())
	stack.add_child(_progress_bar)


func _on_channel_started(action_name: String, duration: float, _context: Dictionary) -> void:
	_action_label.text = action_name
	_time_label.text = _format_seconds(duration)
	_progress_bar.value = 0.0
	visible = true


func _on_channel_progress_changed(progress: float, _elapsed: float, remaining: float) -> void:
	_progress_bar.value = progress
	_time_label.text = _format_seconds(remaining)


func _on_channel_completed(_context: Dictionary) -> void:
	visible = false


func _on_channel_cancelled(_reason: String, _context: Dictionary) -> void:
	visible = false


func _format_seconds(value: float) -> String:
	return "%.1fs" % maxf(value, 0.0)


func _panel_style() -> StyleBoxFlat:
	return UiStyle.compact_panel_style()


func _bar_background_style() -> StyleBoxFlat:
	return UiStyle.channel_background_style()


func _bar_fill_style() -> StyleBoxFlat:
	return UiStyle.channel_fill_style()
