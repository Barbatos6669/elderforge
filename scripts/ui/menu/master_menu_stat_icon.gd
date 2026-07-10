## Small code-drawn stat icons used by the master menu header.
##
## These are placeholders for eventual painted icon art. Keeping them as a
## separate Control lets the header layout stay stable when real icons arrive.
class_name MasterMenuStatIcon
extends Control

enum IconKind {
	BAG,
	WEIGHT,
	SILVER,
}

@export var icon_kind := IconKind.BAG:
	set(value):
		icon_kind = value
		queue_redraw()

@export var icon_color := Color(0.96, 0.90, 0.76, 1.0):
	set(value):
		icon_color = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(24.0, 24.0)


func _draw() -> void:
	var icon_size := minf(size.x, size.y)
	if icon_size <= 0.0:
		return

	var offset := (size - Vector2(icon_size, icon_size)) * 0.5
	match icon_kind:
		IconKind.SILVER:
			_draw_coin(offset, icon_size)
		IconKind.WEIGHT:
			_draw_weight(offset, icon_size)
		_:
			_draw_bag(offset, icon_size)


func _draw_bag(offset: Vector2, icon_size: float) -> void:
	var center := offset + Vector2(icon_size * 0.5, icon_size * 0.5)
	draw_circle(center, icon_size * 0.47, Color(0.95, 0.78, 0.30, 0.20))

	var body := Rect2(
		offset + Vector2(icon_size * 0.22, icon_size * 0.40),
		Vector2(icon_size * 0.56, icon_size * 0.42)
	)
	draw_rect(body, icon_color, true)

	var neck := Rect2(
		offset + Vector2(icon_size * 0.38, icon_size * 0.28),
		Vector2(icon_size * 0.24, icon_size * 0.18)
	)
	draw_rect(neck, icon_color, true)

	var handle_center := offset + Vector2(icon_size * 0.5, icon_size * 0.32)
	draw_arc(handle_center, icon_size * 0.18, PI, TAU, 16, icon_color, icon_size * 0.10)


func _draw_coin(offset: Vector2, icon_size: float) -> void:
	var center := offset + Vector2(icon_size * 0.5, icon_size * 0.5)
	draw_circle(center, icon_size * 0.48, Color(0.95, 0.78, 0.30, 0.22))
	draw_circle(center, icon_size * 0.35, icon_color)
	draw_arc(center, icon_size * 0.24, -PI * 0.65, PI * 0.65, 24, Color(0.38, 0.24, 0.05, 0.80), icon_size * 0.08)
	draw_circle(offset + Vector2(icon_size * 0.38, icon_size * 0.32), icon_size * 0.07, Color.WHITE)


func _draw_weight(offset: Vector2, icon_size: float) -> void:
	var center := offset + Vector2(icon_size * 0.5, icon_size * 0.5)
	draw_circle(center, icon_size * 0.47, Color(0.95, 0.78, 0.30, 0.18))

	var handle_center := offset + Vector2(icon_size * 0.5, icon_size * 0.38)
	draw_arc(handle_center, icon_size * 0.19, PI, TAU, 16, icon_color, icon_size * 0.10)

	var body_points := PackedVector2Array([
		offset + Vector2(icon_size * 0.24, icon_size * 0.42),
		offset + Vector2(icon_size * 0.76, icon_size * 0.42),
		offset + Vector2(icon_size * 0.85, icon_size * 0.82),
		offset + Vector2(icon_size * 0.15, icon_size * 0.82),
	])
	draw_colored_polygon(body_points, icon_color)
	draw_line(offset + Vector2(icon_size * 0.30, icon_size * 0.60), offset + Vector2(icon_size * 0.70, icon_size * 0.60), Color(0.38, 0.24, 0.05, 0.65), icon_size * 0.06)
