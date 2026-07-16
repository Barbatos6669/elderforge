## Rich hover hint shared by every weapon ability slot.
##
## WeaponAbilityHud owns and confines this panel to the middle-center HUD grid
## cell. The panel reads presentation metadata from WeaponAbilityDefinition;
## gameplay timing and damage remain authoritative in the combat component.
class_name AbilityTooltipPanel
extends PanelContainer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")

const TOOLTIP_WIDTH := 390.0
const TAG_COLORS := {
	"damage": Color(0.94, 0.28, 0.22, 1.0),
	"crowd control": Color(0.96, 0.72, 0.18, 1.0),
	"control": Color(0.96, 0.72, 0.18, 1.0),
	"mobility": Color(0.82, 0.86, 0.88, 1.0),
	"single target": Color(0.88, 0.76, 0.46, 1.0),
	"area": Color(0.92, 0.54, 0.22, 1.0),
	"healing": Color(0.36, 0.82, 0.42, 1.0),
	"recovery": Color(0.42, 0.78, 0.68, 1.0),
	"channel": Color(0.62, 0.82, 0.92, 1.0),
	"survival": Color(0.76, 0.86, 0.52, 1.0),
	"out of combat": Color(0.90, 0.66, 0.28, 1.0),
	"buff": Color(0.42, 0.78, 0.95, 1.0),
	"shield": Color(0.35, 0.76, 1.0, 1.0),
	"self": Color(0.70, 0.82, 0.92, 1.0),
	"utility": Color(0.78, 0.75, 0.95, 1.0),
	"debuff": Color(0.76, 0.44, 0.90, 1.0),
}

var _definition: Resource
var _title_label: Label
var _tag_container: HFlowContainer
var _description_label: RichTextLabel
var _effects_container: GridContainer
var _stats_grid: GridContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiStyle.ability_tooltip_style())
	_build_ui()
	_refresh_content()


## Supplies the data before Godot attaches this custom tooltip to its popup.
func set_ability(definition: Resource) -> void:
	_definition = definition
	if is_node_ready():
		_refresh_content()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)

	var content := VBoxContainer.new()
	content.name = "TooltipContent"
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)

	_title_label = Label.new()
	_title_label.name = "AbilityTitle"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.label_primary(_title_label, 18, 1)
	content.add_child(_title_label)

	_tag_container = HFlowContainer.new()
	_tag_container.name = "CategoryTags"
	_tag_container.add_theme_constant_override("h_separation", 5)
	_tag_container.add_theme_constant_override("v_separation", 3)
	content.add_child(_tag_container)

	content.add_child(_make_separator())

	_description_label = RichTextLabel.new()
	_description_label.name = "AbilityDescription"
	_description_label.bbcode_enabled = false
	_description_label.fit_content = true
	_description_label.scroll_active = false
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(0.0, 36.0)
	_description_label.add_theme_font_size_override("normal_font_size", 13)
	_description_label.add_theme_color_override("default_color", UiStyle.COLOR_TEXT_PRIMARY)
	content.add_child(_description_label)

	_effects_container = GridContainer.new()
	_effects_container.name = "AbilityEffects"
	_effects_container.columns = 2
	_effects_container.add_theme_constant_override("h_separation", 5)
	_effects_container.add_theme_constant_override("v_separation", 3)
	content.add_child(_effects_container)

	content.add_child(_make_separator())

	_stats_grid = GridContainer.new()
	_stats_grid.name = "CombatStats"
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 10)
	_stats_grid.add_theme_constant_override("v_separation", 2)
	content.add_child(_stats_grid)


func _refresh_content() -> void:
	if _title_label == null:
		return

	_clear_children(_tag_container)
	_clear_children(_effects_container)
	_clear_children(_stats_grid)
	if _definition == null:
		_title_label.text = "Unassigned Ability"
		_description_label.text = ""
		return

	_title_label.text = String(_definition.get("display_name"))
	_description_label.text = String(_definition.get("description"))

	var raw_tags: Variant = _definition.get("tooltip_tags")
	if raw_tags is PackedStringArray:
		for tag in raw_tags as PackedStringArray:
			_tag_container.add_child(_make_tag(String(tag)))

	var raw_effects: Variant = _definition.get("tooltip_effects")
	if raw_effects is Array:
		for effect_variant in raw_effects as Array:
			var effect := effect_variant as Resource
			if effect != null:
				_effects_container.add_child(_make_effect_row(effect))
	_effects_container.visible = _effects_container.get_child_count() > 0

	_add_stat_row("Energy Cost", _format_number(float(_definition.get("energy_cost"))))
	var execution_type := String(_definition.get("execution_type"))
	if execution_type == "regeneration":
		_add_stat_row(
			"Channel Time",
			_format_seconds(float(_definition.get("cast_duration_seconds")))
		)
		_add_stat_row("Target", "Self")
	elif execution_type == "shield":
		_add_stat_row("Cast Time", _format_seconds(float(_definition.get("cast_duration_seconds"))))
		_add_stat_row("Range", "0m")
	else:
		_add_stat_row("Cast Time", _format_seconds(float(_definition.get("cast_duration_seconds"))))
		_add_stat_row("Range", "%sm" % _format_number(float(_definition.get("attack_range"))))
	_add_stat_row("Cooldown", _format_seconds(float(_definition.get("cooldown_seconds"))))


func _make_tag(tag_text: String) -> Control:
	var accent := _semantic_color(tag_text)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiStyle.ability_tooltip_tag_style(accent))

	var label := Label.new()
	label.text = tag_text.to_upper()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", accent)
	panel.add_child(label)
	return panel


func _make_effect_row(effect: Resource) -> Control:
	var accent := _semantic_color(String(effect.get("tone")))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiStyle.ability_tooltip_effect_style(accent))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var label := Label.new()
	label.text = String(effect.get("label"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_MUTED)
	row.add_child(label)

	var value := Label.new()
	value.text = String(effect.get("value"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override("font_color", accent)
	row.add_child(value)
	return panel


func _add_stat_row(label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.text = "%s:" % label_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_MUTED)
	_stats_grid.add_child(label)

	var value := Label.new()
	value.name = "%sValue" % label_text.replace(" ", "")
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_font_size_override("font_size", 12)
	value.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_PRIMARY)
	_stats_grid.add_child(value)


func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	separator.add_theme_color_override("separator", Color(0.62, 0.48, 0.20, 0.55))
	return separator


func _semantic_color(semantic_name: String) -> Color:
	return TAG_COLORS.get(semantic_name.strip_edges().to_lower(), UiStyle.COLOR_GOLD) as Color


func _format_seconds(seconds: float) -> String:
	return "%ss" % _format_number(maxf(seconds, 0.0))


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	if is_equal_approx(value * 10.0, roundf(value * 10.0)):
		return ("%.1f" % value).trim_suffix("0").trim_suffix(".")
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
