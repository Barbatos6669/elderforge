class_name PlayerInput
extends Node

@export var click_ray_length: float = 1000.0
@export_flags_3d_physics var click_collision_mask: int = 1

var _click_move_started := false
var _was_left_mouse_down := false
var _was_right_mouse_down := false


func is_stop_requested() -> bool:
	return Input.is_key_pressed(KEY_S)


func was_click_move_started() -> bool:
	return _click_move_started


func get_click_move_target(character: CharacterBody3D):
	var is_left_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var is_right_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var is_move_button_down := is_left_mouse_down or is_right_mouse_down
	_click_move_started = (
		(is_left_mouse_down and not _was_left_mouse_down)
		or (is_right_mouse_down and not _was_right_mouse_down)
	)

	_was_left_mouse_down = is_left_mouse_down
	_was_right_mouse_down = is_right_mouse_down

	if not is_move_button_down:
		return null

	var camera := character.get_viewport().get_camera_3d()
	if camera == null:
		return null

	var mouse_position := character.get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var ray_end := ray_origin + ray_direction * click_ray_length
	var direct_space_state := character.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, click_collision_mask)
	query.exclude = [character.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := direct_space_state.intersect_ray(query)
	if hit.has("position"):
		return hit["position"]

	return _intersect_character_floor(character, ray_origin, ray_direction)


func _intersect_character_floor(
	character: CharacterBody3D,
	ray_origin: Vector3,
	ray_direction: Vector3
):
	if absf(ray_direction.y) < 0.0001:
		return null

	var distance := (character.global_position.y - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return null

	return ray_origin + ray_direction * distance
