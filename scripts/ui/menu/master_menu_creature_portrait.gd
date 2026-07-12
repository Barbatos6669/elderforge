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

	match creature_id:
		"hollowfield_rat":
			_draw_rat(origin, portrait_size)
		"hearthvale_hare":
			_draw_hare(origin, portrait_size)
		"vale_deer":
			_draw_deer(origin, portrait_size)
		"ashback_boar":
			_draw_boar(origin, portrait_size)
		"lantern_moth":
			_draw_moth(origin, portrait_size)
		"claybank_toad":
			_draw_toad(origin, portrait_size)
		"mineweb_spider":
			_draw_spider(origin, portrait_size)
		"duskfeather_crow":
			_draw_crow(origin, portrait_size)
		"corrupted_wolf":
			_draw_wolf(origin, portrait_size)
		"blackroot_stag":
			_draw_stag(origin, portrait_size)
		_:
			_draw_needlekin(origin, portrait_size)


func _draw_needlekin(origin: Vector2, portrait_size: float) -> void:
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


func _draw_rat(origin: Vector2, portrait_size: float) -> void:
	var fur := Color(0.34, 0.30, 0.25, 1.0)
	var belly := Color(0.55, 0.49, 0.42, 1.0)
	var outline := Color(0.05, 0.04, 0.035, 0.9)
	_draw_ellipse(origin + Vector2(portrait_size * 0.50, portrait_size * 0.58), Vector2(portrait_size * 0.26, portrait_size * 0.14), fur, outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.65, portrait_size * 0.50), Vector2(portrait_size * 0.13, portrait_size * 0.10), fur.lightened(0.08), outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.55, portrait_size * 0.61), Vector2(portrait_size * 0.15, portrait_size * 0.07), belly, outline)
	draw_arc(origin + Vector2(portrait_size * 0.27, portrait_size * 0.62), portrait_size * 0.20, PI * 0.15, PI * 1.1, 18, Color(0.58, 0.36, 0.32), portrait_size * 0.025)
	draw_circle(origin + Vector2(portrait_size * 0.69, portrait_size * 0.47), portrait_size * 0.035, fur.lightened(0.16))
	draw_circle(origin + Vector2(portrait_size * 0.70, portrait_size * 0.50), portrait_size * 0.010, Color(0.02, 0.02, 0.02))


func _draw_hare(origin: Vector2, portrait_size: float) -> void:
	var fur := Color(0.55, 0.36, 0.20, 1.0)
	var cream := Color(0.82, 0.70, 0.52, 1.0)
	var outline := Color(0.07, 0.045, 0.025, 0.9)
	draw_line(origin + Vector2(portrait_size * 0.58, portrait_size * 0.40), origin + Vector2(portrait_size * 0.64, portrait_size * 0.16), fur, portrait_size * 0.055)
	draw_line(origin + Vector2(portrait_size * 0.66, portrait_size * 0.42), origin + Vector2(portrait_size * 0.78, portrait_size * 0.19), fur, portrait_size * 0.055)
	_draw_ellipse(origin + Vector2(portrait_size * 0.48, portrait_size * 0.62), Vector2(portrait_size * 0.24, portrait_size * 0.15), fur, outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.65, portrait_size * 0.46), Vector2(portrait_size * 0.13, portrait_size * 0.11), fur.lightened(0.10), outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.50, portrait_size * 0.65), Vector2(portrait_size * 0.12, portrait_size * 0.06), cream, outline)
	draw_circle(origin + Vector2(portrait_size * 0.68, portrait_size * 0.44), portrait_size * 0.010, Color.BLACK)
	draw_circle(origin + Vector2(portrait_size * 0.28, portrait_size * 0.56), portrait_size * 0.040, cream)


func _draw_deer(origin: Vector2, portrait_size: float) -> void:
	var fur := Color(0.48, 0.30, 0.16, 1.0)
	var throat := Color(0.82, 0.70, 0.52, 1.0)
	var outline := Color(0.06, 0.04, 0.025, 0.9)
	_draw_ellipse(origin + Vector2(portrait_size * 0.47, portrait_size * 0.63), Vector2(portrait_size * 0.25, portrait_size * 0.14), fur, outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.65, portrait_size * 0.43), Vector2(portrait_size * 0.12, portrait_size * 0.10), fur.lightened(0.08), outline)
	draw_line(origin + Vector2(portrait_size * 0.59, portrait_size * 0.51), origin + Vector2(portrait_size * 0.51, portrait_size * 0.60), fur, portrait_size * 0.065)
	draw_line(origin + Vector2(portrait_size * 0.63, portrait_size * 0.35), origin + Vector2(portrait_size * 0.58, portrait_size * 0.18), throat, portrait_size * 0.018)
	draw_line(origin + Vector2(portrait_size * 0.70, portrait_size * 0.35), origin + Vector2(portrait_size * 0.78, portrait_size * 0.20), throat, portrait_size * 0.018)
	draw_line(origin + Vector2(portrait_size * 0.58, portrait_size * 0.18), origin + Vector2(portrait_size * 0.52, portrait_size * 0.14), throat, portrait_size * 0.014)
	draw_line(origin + Vector2(portrait_size * 0.78, portrait_size * 0.20), origin + Vector2(portrait_size * 0.84, portrait_size * 0.16), throat, portrait_size * 0.014)
	draw_circle(origin + Vector2(portrait_size * 0.68, portrait_size * 0.42), portrait_size * 0.010, Color.BLACK)
	for foot_x in [0.35, 0.48, 0.58]:
		draw_line(origin + Vector2(portrait_size * foot_x, portrait_size * 0.73), origin + Vector2(portrait_size * (foot_x - 0.02), portrait_size * 0.86), fur, portrait_size * 0.025)


func _draw_boar(origin: Vector2, portrait_size: float) -> void:
	var fur := Color(0.36, 0.22, 0.16, 1.0)
	var ash := Color(0.14, 0.14, 0.13, 1.0)
	var tusk := Color(0.88, 0.78, 0.58, 1.0)
	var outline := Color(0.05, 0.035, 0.025, 0.9)
	_draw_ellipse(origin + Vector2(portrait_size * 0.47, portrait_size * 0.60), Vector2(portrait_size * 0.29, portrait_size * 0.16), fur, outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.70, portrait_size * 0.53), Vector2(portrait_size * 0.15, portrait_size * 0.12), fur.lightened(0.08), outline)
	draw_line(origin + Vector2(portrait_size * 0.28, portrait_size * 0.47), origin + Vector2(portrait_size * 0.62, portrait_size * 0.43), ash, portrait_size * 0.045)
	draw_line(origin + Vector2(portrait_size * 0.73, portrait_size * 0.58), origin + Vector2(portrait_size * 0.86, portrait_size * 0.52), tusk, portrait_size * 0.020)
	draw_line(origin + Vector2(portrait_size * 0.73, portrait_size * 0.61), origin + Vector2(portrait_size * 0.84, portrait_size * 0.67), tusk, portrait_size * 0.020)
	draw_circle(origin + Vector2(portrait_size * 0.72, portrait_size * 0.49), portrait_size * 0.010, Color.BLACK)
	for foot_x in [0.36, 0.52, 0.64]:
		draw_line(origin + Vector2(portrait_size * foot_x, portrait_size * 0.72), origin + Vector2(portrait_size * foot_x, portrait_size * 0.86), fur, portrait_size * 0.028)


func _draw_moth(origin: Vector2, portrait_size: float) -> void:
	var gold := Color(0.95, 0.68, 0.22, 0.92)
	var wing := Color(0.98, 0.84, 0.40, 0.74)
	var dark := Color(0.12, 0.08, 0.04, 0.92)
	var glow := Color(1.0, 0.78, 0.24, 0.20)
	var center := origin + Vector2(portrait_size * 0.50, portrait_size * 0.54)
	draw_circle(center, portrait_size * 0.28, glow)
	_draw_ellipse(origin + Vector2(portrait_size * 0.36, portrait_size * 0.50), Vector2(portrait_size * 0.16, portrait_size * 0.26), wing, dark)
	_draw_ellipse(origin + Vector2(portrait_size * 0.64, portrait_size * 0.50), Vector2(portrait_size * 0.16, portrait_size * 0.26), wing, dark)
	draw_line(origin + Vector2(portrait_size * 0.50, portrait_size * 0.32), origin + Vector2(portrait_size * 0.50, portrait_size * 0.72), dark, portrait_size * 0.038)
	draw_circle(origin + Vector2(portrait_size * 0.50, portrait_size * 0.35), portrait_size * 0.055, gold)
	draw_line(origin + Vector2(portrait_size * 0.47, portrait_size * 0.30), origin + Vector2(portrait_size * 0.37, portrait_size * 0.22), gold, portrait_size * 0.012)
	draw_line(origin + Vector2(portrait_size * 0.53, portrait_size * 0.30), origin + Vector2(portrait_size * 0.63, portrait_size * 0.22), gold, portrait_size * 0.012)


func _draw_toad(origin: Vector2, portrait_size: float) -> void:
	var skin := Color(0.45, 0.36, 0.20, 1.0)
	var throat := Color(0.77, 0.65, 0.39, 1.0)
	var spot := Color(0.18, 0.14, 0.08, 1.0)
	var outline := Color(0.06, 0.05, 0.03, 0.9)
	_draw_ellipse(origin + Vector2(portrait_size * 0.50, portrait_size * 0.62), Vector2(portrait_size * 0.28, portrait_size * 0.18), skin, outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.50, portrait_size * 0.46), Vector2(portrait_size * 0.20, portrait_size * 0.13), skin.lightened(0.10), outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.50, portrait_size * 0.55), Vector2(portrait_size * 0.16, portrait_size * 0.09), throat, outline)
	draw_circle(origin + Vector2(portrait_size * 0.42, portrait_size * 0.41), portrait_size * 0.022, Color(0.88, 0.76, 0.36))
	draw_circle(origin + Vector2(portrait_size * 0.58, portrait_size * 0.41), portrait_size * 0.022, Color(0.88, 0.76, 0.36))
	for spot_position in [Vector2(0.37, 0.60), Vector2(0.52, 0.67), Vector2(0.64, 0.58)]:
		draw_circle(origin + portrait_size * spot_position, portrait_size * 0.020, spot)


func _draw_spider(origin: Vector2, portrait_size: float) -> void:
	var shell := Color(0.21, 0.21, 0.22, 1.0)
	var pale := Color(0.72, 0.70, 0.64, 1.0)
	var venom := Color(0.58, 0.82, 0.62, 1.0)
	var outline := Color(0.02, 0.02, 0.02, 0.9)
	_draw_ellipse(origin + Vector2(portrait_size * 0.47, portrait_size * 0.58), Vector2(portrait_size * 0.19, portrait_size * 0.16), shell, outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.62, portrait_size * 0.50), Vector2(portrait_size * 0.13, portrait_size * 0.11), shell.lightened(0.08), outline)
	for index in range(4):
		var y := 0.47 + float(index) * 0.06
		draw_line(origin + Vector2(portrait_size * 0.42, portrait_size * y), origin + Vector2(portrait_size * 0.20, portrait_size * (y - 0.10)), pale, portrait_size * 0.018)
		draw_line(origin + Vector2(portrait_size * 0.52, portrait_size * y), origin + Vector2(portrait_size * 0.78, portrait_size * (y - 0.08)), pale, portrait_size * 0.018)
	draw_circle(origin + Vector2(portrait_size * 0.64, portrait_size * 0.48), portrait_size * 0.012, venom)
	draw_circle(origin + Vector2(portrait_size * 0.69, portrait_size * 0.49), portrait_size * 0.012, venom)


func _draw_crow(origin: Vector2, portrait_size: float) -> void:
	var feather := Color(0.05, 0.06, 0.08, 1.0)
	var blue := Color(0.10, 0.16, 0.22, 1.0)
	var beak := Color(0.76, 0.62, 0.30, 1.0)
	var outline := Color(0.0, 0.0, 0.0, 0.92)
	_draw_ellipse(origin + Vector2(portrait_size * 0.47, portrait_size * 0.57), Vector2(portrait_size * 0.22, portrait_size * 0.15), feather, outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.64, portrait_size * 0.45), Vector2(portrait_size * 0.10, portrait_size * 0.09), blue, outline)
	var wing := PackedVector2Array([
		origin + Vector2(portrait_size * 0.41, portrait_size * 0.48),
		origin + Vector2(portrait_size * 0.20, portrait_size * 0.37),
		origin + Vector2(portrait_size * 0.30, portrait_size * 0.66),
	])
	draw_colored_polygon(wing, blue)
	draw_polyline(wing, outline, portrait_size * 0.012, true)
	var beak_points := PackedVector2Array([
		origin + Vector2(portrait_size * 0.72, portrait_size * 0.44),
		origin + Vector2(portrait_size * 0.86, portrait_size * 0.47),
		origin + Vector2(portrait_size * 0.72, portrait_size * 0.50),
	])
	draw_colored_polygon(beak_points, beak)
	draw_circle(origin + Vector2(portrait_size * 0.67, portrait_size * 0.42), portrait_size * 0.011, Color(0.88, 0.80, 0.46))


func _draw_wolf(origin: Vector2, portrait_size: float) -> void:
	var fur := Color(0.16, 0.16, 0.15, 1.0)
	var ember := Color(1.0, 0.28, 0.08, 1.0)
	var root := Color(0.05, 0.03, 0.025, 1.0)
	var outline := Color(0.0, 0.0, 0.0, 0.9)
	_draw_ellipse(origin + Vector2(portrait_size * 0.45, portrait_size * 0.60), Vector2(portrait_size * 0.28, portrait_size * 0.14), fur, outline)
	var head := PackedVector2Array([
		origin + Vector2(portrait_size * 0.61, portrait_size * 0.48),
		origin + Vector2(portrait_size * 0.70, portrait_size * 0.34),
		origin + Vector2(portrait_size * 0.82, portrait_size * 0.44),
		origin + Vector2(portrait_size * 0.81, portrait_size * 0.57),
		origin + Vector2(portrait_size * 0.68, portrait_size * 0.59),
	])
	draw_colored_polygon(head, fur.lightened(0.08))
	draw_polyline(head, outline, portrait_size * 0.014, true)
	draw_circle(origin + Vector2(portrait_size * 0.72, portrait_size * 0.47), portrait_size * 0.013, ember)
	draw_circle(origin + Vector2(portrait_size * 0.78, portrait_size * 0.48), portrait_size * 0.013, ember)
	draw_line(origin + Vector2(portrait_size * 0.27, portrait_size * 0.52), origin + Vector2(portrait_size * 0.15, portrait_size * 0.39), fur, portrait_size * 0.035)
	for index in range(4):
		var x := 0.35 + index * 0.09
		draw_line(origin + Vector2(portrait_size * x, portrait_size * 0.49), origin + Vector2(portrait_size * (x - 0.03), portrait_size * 0.37), root, portrait_size * 0.013)


func _draw_stag(origin: Vector2, portrait_size: float) -> void:
	var fur := Color(0.26, 0.14, 0.09, 1.0)
	var root := Color(0.03, 0.02, 0.015, 1.0)
	var ember := Color(1.0, 0.24, 0.10, 1.0)
	var outline := Color(0.0, 0.0, 0.0, 0.9)
	_draw_ellipse(origin + Vector2(portrait_size * 0.47, portrait_size * 0.63), Vector2(portrait_size * 0.25, portrait_size * 0.14), fur, outline)
	_draw_ellipse(origin + Vector2(portrait_size * 0.66, portrait_size * 0.42), Vector2(portrait_size * 0.12, portrait_size * 0.10), fur.lightened(0.08), outline)
	draw_line(origin + Vector2(portrait_size * 0.59, portrait_size * 0.51), origin + Vector2(portrait_size * 0.51, portrait_size * 0.60), fur, portrait_size * 0.065)
	for side in [-1.0, 1.0]:
		var antler_root := origin + Vector2(portrait_size * (0.66 + side * 0.04), portrait_size * 0.34)
		draw_line(antler_root, antler_root + Vector2(portrait_size * side * 0.12, -portrait_size * 0.18), root, portrait_size * 0.020)
		draw_line(antler_root + Vector2(portrait_size * side * 0.07, -portrait_size * 0.10), antler_root + Vector2(portrait_size * side * 0.15, -portrait_size * 0.09), root, portrait_size * 0.014)
		draw_line(antler_root + Vector2(portrait_size * side * 0.10, -portrait_size * 0.15), antler_root + Vector2(portrait_size * side * 0.17, -portrait_size * 0.19), root, portrait_size * 0.014)
	draw_circle(origin + Vector2(portrait_size * 0.68, portrait_size * 0.41), portrait_size * 0.012, ember)
	draw_line(origin + Vector2(portrait_size * 0.37, portrait_size * 0.52), origin + Vector2(portrait_size * 0.55, portrait_size * 0.49), root, portrait_size * 0.018)
	for foot_x in [0.35, 0.48, 0.58]:
		draw_line(origin + Vector2(portrait_size * foot_x, portrait_size * 0.73), origin + Vector2(portrait_size * (foot_x - 0.02), portrait_size * 0.86), fur, portrait_size * 0.025)


func _draw_needle(point: Vector2, needle_size: float, fill: Color, outline: Color) -> void:
	var points := PackedVector2Array([
		point + Vector2(0.0, -needle_size),
		point + Vector2(needle_size * 0.42, needle_size * 0.20),
		point + Vector2(0.0, needle_size * 0.72),
		point + Vector2(-needle_size * 0.42, needle_size * 0.20),
	])
	draw_colored_polygon(points, fill)
	draw_polyline(points, outline, needle_size * 0.10, true)


func _draw_ellipse(center: Vector2, radius: Vector2, fill: Color, outline: Color) -> void:
	draw_set_transform(center, 0.0, radius)
	draw_circle(Vector2.ZERO, 1.0, fill)
	draw_arc(Vector2.ZERO, 1.0, 0.0, TAU, 36, outline, 0.06)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
