## Compact UTC world time display.
##
## MMO-facing schedules should use one shared reference time. For this prototype
## the HUD reads UTC from the local system clock; later the server can push an
## authoritative UTC offset without changing the UI layout.
class_name WorldTimeHud
extends CanvasLayer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")

## Top-right offset from the viewport.
@export var screen_offset := Vector2(8.0, 8.0)
## Shows a small UTC suffix so testers know the clock is not local time.
@export var show_utc_suffix := true

var _root: Control
var _time_label: Label
var _last_display_minute := -1


func _ready() -> void:
	layer = UiStyle.LAYER_HUD_ACTIONS
	_build_ui()
	_update_utc_time(true)


func _process(_delta: float) -> void:
	_update_utc_time()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "WorldTimeRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.anchor_left = 1.0
	_root.anchor_top = 0.0
	_root.anchor_right = 1.0
	_root.anchor_bottom = 0.0
	_root.offset_left = -164.0 - screen_offset.x
	_root.offset_top = screen_offset.y
	_root.offset_right = -screen_offset.x
	_root.offset_bottom = screen_offset.y + 36.0
	add_child(_root)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UiStyle.compact_panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	_time_label = Label.new()
	_time_label.text = "--:--"
	_time_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.label_primary(_time_label, 20, 2)
	_time_label.add_theme_color_override("font_color", UiStyle.COLOR_GOLD)
	margin.add_child(_time_label)


func _update_utc_time(force := false) -> void:
	var time_data := Time.get_datetime_dict_from_system(true)
	var display_hour := int(time_data.get("hour", 0))
	var display_minute := int(time_data.get("minute", 0))
	var total_minutes := display_hour * 60 + display_minute
	if not force and total_minutes == _last_display_minute:
		return

	_last_display_minute = total_minutes
	if _time_label != null:
		var suffix := " UTC" if show_utc_suffix else ""
		_time_label.text = "%02d:%02d%s" % [display_hour, display_minute, suffix]
