## Code-drawn player portrait placeholder for the top-left HUD.
##
## This will be replaced by character renders later. For now it gives the HUD a
## stable profile image without needing external portrait art.
class_name HudProfilePortrait
extends Control

@export var frame_color := Color(0.82, 0.68, 0.30, 1.0)
@export var background_color := Color(0.09, 0.12, 0.12, 1.0)
@export var skin_color := Color(0.74, 0.86, 0.92, 1.0)
@export var shadow_color := Color(0.02, 0.025, 0.025, 0.85)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var unit := minf(size.x, size.y)
	if unit <= 0.0:
		return

	var center := size * 0.5
	var radius := unit * 0.46
	draw_circle(center, radius, shadow_color)
	draw_circle(center, radius * 0.92, background_color)
	draw_arc(center, radius * 0.97, 0.0, TAU, 96, frame_color, maxf(unit * 0.045, 2.0), true)

	var shoulder_rect := Rect2(
		center + Vector2(-unit * 0.26, unit * 0.11),
		Vector2(unit * 0.52, unit * 0.25)
	)
	draw_rect(shoulder_rect, skin_color.darkened(0.18))

	var neck_rect := Rect2(
		center + Vector2(-unit * 0.08, unit * 0.03),
		Vector2(unit * 0.16, unit * 0.18)
	)
	draw_rect(neck_rect, skin_color.darkened(0.08))

	draw_circle(center + Vector2(0.0, -unit * 0.12), unit * 0.16, skin_color)
	draw_circle(center + Vector2(-unit * 0.055, -unit * 0.13), unit * 0.018, Color(0.08, 0.10, 0.12, 1.0))
	draw_circle(center + Vector2(unit * 0.055, -unit * 0.13), unit * 0.018, Color(0.08, 0.10, 0.12, 1.0))
