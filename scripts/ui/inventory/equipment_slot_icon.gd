## Draws simple placeholder icons for empty equipment slots.
##
## These are UI placeholders, not final item art. Keeping them code-drawn lets
## empty slots stay crisp at different sizes without carrying temporary bitmaps.
class_name EquipmentSlotIcon
extends Control

## Equipment slot id used to choose which placeholder silhouette to draw.
@export var icon_id := "head":
	set(value):
		icon_id = value
		queue_redraw()

## Main silhouette color.
@export var icon_color := Color(0.46, 0.46, 0.46, 0.9):
	set(value):
		icon_color = value
		queue_redraw()

## Dark detail color used for vents and subtle internal cuts.
@export var detail_color := Color(0.12, 0.13, 0.12, 0.55):
	set(value):
		detail_color = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	match icon_id:
		"bag":
			_draw_bag()
		"head":
			_draw_helmet()
		"cape":
			_draw_cape()
		"main_hand":
			_draw_sword()
		"chest":
			_draw_chest()
		"off_hand":
			_draw_shield()
		"potion":
			_draw_potion()
		"shoes":
			_draw_shoes()
		"food":
			_draw_food()
		_:
			_draw_generic_slot()


## Updates the slot id from the parent equipment panel.
func set_icon_id(new_icon_id: String) -> void:
	icon_id = new_icon_id


func _draw_bag() -> void:
	_draw_line_norm(Vector2(0.36, 0.24), Vector2(0.36, 0.15), icon_color, 0.06)
	_draw_line_norm(Vector2(0.64, 0.24), Vector2(0.64, 0.15), icon_color, 0.06)
	_draw_line_norm(Vector2(0.36, 0.15), Vector2(0.64, 0.15), icon_color, 0.06)
	_draw_shape([
		Vector2(0.22, 0.28),
		Vector2(0.78, 0.28),
		Vector2(0.85, 0.86),
		Vector2(0.15, 0.86),
	], icon_color)
	_draw_shape([
		Vector2(0.25, 0.31),
		Vector2(0.75, 0.31),
		Vector2(0.66, 0.50),
		Vector2(0.34, 0.50),
	], detail_color)
	_draw_rect_norm(Vector2(0.36, 0.58), Vector2(0.28, 0.20), detail_color)
	_draw_line_norm(Vector2(0.26, 0.54), Vector2(0.26, 0.78), detail_color, 0.035)
	_draw_line_norm(Vector2(0.74, 0.54), Vector2(0.74, 0.78), detail_color, 0.035)


func _draw_helmet() -> void:
	_draw_shape([
		Vector2(0.18, 0.48),
		Vector2(0.23, 0.28),
		Vector2(0.36, 0.15),
		Vector2(0.50, 0.10),
		Vector2(0.64, 0.15),
		Vector2(0.77, 0.28),
		Vector2(0.82, 0.48),
		Vector2(0.70, 0.54),
		Vector2(0.50, 0.61),
		Vector2(0.30, 0.54),
	], icon_color)
	_draw_shape([
		Vector2(0.45, 0.14),
		Vector2(0.50, 0.02),
		Vector2(0.55, 0.14),
		Vector2(0.54, 0.28),
		Vector2(0.46, 0.28),
	], icon_color)
	_draw_shape([
		Vector2(0.18, 0.52),
		Vector2(0.48, 0.61),
		Vector2(0.48, 0.72),
		Vector2(0.37, 0.68),
		Vector2(0.26, 0.73),
		Vector2(0.18, 0.62),
	], icon_color)
	_draw_shape([
		Vector2(0.82, 0.52),
		Vector2(0.52, 0.61),
		Vector2(0.52, 0.72),
		Vector2(0.63, 0.68),
		Vector2(0.74, 0.73),
		Vector2(0.82, 0.62),
	], icon_color)
	_draw_shape([
		Vector2(0.22, 0.66),
		Vector2(0.37, 0.74),
		Vector2(0.46, 0.80),
		Vector2(0.48, 0.94),
		Vector2(0.28, 0.82),
		Vector2(0.16, 0.70),
	], icon_color)
	_draw_shape([
		Vector2(0.78, 0.66),
		Vector2(0.63, 0.74),
		Vector2(0.54, 0.80),
		Vector2(0.52, 0.94),
		Vector2(0.72, 0.82),
		Vector2(0.84, 0.70),
	], icon_color)
	_draw_shape([
		Vector2(0.46, 0.60),
		Vector2(0.54, 0.60),
		Vector2(0.51, 0.96),
		Vector2(0.49, 0.96),
	], icon_color)

	_draw_vent(0.30, 0.77, 0.86)
	_draw_vent(0.39, 0.80, 0.91)
	_draw_vent(0.70, 0.77, 0.86)
	_draw_vent(0.61, 0.80, 0.91)


func _draw_cape() -> void:
	_draw_shape([
		Vector2(0.34, 0.16),
		Vector2(0.66, 0.16),
		Vector2(0.78, 0.90),
		Vector2(0.50, 0.78),
		Vector2(0.22, 0.90),
	], icon_color)
	_draw_shape([
		Vector2(0.36, 0.16),
		Vector2(0.50, 0.08),
		Vector2(0.64, 0.16),
		Vector2(0.50, 0.28),
	], detail_color)
	_draw_line_norm(Vector2(0.50, 0.28), Vector2(0.50, 0.78), detail_color, 0.035)
	_draw_line_norm(Vector2(0.38, 0.30), Vector2(0.30, 0.82), detail_color, 0.025)
	_draw_line_norm(Vector2(0.62, 0.30), Vector2(0.70, 0.82), detail_color, 0.025)


func _draw_sword() -> void:
	_draw_shape([
		Vector2(0.50, 0.05),
		Vector2(0.59, 0.20),
		Vector2(0.55, 0.62),
		Vector2(0.50, 0.70),
		Vector2(0.45, 0.62),
		Vector2(0.41, 0.20),
	], icon_color)
	_draw_line_norm(Vector2(0.50, 0.18), Vector2(0.50, 0.63), detail_color, 0.025)
	_draw_shape([
		Vector2(0.20, 0.65),
		Vector2(0.45, 0.60),
		Vector2(0.49, 0.68),
		Vector2(0.24, 0.76),
	], icon_color)
	_draw_shape([
		Vector2(0.80, 0.65),
		Vector2(0.55, 0.60),
		Vector2(0.51, 0.68),
		Vector2(0.76, 0.76),
	], icon_color)
	_draw_rect_norm(Vector2(0.46, 0.70), Vector2(0.08, 0.20), icon_color)
	_draw_circle_norm(Vector2(0.50, 0.94), 0.065, icon_color)


func _draw_chest() -> void:
	_draw_shape([
		Vector2(0.28, 0.22),
		Vector2(0.40, 0.12),
		Vector2(0.50, 0.25),
		Vector2(0.60, 0.12),
		Vector2(0.72, 0.22),
		Vector2(0.82, 0.46),
		Vector2(0.70, 0.56),
		Vector2(0.68, 0.88),
		Vector2(0.32, 0.88),
		Vector2(0.30, 0.56),
		Vector2(0.18, 0.46),
	], icon_color)
	_draw_shape([
		Vector2(0.40, 0.15),
		Vector2(0.50, 0.30),
		Vector2(0.60, 0.15),
		Vector2(0.58, 0.36),
		Vector2(0.50, 0.42),
		Vector2(0.42, 0.36),
	], detail_color)
	_draw_line_norm(Vector2(0.50, 0.43), Vector2(0.50, 0.86), detail_color, 0.03)
	_draw_line_norm(Vector2(0.34, 0.56), Vector2(0.66, 0.56), detail_color, 0.03)


func _draw_shield() -> void:
	_draw_shape([
		Vector2(0.50, 0.08),
		Vector2(0.78, 0.20),
		Vector2(0.74, 0.62),
		Vector2(0.50, 0.92),
		Vector2(0.26, 0.62),
		Vector2(0.22, 0.20),
	], icon_color)
	_draw_shape([
		Vector2(0.50, 0.18),
		Vector2(0.68, 0.27),
		Vector2(0.65, 0.58),
		Vector2(0.50, 0.78),
	], detail_color)
	_draw_line_norm(Vector2(0.50, 0.14), Vector2(0.50, 0.84), detail_color, 0.025)


func _draw_potion() -> void:
	_draw_rect_norm(Vector2(0.42, 0.10), Vector2(0.16, 0.13), icon_color)
	_draw_rect_norm(Vector2(0.38, 0.22), Vector2(0.24, 0.10), icon_color)
	_draw_shape([
		Vector2(0.38, 0.32),
		Vector2(0.62, 0.32),
		Vector2(0.76, 0.74),
		Vector2(0.66, 0.90),
		Vector2(0.34, 0.90),
		Vector2(0.24, 0.74),
	], icon_color)
	_draw_shape([
		Vector2(0.32, 0.64),
		Vector2(0.68, 0.58),
		Vector2(0.68, 0.80),
		Vector2(0.60, 0.86),
		Vector2(0.38, 0.86),
		Vector2(0.31, 0.78),
	], detail_color)
	_draw_circle_norm(Vector2(0.58, 0.44), 0.04, detail_color)


func _draw_shoes() -> void:
	_draw_shape([
		Vector2(0.22, 0.18),
		Vector2(0.43, 0.18),
		Vector2(0.42, 0.56),
		Vector2(0.51, 0.68),
		Vector2(0.48, 0.80),
		Vector2(0.20, 0.80),
		Vector2(0.16, 0.70),
		Vector2(0.24, 0.60),
	], icon_color)
	_draw_shape([
		Vector2(0.57, 0.18),
		Vector2(0.78, 0.18),
		Vector2(0.76, 0.60),
		Vector2(0.84, 0.70),
		Vector2(0.80, 0.80),
		Vector2(0.52, 0.80),
		Vector2(0.49, 0.68),
		Vector2(0.58, 0.56),
	], icon_color)
	_draw_rect_norm(Vector2(0.20, 0.20), Vector2(0.25, 0.08), detail_color)
	_draw_rect_norm(Vector2(0.55, 0.20), Vector2(0.25, 0.08), detail_color)
	_draw_line_norm(Vector2(0.20, 0.80), Vector2(0.48, 0.80), detail_color, 0.04)
	_draw_line_norm(Vector2(0.52, 0.80), Vector2(0.80, 0.80), detail_color, 0.04)
	_draw_line_norm(Vector2(0.31, 0.34), Vector2(0.31, 0.58), detail_color, 0.025)
	_draw_line_norm(Vector2(0.69, 0.34), Vector2(0.69, 0.58), detail_color, 0.025)


func _draw_food() -> void:
	_draw_circle_norm(Vector2(0.42, 0.54), 0.22, icon_color)
	_draw_circle_norm(Vector2(0.58, 0.54), 0.22, icon_color)
	_draw_shape([
		Vector2(0.34, 0.58),
		Vector2(0.66, 0.58),
		Vector2(0.58, 0.88),
		Vector2(0.50, 0.94),
		Vector2(0.42, 0.88),
	], icon_color)
	_draw_line_norm(Vector2(0.50, 0.24), Vector2(0.50, 0.36), icon_color, 0.05)
	_draw_shape([
		Vector2(0.52, 0.25),
		Vector2(0.72, 0.20),
		Vector2(0.64, 0.35),
	], icon_color)
	_draw_circle_norm(Vector2(0.44, 0.52), 0.045, detail_color)


func _draw_generic_slot() -> void:
	_draw_rect_norm(Vector2(0.24, 0.24), Vector2(0.52, 0.52), icon_color)
	_draw_line_norm(Vector2(0.32, 0.50), Vector2(0.68, 0.50), detail_color, 0.04)
	_draw_line_norm(Vector2(0.50, 0.32), Vector2(0.50, 0.68), detail_color, 0.04)


func _draw_shape(points: Array, color: Color) -> void:
	var scaled_points := PackedVector2Array()
	for point in points:
		scaled_points.append(_scaled_point(point))

	draw_colored_polygon(scaled_points, color)


func _draw_vent(x: float, top_y: float, bottom_y: float) -> void:
	draw_line(_scaled_point(Vector2(x, top_y)), _scaled_point(Vector2(x, bottom_y)), detail_color, _unit_size() * 0.055)


func _draw_line_norm(from: Vector2, to: Vector2, color: Color, width_scale: float) -> void:
	draw_line(_scaled_point(from), _scaled_point(to), color, _unit_size() * width_scale)


func _draw_rect_norm(position: Vector2, rect_size: Vector2, color: Color) -> void:
	var unit := _unit_size()
	var rect := Rect2(_scaled_point(position), rect_size * unit)
	draw_rect(rect, color)


func _draw_circle_norm(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(_scaled_point(center), _unit_size() * radius, color)


func _scaled_point(point: Vector2) -> Vector2:
	var unit := _unit_size()
	var origin := (size - Vector2(unit, unit)) * 0.5
	return origin + point * unit


func _unit_size() -> float:
	return minf(size.x, size.y)
