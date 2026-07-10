## Code-drawn placeholder icons for the fullscreen master menu tiles.
##
## Final art can replace this with textures later. For now these keep the menu
## readable and let us tune spacing around real icon-sized content.
class_name MasterMenuTileIcon
extends Control

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")

@export var icon_id := "glossary":
	set(value):
		icon_id = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(48.0, 48.0)


func _draw() -> void:
	var icon_size := minf(size.x, size.y)
	if icon_size <= 0.0:
		return

	var origin := (size - Vector2(icon_size, icon_size)) * 0.5
	match icon_id:
		"alchemy":
			_draw_alchemy(origin, icon_size)
		"inventory":
			_draw_inventory(origin, icon_size)
		"world_map":
			_draw_world_map(origin, icon_size)
		"quests":
			_draw_quests(origin, icon_size)
		"character":
			_draw_character(origin, icon_size)
		_:
			_draw_glossary(origin, icon_size)


func _draw_glossary(origin: Vector2, icon_size: float) -> void:
	var page_color := UiStyle.COLOR_TEXT_PRIMARY
	var shadow := Color(0.12, 0.08, 0.035, 0.85)
	var left := Rect2(origin + Vector2(icon_size * 0.16, icon_size * 0.20), Vector2(icon_size * 0.31, icon_size * 0.58))
	var right := Rect2(origin + Vector2(icon_size * 0.53, icon_size * 0.20), Vector2(icon_size * 0.31, icon_size * 0.58))
	draw_rect(left, shadow, true)
	draw_rect(right, shadow, true)
	draw_rect(left.grow(-icon_size * 0.035), page_color, true)
	draw_rect(right.grow(-icon_size * 0.035), page_color, true)
	draw_line(origin + Vector2(icon_size * 0.50, icon_size * 0.22), origin + Vector2(icon_size * 0.50, icon_size * 0.79), UiStyle.COLOR_GOLD, icon_size * 0.04)
	for row in range(3):
		var y := origin.y + icon_size * (0.34 + float(row) * 0.12)
		draw_line(Vector2(origin.x + icon_size * 0.22, y), Vector2(origin.x + icon_size * 0.41, y), shadow, icon_size * 0.025)
		draw_line(Vector2(origin.x + icon_size * 0.59, y), Vector2(origin.x + icon_size * 0.78, y), shadow, icon_size * 0.025)


func _draw_alchemy(origin: Vector2, icon_size: float) -> void:
	var liquid := Color(0.28, 0.95, 0.68, 1.0)
	var glass := Color(0.82, 0.95, 1.0, 0.78)
	var outline := UiStyle.COLOR_GOLD
	var neck := Rect2(origin + Vector2(icon_size * 0.42, icon_size * 0.16), Vector2(icon_size * 0.16, icon_size * 0.25))
	draw_rect(neck, glass, true)
	draw_rect(neck, outline, false, icon_size * 0.035)
	draw_circle(origin + Vector2(icon_size * 0.50, icon_size * 0.62), icon_size * 0.27, glass)
	draw_circle(origin + Vector2(icon_size * 0.50, icon_size * 0.68), icon_size * 0.20, liquid)
	draw_arc(origin + Vector2(icon_size * 0.50, icon_size * 0.62), icon_size * 0.28, 0.0, TAU, 32, outline, icon_size * 0.035)
	draw_circle(origin + Vector2(icon_size * 0.40, icon_size * 0.68), icon_size * 0.035, Color.WHITE)
	draw_circle(origin + Vector2(icon_size * 0.58, icon_size * 0.59), icon_size * 0.025, Color.WHITE)


func _draw_inventory(origin: Vector2, icon_size: float) -> void:
	var leather := Color(0.58, 0.34, 0.14, 1.0)
	var edge := UiStyle.COLOR_GOLD
	var bag := Rect2(origin + Vector2(icon_size * 0.20, icon_size * 0.38), Vector2(icon_size * 0.60, icon_size * 0.43))
	draw_rect(bag, leather, true)
	draw_rect(bag, edge, false, icon_size * 0.04)
	draw_arc(origin + Vector2(icon_size * 0.50, icon_size * 0.40), icon_size * 0.20, PI, TAU, 20, edge, icon_size * 0.07)
	draw_rect(Rect2(origin + Vector2(icon_size * 0.30, icon_size * 0.48), Vector2(icon_size * 0.40, icon_size * 0.08)), UiStyle.COLOR_TEXT_PRIMARY, true)
	draw_circle(origin + Vector2(icon_size * 0.50, icon_size * 0.64), icon_size * 0.06, edge)


func _draw_world_map(origin: Vector2, icon_size: float) -> void:
	var paper := UiStyle.COLOR_TEXT_PRIMARY
	var line := Color(0.18, 0.13, 0.07, 0.88)
	var points := PackedVector2Array([
		origin + Vector2(icon_size * 0.16, icon_size * 0.28),
		origin + Vector2(icon_size * 0.36, icon_size * 0.20),
		origin + Vector2(icon_size * 0.58, icon_size * 0.28),
		origin + Vector2(icon_size * 0.84, icon_size * 0.20),
		origin + Vector2(icon_size * 0.84, icon_size * 0.72),
		origin + Vector2(icon_size * 0.62, icon_size * 0.80),
		origin + Vector2(icon_size * 0.38, icon_size * 0.72),
		origin + Vector2(icon_size * 0.16, icon_size * 0.80),
	])
	draw_colored_polygon(points, paper)
	draw_polyline(points, UiStyle.COLOR_GOLD, icon_size * 0.035, true)
	draw_line(origin + Vector2(icon_size * 0.36, icon_size * 0.22), origin + Vector2(icon_size * 0.38, icon_size * 0.72), line, icon_size * 0.025)
	draw_line(origin + Vector2(icon_size * 0.58, icon_size * 0.30), origin + Vector2(icon_size * 0.62, icon_size * 0.78), line, icon_size * 0.025)
	draw_circle(origin + Vector2(icon_size * 0.58, icon_size * 0.48), icon_size * 0.055, Color(0.22, 0.55, 0.92, 1.0))


func _draw_quests(origin: Vector2, icon_size: float) -> void:
	var scroll := Rect2(origin + Vector2(icon_size * 0.25, icon_size * 0.18), Vector2(icon_size * 0.50, icon_size * 0.64))
	draw_rect(scroll, UiStyle.COLOR_TEXT_PRIMARY, true)
	draw_rect(scroll, UiStyle.COLOR_GOLD, false, icon_size * 0.04)
	for row in range(3):
		var y := origin.y + icon_size * (0.36 + float(row) * 0.13)
		draw_line(Vector2(origin.x + icon_size * 0.36, y), Vector2(origin.x + icon_size * 0.66, y), Color(0.20, 0.12, 0.05, 0.86), icon_size * 0.03)
	draw_circle(origin + Vector2(icon_size * 0.25, icon_size * 0.24), icon_size * 0.09, UiStyle.COLOR_GOLD)
	draw_circle(origin + Vector2(icon_size * 0.75, icon_size * 0.76), icon_size * 0.09, UiStyle.COLOR_GOLD)


func _draw_character(origin: Vector2, icon_size: float) -> void:
	var body := UiStyle.COLOR_TEXT_PRIMARY
	draw_circle(origin + Vector2(icon_size * 0.50, icon_size * 0.28), icon_size * 0.14, body)
	draw_line(origin + Vector2(icon_size * 0.50, icon_size * 0.42), origin + Vector2(icon_size * 0.50, icon_size * 0.68), body, icon_size * 0.11)
	draw_line(origin + Vector2(icon_size * 0.27, icon_size * 0.50), origin + Vector2(icon_size * 0.73, icon_size * 0.50), body, icon_size * 0.08)
	draw_line(origin + Vector2(icon_size * 0.50, icon_size * 0.66), origin + Vector2(icon_size * 0.34, icon_size * 0.84), body, icon_size * 0.08)
	draw_line(origin + Vector2(icon_size * 0.50, icon_size * 0.66), origin + Vector2(icon_size * 0.66, icon_size * 0.84), body, icon_size * 0.08)
	draw_arc(origin + Vector2(icon_size * 0.50, icon_size * 0.53), icon_size * 0.35, -PI * 0.15, PI * 1.15, 28, UiStyle.COLOR_GOLD, icon_size * 0.035)
