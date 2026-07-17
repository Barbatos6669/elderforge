## Draws one equipment-provided ability and its cooldown state.
##
## The control owns presentation only. Ability data and timing remain in
## PlayerWeaponAbilities so this slot can display any supported action-bar slot.
class_name WeaponAbilitySlot
extends Control

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")

signal ability_hint_requested(definition: Resource)
signal ability_hint_dismissed(definition: Resource)
signal ability_activation_requested

var _definition: Resource
var _remaining_seconds := 0.0
var _total_seconds := 0.0
var _key_hint := "Q"
var _key_label: Label
var _cooldown_label: Label
var _is_hovered := false
var _show_key_hint := true
var _uses_loadout_selection := false
var _is_loadout_selected := false
var _interaction_enabled := true


func _ready() -> void:
	# STOP gives this visible HUD control a hover target and prevents world clicks
	# from passing through the spell icon.
	_refresh_interaction_state()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(48.0, 48.0)
	_build_labels()
	_refresh_labels()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_labels()
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var unit := minf(size.x, size.y)
	var origin := (size - Vector2(unit, unit)) * 0.5
	var center := origin + Vector2(unit * 0.5, unit * 0.5)
	var outer_radius := unit * 0.47
	var inner_radius := unit * 0.40
	var icon_radius := inner_radius * 0.74
	var icon_rect := Rect2(
		center - Vector2(icon_radius, icon_radius),
		Vector2(icon_radius * 2.0, icon_radius * 2.0)
	)
	var cooldown_rect := Rect2(
		center - Vector2(inner_radius, inner_radius),
		Vector2(inner_radius * 2.0, inner_radius * 2.0)
	)

	draw_circle(center + Vector2(0.0, unit * 0.02), outer_radius + unit * 0.025, Color(0.0, 0.0, 0.0, 0.52))
	draw_circle(center, outer_radius, Color(0.045, 0.042, 0.034, 0.98))
	draw_circle(center, inner_radius, _icon_background_color())
	if _definition != null:
		_draw_ability_icon(icon_rect)

	var cooldown_fraction := _cooldown_fraction()
	if cooldown_fraction > 0.0:
		_draw_radial_cooldown(cooldown_rect, cooldown_fraction)

	var border_color := UiStyle.COLOR_GOLD_SOFT
	var border_width := maxf(unit * 0.025, 1.0)
	if _uses_loadout_selection:
		border_color = (
			Color(1.0, 0.84, 0.30, 1.0)
			if _is_loadout_selected
			else Color(0.38, 0.36, 0.30, 0.92)
		)
		border_width = maxf(unit * (0.052 if _is_loadout_selected else 0.022), 1.0)
	elif _definition != null and cooldown_fraction <= 0.0:
		border_color = Color(1.0, 0.82, 0.30, 1.0)
	draw_arc(center, outer_radius, 0.0, TAU, 64, border_color, border_width, true)
	if _uses_loadout_selection and _is_loadout_selected:
		draw_arc(
			center,
			outer_radius - unit * 0.065,
			0.0,
			TAU,
			64,
			Color(1.0, 0.94, 0.64, 0.94),
			maxf(unit * 0.018, 1.0),
			true
		)
	draw_arc(
		center,
		inner_radius,
		0.0,
		TAU,
		64,
		Color(0.02, 0.018, 0.014, 0.92),
		maxf(unit * 0.018, 1.0),
		true
	)


## Replaces the displayed spell when equipment changes.
func set_ability(definition: Resource) -> void:
	var previous_definition := _definition
	_definition = definition
	# Native tooltips can escape HUD zones. WeaponAbilityHud owns the hint panel
	# and confines it to the middle-center grid cell instead.
	tooltip_text = ""
	if _definition == null:
		_remaining_seconds = 0.0
		_total_seconds = 0.0
	if _is_hovered and previous_definition != _definition:
		if previous_definition != null:
			ability_hint_dismissed.emit(previous_definition)
		if _definition != null:
			ability_hint_requested.emit(_definition)
	_refresh_labels()
	queue_redraw()


func get_ability_definition() -> Resource:
	return _definition


## Updates the visible cooldown without owning gameplay timing.
func set_cooldown(remaining_seconds: float, total_seconds: float) -> void:
	_remaining_seconds = maxf(remaining_seconds, 0.0)
	_total_seconds = maxf(total_seconds, 0.0)
	_refresh_labels()
	queue_redraw()


## Sets the keyboard hint independently from ability data so empty placeholder
## slots still communicate their eventual input position.
func set_key_hint(key_hint: String) -> void:
	_key_hint = key_hint
	if _key_label != null:
		_key_label.text = _key_hint


func get_key_hint() -> String:
	return _key_hint


## Hides the embedded key badge when a parent row already identifies the slot.
func set_key_hint_visible(is_visible: bool) -> void:
	_show_key_hint = is_visible
	if _key_label != null:
		_key_label.visible = _show_key_hint


## Enables the stronger selected/unselected rings used by loadout pickers.
func set_loadout_selected(is_selected: bool) -> void:
	_uses_loadout_selection = true
	_is_loadout_selected = is_selected
	queue_redraw()


func is_loadout_selected() -> bool:
	return _uses_loadout_selection and _is_loadout_selected


## Disables hover/click capture for decorative empty spell placeholders.
func set_interaction_enabled(is_enabled: bool) -> void:
	_interaction_enabled = is_enabled
	_refresh_interaction_state()


func _on_mouse_entered() -> void:
	if not _interaction_enabled:
		return
	_is_hovered = true
	if _definition != null:
		ability_hint_requested.emit(_definition)


func _on_mouse_exited() -> void:
	if not _interaction_enabled:
		return
	_is_hovered = false
	if _definition != null:
		ability_hint_dismissed.emit(_definition)


func _on_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if (
		not _interaction_enabled
		or mouse_event == null
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
		or _definition == null
	):
		return

	ability_activation_requested.emit()
	accept_event()


func _build_labels() -> void:
	_key_label = Label.new()
	_key_label.name = "KeyLabel"
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_label.text = _key_hint
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_PRIMARY)
	_key_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_key_label.visible = _show_key_hint
	add_child(_key_label)

	_cooldown_label = Label.new()
	_cooldown_label.name = "CooldownLabel"
	_cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cooldown_label.add_theme_color_override("font_color", Color.WHITE)
	_cooldown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_cooldown_label)
	_layout_labels()


func _layout_labels() -> void:
	if _key_label == null or _cooldown_label == null:
		return

	var unit := minf(size.x, size.y)
	var origin := (size - Vector2(unit, unit)) * 0.5
	var key_font_size := clampi(roundi(unit * 0.19), 8, 15)
	var key_outline_size := 1 if unit < 56.0 else 2
	_key_label.add_theme_font_size_override("font_size", key_font_size)
	_key_label.add_theme_constant_override("outline_size", key_outline_size)
	# Keep the entire glyph box inside the icon. The previous 24% tall box was
	# shorter than the fixed font after the nine-zone HUD made slots responsive.
	_key_label.position = origin + Vector2(unit * 0.22, unit * 0.58)
	_key_label.size = Vector2(unit * 0.56, unit * 0.36)

	var cooldown_font_size := clampi(roundi(unit * 0.27), 10, 19)
	var cooldown_outline_size := 1 if unit < 48.0 else (2 if unit < 64.0 else 3)
	_cooldown_label.add_theme_font_size_override("font_size", cooldown_font_size)
	_cooldown_label.add_theme_constant_override("outline_size", cooldown_outline_size)
	_cooldown_label.position = origin + Vector2(unit * 0.10, unit * 0.14)
	_cooldown_label.size = Vector2(unit * 0.80, unit * 0.52)


func _refresh_labels() -> void:
	if _key_label == null or _cooldown_label == null:
		return

	_key_label.modulate = Color.WHITE if _definition != null else Color(0.55, 0.55, 0.55, 1.0)
	_key_label.visible = _show_key_hint
	_cooldown_label.visible = _definition != null and _remaining_seconds > 0.0
	if _cooldown_label.visible:
		_cooldown_label.text = str(ceili(_remaining_seconds))


func _refresh_interaction_state() -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if _interaction_enabled
		else Control.MOUSE_FILTER_IGNORE
	)
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if _interaction_enabled
		else Control.CURSOR_ARROW
	)


func _cooldown_fraction() -> float:
	if _definition == null or _total_seconds <= 0.0:
		return 0.0
	return clampf(_remaining_seconds / _total_seconds, 0.0, 1.0)


func _icon_background_color() -> Color:
	if _definition == null:
		return Color(0.09, 0.09, 0.085, 1.0)
	if String(_definition.get("icon_id")) == "moonleaf_binding":
		return Color(0.075, 0.20, 0.12, 1.0)
	if String(_definition.get("icon_id")) == "energizing_shield":
		return Color(0.055, 0.13, 0.18, 1.0)
	if String(_definition.get("icon_id")) == "whirling_slash":
		return Color(0.045, 0.15, 0.16, 1.0)
	return Color(0.24, 0.075, 0.055, 1.0)


func _draw_ability_icon(rect: Rect2) -> void:
	match String(_definition.get("icon_id")):
		"dodge_roll":
			_draw_dodge_roll_icon(rect)
		"moonleaf_binding":
			_draw_moonleaf_binding_icon(rect)
		"energizing_shield":
			_draw_energizing_shield_icon(rect)
		"whirling_slash":
			_draw_whirling_slash_icon(rect)
		_:
			_draw_sword_slash_icon(rect)


func _draw_energizing_shield_icon(rect: Rect2) -> void:
	var outline := Color(0.015, 0.022, 0.028, 1.0)
	var shield_dark := Color(0.10, 0.30, 0.42, 1.0)
	var shield_light := Color(0.35, 0.82, 1.0, 1.0)
	var energy := Color(0.92, 0.98, 1.0, 1.0)
	var center := rect.get_center()
	var shield := PackedVector2Array([
		rect.position + rect.size * Vector2(0.50, 0.10),
		rect.position + rect.size * Vector2(0.76, 0.24),
		rect.position + rect.size * Vector2(0.70, 0.62),
		rect.position + rect.size * Vector2(0.50, 0.86),
		rect.position + rect.size * Vector2(0.30, 0.62),
		rect.position + rect.size * Vector2(0.24, 0.24),
	])
	draw_colored_polygon(shield, outline)
	var inset := PackedVector2Array()
	for point in shield:
		inset.append(center + (point - center) * 0.84)
	draw_colored_polygon(inset, shield_dark)
	draw_line(
		rect.position + rect.size * Vector2(0.50, 0.18),
		rect.position + rect.size * Vector2(0.50, 0.76),
		shield_light,
		maxf(rect.size.x * 0.045, 1.0),
		true
	)
	draw_arc(
		center,
		rect.size.x * 0.33,
		-2.85,
		-0.25,
		28,
		shield_light,
		maxf(rect.size.x * 0.055, 1.0),
		true
	)
	draw_arc(
		center,
		rect.size.x * 0.25,
		0.45,
		2.65,
		24,
		Color(0.55, 0.92, 1.0, 0.72),
		maxf(rect.size.x * 0.045, 1.0),
		true
	)
	var bolt := PackedVector2Array([
		rect.position + rect.size * Vector2(0.54, 0.20),
		rect.position + rect.size * Vector2(0.42, 0.50),
		rect.position + rect.size * Vector2(0.53, 0.50),
		rect.position + rect.size * Vector2(0.45, 0.78),
		rect.position + rect.size * Vector2(0.64, 0.42),
		rect.position + rect.size * Vector2(0.52, 0.42),
	])
	draw_colored_polygon(bolt, outline)
	var bolt_inset := PackedVector2Array()
	for point in bolt:
		bolt_inset.append(center + (point - center) * 0.88)
	draw_colored_polygon(bolt_inset, energy)


func _draw_moonleaf_binding_icon(rect: Rect2) -> void:
	var outline := Color(0.025, 0.035, 0.025, 1.0)
	var leaf_dark := Color(0.18, 0.46, 0.24, 1.0)
	var leaf_light := Color(0.52, 0.84, 0.48, 1.0)
	var moonlight := Color(0.78, 0.93, 0.82, 1.0)
	var binding := Color(0.90, 0.82, 0.61, 1.0)
	var center := rect.get_center()
	var leaf := PackedVector2Array([
		rect.position + rect.size * Vector2(0.50, 0.10),
		rect.position + rect.size * Vector2(0.73, 0.30),
		rect.position + rect.size * Vector2(0.66, 0.58),
		rect.position + rect.size * Vector2(0.50, 0.76),
		rect.position + rect.size * Vector2(0.34, 0.58),
		rect.position + rect.size * Vector2(0.27, 0.30),
	])
	draw_colored_polygon(leaf, outline)
	var inset := PackedVector2Array()
	for point in leaf:
		inset.append(center + (point - center) * 0.86)
	draw_colored_polygon(inset, leaf_dark)
	draw_line(
		rect.position + rect.size * Vector2(0.50, 0.18),
		rect.position + rect.size * Vector2(0.50, 0.74),
		leaf_light,
		maxf(rect.size.x * 0.045, 1.0),
		true
	)
	draw_arc(
		rect.position + rect.size * Vector2(0.43, 0.29),
		rect.size.x * 0.16,
		-1.45,
		1.45,
		18,
		moonlight,
		maxf(rect.size.x * 0.055, 1.0),
		true
	)
	var bandage_center := rect.position + rect.size * Vector2(0.50, 0.62)
	var bandage_half_width := rect.size.x * 0.25
	for offset_index in range(-1, 2):
		var offset := float(offset_index) * rect.size.y * 0.105
		draw_line(
			bandage_center + Vector2(-bandage_half_width, offset),
			bandage_center + Vector2(bandage_half_width, offset),
			outline,
			maxf(rect.size.x * 0.105, 2.0),
			true
		)
		draw_line(
			bandage_center + Vector2(-bandage_half_width, offset),
			bandage_center + Vector2(bandage_half_width, offset),
			binding,
			maxf(rect.size.x * 0.065, 1.0),
			true
		)


func _draw_dodge_roll_icon(rect: Rect2) -> void:
	var dark := Color(0.07, 0.045, 0.025, 1.0)
	var leather := Color(0.55, 0.30, 0.12, 1.0)
	var highlight := Color(0.94, 0.76, 0.34, 1.0)
	var points := PackedVector2Array([
		rect.position + rect.size * Vector2(0.30, 0.16),
		rect.position + rect.size * Vector2(0.58, 0.16),
		rect.position + rect.size * Vector2(0.58, 0.54),
		rect.position + rect.size * Vector2(0.80, 0.65),
		rect.position + rect.size * Vector2(0.78, 0.80),
		rect.position + rect.size * Vector2(0.28, 0.80),
		rect.position + rect.size * Vector2(0.22, 0.66),
		rect.position + rect.size * Vector2(0.30, 0.56),
	])
	draw_colored_polygon(points, dark)
	var inset := PackedVector2Array()
	var center := rect.get_center()
	for point in points:
		inset.append(center + (point - center) * 0.84)
	draw_colored_polygon(inset, leather)
	draw_polyline(points, highlight, maxf(rect.size.x * 0.045, 1.0), true)
	draw_arc(
		rect.get_center(),
		rect.size.x * 0.40,
		-2.7,
		-0.15,
		24,
		Color(1.0, 0.78, 0.22, 0.72),
		maxf(rect.size.x * 0.055, 1.0),
		true
	)


func _draw_sword_slash_icon(rect: Rect2) -> void:
	var icon_color := Color(0.92, 0.88, 0.72, 1.0)
	var steel_shadow := Color(0.34, 0.37, 0.39, 1.0)
	var gold := Color(0.92, 0.66, 0.20, 1.0)
	var start := rect.position + rect.size * Vector2(0.26, 0.78)
	var finish := rect.position + rect.size * Vector2(0.76, 0.20)
	var blade_width := maxf(rect.size.x * 0.115, 2.0)

	draw_line(start, finish, Color(0.015, 0.015, 0.012, 1.0), blade_width * 1.55, true)
	draw_line(start, finish, steel_shadow, blade_width, true)
	draw_line(start + Vector2(1.0, -1.0), finish + Vector2(1.0, -1.0), icon_color, blade_width * 0.42, true)

	var direction := (finish - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var guard_center := start + direction * rect.size.x * 0.10
	draw_line(
		guard_center - perpendicular * rect.size.x * 0.15,
		guard_center + perpendicular * rect.size.x * 0.15,
		Color(0.02, 0.018, 0.014, 1.0),
		blade_width * 0.90,
		true
	)
	draw_line(
		guard_center - perpendicular * rect.size.x * 0.13,
		guard_center + perpendicular * rect.size.x * 0.13,
		gold,
		blade_width * 0.52,
		true
	)
	draw_circle(start - direction * rect.size.x * 0.05, blade_width * 0.42, gold)

	var slash_arc_center := rect.position + rect.size * Vector2(0.50, 0.50)
	draw_arc(
		slash_arc_center,
		rect.size.x * 0.38,
		-2.55,
		-0.35,
		24,
		Color(1.0, 0.73, 0.23, 0.50),
		maxf(rect.size.x * 0.055, 1.0),
		true
	)


func _draw_whirling_slash_icon(rect: Rect2) -> void:
	_draw_sword_slash_icon(rect)
	var center := rect.get_center()
	var swirl_color := Color(0.30, 0.92, 0.88, 0.82)
	var swirl_shadow := Color(0.015, 0.035, 0.04, 0.96)
	var radius := rect.size.x * 0.43
	var width := maxf(rect.size.x * 0.065, 1.0)
	draw_arc(center, radius, -2.8, 0.75, 30, swirl_shadow, width * 1.8, true)
	draw_arc(center, radius, -2.8, 0.75, 30, swirl_color, width, true)
	var arrow_tip := center + Vector2(cos(0.75), sin(0.75)) * radius
	var tangent := Vector2(-sin(0.75), cos(0.75))
	var inward := (center - arrow_tip).normalized()
	var arrow := PackedVector2Array([
		arrow_tip + tangent * rect.size.x * 0.02,
		arrow_tip - tangent * rect.size.x * 0.16 + inward * rect.size.x * 0.04,
		arrow_tip - tangent * rect.size.x * 0.03 + inward * rect.size.x * 0.15,
	])
	draw_colored_polygon(arrow, swirl_shadow)
	var arrow_inset := PackedVector2Array()
	for point in arrow:
		arrow_inset.append(arrow_tip + (point - arrow_tip) * 0.78)
	draw_colored_polygon(arrow_inset, swirl_color)


func _draw_radial_cooldown(rect: Rect2, fraction: float) -> void:
	var clamped_fraction := clampf(fraction, 0.0, 1.0)
	if clamped_fraction <= 0.0:
		return

	var center := rect.get_center()
	# Keep the radial shade inside the icon well. The previous diagonal-based
	# radius crossed the inner border and made the cooldown look unclipped.
	var radius := minf(rect.size.x, rect.size.y) * 0.5
	var segment_count := maxi(2, ceili(48.0 * clamped_fraction))
	var points := PackedVector2Array([center])
	var start_angle := -PI * 0.5
	for segment_index in range(segment_count + 1):
		var progress := float(segment_index) / float(segment_count)
		var angle := start_angle + TAU * clamped_fraction * progress
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(0.01, 0.012, 0.014, 0.78))
