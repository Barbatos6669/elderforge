## Placeholder creature artwork for the master menu detail view.
##
## This will be replaced by discovered-creature art or 3D previews later. The
## current drawing keeps the Creatures page layout useful while gameplay data is
## still being built.
class_name MasterMenuCreaturePortrait
extends Control

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")

@export var creature_id := "needlekin":
	set(value):
		creature_id = value
		queue_redraw()


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(230.0, 230.0)


func _draw() -> void:
	var portrait_size := minf(size.x, size.y)
	if portrait_size <= 0.0:
		return

	var origin := (size - Vector2(portrait_size, portrait_size)) * 0.5
	var center := origin + Vector2(portrait_size * 0.5, portrait_size * 0.54)
	draw_circle(center, portrait_size * 0.40, Color(0.10, 0.12, 0.10, 0.48))
	draw_circle(center, portrait_size * 0.32, Color(0.62, 0.86, 0.70, 0.10))

	var bark := Color(0.42, 0.25, 0.12, 1.0)
	var needles := Color(0.52, 0.74, 0.62, 1.0)
	var moon := Color(0.72, 0.90, 1.0, 0.86)
	var outline := Color(0.05, 0.035, 0.025, 0.88)

	var body := PackedVector2Array([
		origin + Vector2(portrait_size * 0.38, portrait_size * 0.34),
		origin + Vector2(portrait_size * 0.60, portrait_size * 0.31),
		origin + Vector2(portrait_size * 0.73, portrait_size * 0.52),
		origin + Vector2(portrait_size * 0.64, portrait_size * 0.78),
		origin + Vector2(portrait_size * 0.38, portrait_size * 0.80),
		origin + Vector2(portrait_size * 0.26, portrait_size * 0.56),
	])
	draw_colored_polygon(body, bark)
	draw_polyline(body, outline, portrait_size * 0.018, true)

	for index in range(9):
		var t := float(index) / 8.0
		var x := lerpf(0.24, 0.76, t)
		var y := 0.30 + sin(t * PI) * 0.13
		_draw_needle(origin + Vector2(portrait_size * x, portrait_size * y), portrait_size * 0.11, needles, outline)

	var head := origin + Vector2(portrait_size * 0.50, portrait_size * 0.26)
	draw_circle(head, portrait_size * 0.11, bark.lightened(0.12))
	draw_arc(head, portrait_size * 0.11, 0.0, TAU, 28, outline, portrait_size * 0.018)
	draw_circle(head + Vector2(-portrait_size * 0.035, -portrait_size * 0.01), portrait_size * 0.012, moon)
	draw_circle(head + Vector2(portrait_size * 0.035, -portrait_size * 0.01), portrait_size * 0.012, moon)

	for foot_x in [0.36, 0.48, 0.60]:
		draw_line(
			origin + Vector2(portrait_size * foot_x, portrait_size * 0.76),
			origin + Vector2(portrait_size * (foot_x - 0.04), portrait_size * 0.88),
			bark,
			portrait_size * 0.025
		)


func _draw_needle(point: Vector2, needle_size: float, fill: Color, outline: Color) -> void:
	var points := PackedVector2Array([
		point + Vector2(0.0, -needle_size),
		point + Vector2(needle_size * 0.42, needle_size * 0.20),
		point + Vector2(0.0, needle_size * 0.72),
		point + Vector2(-needle_size * 0.42, needle_size * 0.20),
	])
	draw_colored_polygon(points, fill)
	draw_polyline(points, outline, needle_size * 0.10, true)
