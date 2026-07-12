## Draws the compact HUD map used during normal gameplay.
##
## This view only knows how to render already-collected positions. World lookup
## stays in `hud_map.gd`, which keeps drawing separate from scene traversal.
class_name HudMapView
extends Control

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")

var map_center := Vector2.ZERO
var map_size_meters := Vector2(100.0, 100.0)
var map_rotation_degrees := 45.0
var has_player := false
var player_position := Vector3.ZERO
var player_yaw := 0.0
var resource_positions: Array[Vector3] = []
var mob_positions: Array[Vector3] = []
var service_positions: Array[Vector3] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func set_map_state(
	new_map_center: Vector2,
	new_map_size_meters: Vector2,
	new_map_rotation_degrees: float,
	new_has_player: bool,
	new_player_position: Vector3,
	new_player_yaw: float,
	new_resource_positions: Array[Vector3],
	new_mob_positions: Array[Vector3],
	new_service_positions: Array[Vector3]
) -> void:
	map_center = new_map_center
	map_size_meters = new_map_size_meters
	map_rotation_degrees = new_map_rotation_degrees
	has_player = new_has_player
	player_position = new_player_position
	player_yaw = new_player_yaw
	resource_positions = new_resource_positions
	mob_positions = new_mob_positions
	service_positions = new_service_positions
	queue_redraw()


func _draw() -> void:
	var map_rect := Rect2(Vector2.ZERO, size)
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return

	draw_rect(map_rect, Color(0.014, 0.019, 0.016, 0.96), true)
	_draw_grid()
	_draw_points(resource_positions, Color(0.34, 0.86, 0.32, 0.96), 2.4)
	_draw_points(service_positions, Color(0.96, 0.68, 0.22, 0.96), 3.0, true)
	_draw_points(mob_positions, Color(0.88, 0.18, 0.12, 0.96), 2.8)
	_draw_player_marker(map_rect)
	draw_rect(map_rect, UiStyle.COLOR_GOLD_SOFT, false, 1.0)


func _draw_grid() -> void:
	var safe_size := _safe_map_size()
	var min_corner := map_center - safe_size * 0.5
	var max_corner := map_center + safe_size * 0.5
	var grid_color := Color(UiStyle.COLOR_GOLD.r, UiStyle.COLOR_GOLD.g, UiStyle.COLOR_GOLD.b, 0.14)
	for line_index in range(1, 4):
		var ratio := float(line_index) / 4.0
		var world_x := min_corner.x + safe_size.x * ratio
		var world_z := min_corner.y + safe_size.y * ratio
		draw_line(
			_world_xz_to_map(Vector2(world_x, min_corner.y)),
			_world_xz_to_map(Vector2(world_x, max_corner.y)),
			grid_color,
			1.0
		)
		draw_line(
			_world_xz_to_map(Vector2(min_corner.x, world_z)),
			_world_xz_to_map(Vector2(max_corner.x, world_z)),
			grid_color,
			1.0
		)

	var axis_color := Color(0.75, 0.72, 0.58, 0.18)
	draw_line(
		_world_xz_to_map(Vector2(map_center.x, min_corner.y)),
		_world_xz_to_map(Vector2(map_center.x, max_corner.y)),
		axis_color,
		1.0
	)
	draw_line(
		_world_xz_to_map(Vector2(min_corner.x, map_center.y)),
		_world_xz_to_map(Vector2(max_corner.x, map_center.y)),
		axis_color,
		1.0
	)


func _draw_points(points: Array[Vector3], color: Color, radius: float, square := false) -> void:
	for world_position in points:
		var map_position := _world_to_map(world_position)
		if not _is_inside_view(map_position):
			continue

		if square:
			draw_rect(Rect2(map_position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color, true)
		else:
			draw_circle(map_position, radius, color)


func _draw_player_marker(map_rect: Rect2) -> void:
	if not has_player:
		return

	var center := _world_to_map(player_position)
	if not _is_inside_view(center):
		center = center.clamp(Vector2.ZERO, map_rect.size)

	draw_circle(center, 5.4, Color(0.05, 0.08, 0.07, 0.95))
	draw_circle(center, 4.0, UiStyle.COLOR_TEXT_PRIMARY)

	var forward := Vector2(-sin(player_yaw), -cos(player_yaw)).rotated(_map_rotation_radians())
	if forward.length_squared() <= 0.001:
		forward = Vector2.UP
	forward = forward.normalized()
	var right := forward.orthogonal()
	var triangle := PackedVector2Array([
		center + forward * 8.5,
		center - forward * 5.0 + right * 4.6,
		center - forward * 5.0 - right * 4.6,
	])
	draw_polygon(triangle, PackedColorArray([UiStyle.COLOR_GOLD, UiStyle.COLOR_GOLD, UiStyle.COLOR_GOLD]))


func _world_to_map(world_position: Vector3) -> Vector2:
	return _world_xz_to_map(Vector2(world_position.x, world_position.z))


func _world_xz_to_map(world_xz: Vector2) -> Vector2:
	var safe_size := _safe_map_size()
	var rotated_bounds := _rotated_bounds(safe_size)
	var rotated_delta := (world_xz - map_center).rotated(_map_rotation_radians())
	var normalized := Vector2(
		(rotated_delta.x + rotated_bounds.x * 0.5) / rotated_bounds.x,
		(rotated_delta.y + rotated_bounds.y * 0.5) / rotated_bounds.y
	)
	return Vector2(normalized.x * size.x, normalized.y * size.y)


func _safe_map_size() -> Vector2:
	return Vector2(maxf(map_size_meters.x, 0.01), maxf(map_size_meters.y, 0.01))


func _rotated_bounds(safe_size: Vector2) -> Vector2:
	var half_size := safe_size * 0.5
	var angle := _map_rotation_radians()
	var cosine := absf(cos(angle))
	var sine := absf(sin(angle))
	return Vector2(
		(cosine * half_size.x + sine * half_size.y) * 2.0,
		(sine * half_size.x + cosine * half_size.y) * 2.0
	)


func _map_rotation_radians() -> float:
	return deg_to_rad(map_rotation_degrees)


func _is_inside_view(map_position: Vector2) -> bool:
	return map_position.x >= 0.0 and map_position.y >= 0.0 and map_position.x <= size.x and map_position.y <= size.y
