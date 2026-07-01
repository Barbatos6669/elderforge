## Draws compact inventory item cards for bag slots.
##
## This is a visual placeholder layer for prototype items. Item ownership should
## eventually move into inventory data/resources, while this control only renders
## whatever item dictionary it receives.
class_name InventoryItemIcon
extends Control

const LogsTexture := preload("res://assets/ui/inventory/logs_icon.png")
const RocksTexture := preload("res://assets/ui/inventory/rocks_icon.png")
const OresTexture := preload("res://assets/ui/inventory/ores_icon.png")
const CottonTexture := preload("res://assets/ui/inventory/cotton_icon.png")
const HideTexture := preload("res://assets/ui/inventory/hide_icon.png")
const TIER_COLORS := {
	1: Color(0.72, 0.72, 0.72, 1.0),
	2: Color(0.72, 0.50, 0.30, 1.0),
	3: Color(0.20, 0.62, 0.25, 1.0),
	4: Color(0.20, 0.42, 0.82, 1.0),
	5: Color(0.78, 0.18, 0.16, 1.0),
	6: Color(0.92, 0.48, 0.14, 1.0),
	7: Color(0.95, 0.82, 0.18, 1.0),
	8: Color(0.94, 0.94, 0.9, 1.0),
}

var _item := {}
var _tier_label: Label
var _quantity_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_labels()
	_refresh_labels()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_labels()
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _item.is_empty():
		return

	_draw_card_frame()
	_draw_item_art()
	_draw_tier_badge()
	_draw_quantity_plate()


## Updates the rendered item dictionary.
func set_item(item_data: Dictionary) -> void:
	_item = item_data.duplicate(true)
	_refresh_labels()
	queue_redraw()


## Clears this icon when the slot is empty.
func clear_item() -> void:
	_item = {}
	_refresh_labels()
	queue_redraw()


func _build_labels() -> void:
	if _tier_label != null:
		return

	_tier_label = Label.new()
	_tier_label.name = "TierLabel"
	_tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tier_label.add_theme_font_size_override("font_size", 10)
	_tier_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36, 1.0))
	_tier_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_tier_label.add_theme_constant_override("outline_size", 2)
	add_child(_tier_label)

	_quantity_label = Label.new()
	_quantity_label.name = "QuantityLabel"
	_quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quantity_label.add_theme_font_size_override("font_size", 11)
	_quantity_label.add_theme_color_override("font_color", Color.WHITE)
	_quantity_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_quantity_label.add_theme_constant_override("outline_size", 2)
	add_child(_quantity_label)

	_layout_labels()


func _refresh_labels() -> void:
	if _tier_label == null or _quantity_label == null:
		return

	var has_item := not _item.is_empty()
	_tier_label.visible = has_item
	_quantity_label.visible = has_item
	if not has_item:
		return

	_tier_label.text = String(_item.get("tier_roman", ""))
	_quantity_label.text = _quantity_text(int(_item.get("quantity", 1)))
	_layout_labels()


func _layout_labels() -> void:
	if _tier_label == null or _quantity_label == null:
		return

	var unit := _unit_size()
	var origin := _origin()
	_tier_label.position = origin + Vector2(unit * 0.08, unit * 0.08)
	_tier_label.size = Vector2(unit * 0.38, unit * 0.24)

	_quantity_label.position = origin + Vector2(unit * 0.52, unit * 0.74)
	_quantity_label.size = Vector2(unit * 0.38, unit * 0.20)


func _draw_card_frame() -> void:
	var unit := _unit_size()
	var origin := _origin()
	var outer_rect := Rect2(origin + Vector2(unit * 0.02, unit * 0.02), Vector2(unit * 0.96, unit * 0.96))
	var inner_rect := Rect2(origin + Vector2(unit * 0.07, unit * 0.07), Vector2(unit * 0.86, unit * 0.86))
	var background_color := _icon_background_color()

	draw_rect(outer_rect, Color(0.04, 0.04, 0.035, 0.96))
	draw_rect(outer_rect, Color(0.64, 0.48, 0.26, 1.0), false, maxf(unit * 0.035, 1.0))
	draw_rect(inner_rect, background_color)
	draw_rect(inner_rect, background_color.darkened(0.34), false, maxf(unit * 0.032, 1.0))
	draw_rect(inner_rect, Color(0.94, 0.76, 0.36, 0.85), false, maxf(unit * 0.018, 1.0))


func _draw_item_art() -> void:
	var item_type := String(_item.get("icon", ""))
	match item_type:
		"logs":
			_draw_logs()
		"rocks":
			_draw_rocks()
		"ores":
			_draw_ores()
		"cotton":
			_draw_cotton()
		"hide":
			_draw_hide()
		_:
			_draw_generic_resource()


func _draw_logs() -> void:
	var unit := _unit_size()
	var art_rect := Rect2(_origin() + Vector2(unit * 0.08, unit * 0.12), Vector2(unit * 0.84, unit * 0.74))
	_draw_texture_fit(LogsTexture, art_rect)


func _draw_rocks() -> void:
	var unit := _unit_size()
	var art_rect := Rect2(_origin() + Vector2(unit * 0.04, unit * 0.10), Vector2(unit * 0.92, unit * 0.78))
	_draw_texture_fit(RocksTexture, art_rect)


func _draw_ores() -> void:
	var unit := _unit_size()
	var art_rect := Rect2(_origin() + Vector2(unit * 0.04, unit * 0.08), Vector2(unit * 0.92, unit * 0.82))
	_draw_texture_fit(OresTexture, art_rect)


func _draw_cotton() -> void:
	var unit := _unit_size()
	var art_rect := Rect2(_origin() + Vector2(unit * 0.06, unit * 0.08), Vector2(unit * 0.88, unit * 0.82))
	_draw_texture_fit(CottonTexture, art_rect)


func _draw_hide() -> void:
	var unit := _unit_size()
	var art_rect := Rect2(_origin() + Vector2(unit * 0.04, unit * 0.10), Vector2(unit * 0.92, unit * 0.78))
	_draw_texture_fit(HideTexture, art_rect)


func _draw_generic_resource() -> void:
	var unit := _unit_size()
	draw_circle(_origin() + Vector2(unit * 0.50, unit * 0.52), unit * 0.22, Color(0.46, 0.46, 0.42, 1.0))


func _draw_texture_fit(texture: Texture2D, target_rect: Rect2) -> void:
	if texture == null:
		return

	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var scale_factor := minf(target_rect.size.x / texture_size.x, target_rect.size.y / texture_size.y)
	var draw_size := texture_size * scale_factor
	var draw_position := target_rect.position + (target_rect.size - draw_size) * 0.5
	draw_texture_rect(texture, Rect2(draw_position, draw_size), false)


func _draw_tier_badge() -> void:
	var unit := _unit_size()
	var badge_rect := Rect2(_origin() + Vector2(unit * 0.07, unit * 0.07), Vector2(unit * 0.42, unit * 0.28))
	draw_rect(badge_rect, Color(0.025, 0.022, 0.018, 0.82))
	draw_rect(badge_rect, Color(0.93, 0.75, 0.28, 0.95), false, maxf(unit * 0.02, 1.0))


func _draw_quantity_plate() -> void:
	var unit := _unit_size()
	var plate := Rect2(_origin() + Vector2(unit * 0.50, unit * 0.76), Vector2(unit * 0.43, unit * 0.19))
	draw_rect(plate, Color(0.02, 0.02, 0.02, 0.76))
	draw_rect(plate, Color(0.86, 0.70, 0.35, 0.8), false, maxf(unit * 0.012, 1.0))


func _tier_color(tier: int) -> Color:
	return TIER_COLORS.get(clampi(tier, 1, 8), TIER_COLORS[1])


func _icon_background_color() -> Color:
	var tier := int(_item.get("tier", 1))
	var item_color: Color = _item.get("color", _tier_color(tier))
	return Color(item_color.r, item_color.g, item_color.b, 1.0)


func _quantity_text(quantity: int) -> String:
	return str(clampi(quantity, 0, 999))


func _origin() -> Vector2:
	var unit := _unit_size()
	return (size - Vector2(unit, unit)) * 0.5


func _unit_size() -> float:
	return minf(size.x, size.y)
