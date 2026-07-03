## Reads local click-to-move input and converts screen clicks to world targets.
##
## This module owns input interpretation only; movement is handled by
## PlayerMovementMotor.
class_name PlayerInput
extends Node

## Maximum distance for the mouse raycast from the active camera.
@export var click_ray_length: float = 1000.0
## Physics collision mask used when looking for click-to-move ground hits.
@export_flags_3d_physics var click_collision_mask: int = 1

var _click_move_started := false
var _was_left_mouse_down := false
var _was_right_mouse_down := false
var _was_auto_attack_down := false
var _block_click_move_until_mouse_release := false


## Syncs internal press-edge state while another system owns player input.
##
## UI windows call this through PlayerController so clicks used for dragging or
## pressing buttons do not become movement orders when the window closes.
func consume_current_action_state() -> void:
	var is_left_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var is_right_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_click_move_started = false
	_was_left_mouse_down = is_left_mouse_down
	_was_right_mouse_down = is_right_mouse_down
	_was_auto_attack_down = Input.is_key_pressed(KEY_SPACE)
	_block_click_move_until_mouse_release = is_left_mouse_down or is_right_mouse_down


## Returns true while the stop key is held.
func is_stop_requested() -> bool:
	return Input.is_key_pressed(KEY_S)


## Returns true only on the first frame of a left or right click-move press.
func was_click_move_started() -> bool:
	return _click_move_started


## Returns true only on the first frame Space is pressed for auto-attack.
func was_auto_attack_pressed() -> bool:
	var is_auto_attack_down := Input.is_key_pressed(KEY_SPACE)
	var was_pressed := is_auto_attack_down and not _was_auto_attack_down
	_was_auto_attack_down = is_auto_attack_down
	return was_pressed


## Suppresses held mouse movement after another module consumes the current click.
func block_click_move_until_mouse_release() -> void:
	_block_click_move_until_mouse_release = true
	_click_move_started = false
	_was_left_mouse_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_was_right_mouse_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


## Returns the current click-move target, or null when no move button is held.
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

	if _block_click_move_until_mouse_release:
		if is_move_button_down:
			_click_move_started = false
			return null

		_block_click_move_until_mouse_release = false

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
	# Exclude the player so clicks pass through the character body to the ground.
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, click_collision_mask)
	query.exclude = [character.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit := direct_space_state.intersect_ray(query)
	if hit.has("position"):
		return hit["position"]

	# In very simple test scenes, movement can still work without ground collision.
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
