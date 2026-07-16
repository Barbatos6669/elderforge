## Reads local click-to-move input and converts screen clicks to world targets.
##
## This module owns input interpretation only; movement is handled by
## PlayerMovementMotor.
class_name PlayerInput
extends Node

const AbilitySlots := preload(
	"res://scripts/combat/abilities/equipment_ability_slots.gd"
)

## Maximum distance for the mouse raycast from the active camera.
@export var click_ray_length: float = 1000.0
## Physics collision mask used when looking for click-to-move ground hits.
@export_flags_3d_physics var click_collision_mask: int = 1

var _click_move_started := false
var _was_left_mouse_down := false
var _was_right_mouse_down := false
var _was_auto_attack_down := false
var _was_ability_slot_down := {}
var _was_escape_down := false
var _block_left_click_move_until_release := false
var _block_right_click_move_until_release := false


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
	_sync_action_key_state()
	_block_left_click_move_until_release = is_left_mouse_down
	_block_right_click_move_until_release = is_right_mouse_down


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


## Returns true only on the first frame Q is pressed for the equipped weapon spell.
func was_weapon_ability_q_pressed() -> bool:
	return was_ability_slot_pressed(&"q")


## Returns true only on the first frame the matching ability hotkey is pressed.
func was_ability_slot_pressed(slot_id: StringName) -> bool:
	if not AbilitySlots.INPUT_KEY_BY_SLOT.has(slot_id):
		return false

	var input_key = AbilitySlots.INPUT_KEY_BY_SLOT[slot_id]
	var is_ability_down := Input.is_key_pressed(input_key)
	var was_pressed := is_ability_down and not bool(
		_was_ability_slot_down.get(slot_id, false)
	)
	_was_ability_slot_down[slot_id] = is_ability_down
	return was_pressed


## Suppresses one consumed mouse button until that button is released.
##
## Keeping the buttons independent prevents a left-click ability confirmation
## from swallowing a right-click movement hold.
func block_click_move_until_mouse_release(mouse_button: int = MOUSE_BUTTON_LEFT) -> void:
	match mouse_button:
		MOUSE_BUTTON_LEFT:
			_block_left_click_move_until_release = true
			_was_left_mouse_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		MOUSE_BUTTON_RIGHT:
			_block_right_click_move_until_release = true
			_was_right_mouse_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		_:
			return
	_click_move_started = false


## Returns the current click-move target, or null when no move button is held.
func get_click_move_target(character: CharacterBody3D):
	var is_left_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var is_right_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_refresh_mouse_release_blocks(is_left_mouse_down, is_right_mouse_down)
	var can_use_left := is_left_mouse_down and not _block_left_click_move_until_release
	var can_use_right := is_right_mouse_down and not _block_right_click_move_until_release
	_click_move_started = (
		(can_use_left and not _was_left_mouse_down)
		or (can_use_right and not _was_right_mouse_down)
	)

	_was_left_mouse_down = is_left_mouse_down
	_was_right_mouse_down = is_right_mouse_down

	if not can_use_left and not can_use_right:
		_click_move_started = false
		return null

	return get_mouse_world_position(character)


## Reads cursor aim and click edges while a directional ability is prepared.
##
## Left-click confirms the ability, right-click remains a movement input, and
## Escape cancels. Keeping those channels separate lets combat aiming coexist
## with the normal click-to-move loop.
func get_directional_aim_input(character: CharacterBody3D) -> Dictionary:
	var is_left_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var is_right_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var is_escape_down := Input.is_key_pressed(KEY_ESCAPE)
	_refresh_mouse_release_blocks(is_left_mouse_down, is_right_mouse_down)
	var can_use_left := not _block_left_click_move_until_release
	var can_use_right := not _block_right_click_move_until_release
	var confirmed := can_use_left and is_left_mouse_down and not _was_left_mouse_down
	var cancelled := is_escape_down and not _was_escape_down
	var movement_started := (
		can_use_right and is_right_mouse_down and not _was_right_mouse_down
	)
	var world_position = get_mouse_world_position(character)
	var movement_world_position = (
		world_position if can_use_right and is_right_mouse_down else null
	)

	_was_left_mouse_down = is_left_mouse_down
	_was_right_mouse_down = is_right_mouse_down
	_was_escape_down = is_escape_down
	_click_move_started = movement_started

	return {
		"world_position": world_position,
		"confirmed": confirmed,
		"cancelled": cancelled,
		"movement_world_position": movement_world_position,
		"movement_started": movement_started,
	}


## Returns live right-click steering while a committed mobility ability owns
## character velocity. The motor queues this destination and takes it over on
## the first frame after the forced movement ends.
func get_mobility_followup_move_target(character: CharacterBody3D):
	var is_left_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var is_right_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_refresh_mouse_release_blocks(is_left_mouse_down, is_right_mouse_down)
	_click_move_started = (
		is_right_mouse_down
		and not _block_right_click_move_until_release
		and not _was_right_mouse_down
	)
	_was_left_mouse_down = is_left_mouse_down
	_was_right_mouse_down = is_right_mouse_down
	_sync_action_key_state()

	if not is_right_mouse_down or _block_right_click_move_until_release:
		return null
	return get_mouse_world_position(character)


func _refresh_mouse_release_blocks(is_left_mouse_down: bool, is_right_mouse_down: bool) -> void:
	if not is_left_mouse_down:
		_block_left_click_move_until_release = false
	if not is_right_mouse_down:
		_block_right_click_move_until_release = false


func _sync_action_key_state() -> void:
	_was_auto_attack_down = Input.is_key_pressed(KEY_SPACE)
	for slot_id in AbilitySlots.ACTIVE_SLOT_IDS:
		var input_key = AbilitySlots.INPUT_KEY_BY_SLOT[slot_id]
		_was_ability_slot_down[slot_id] = Input.is_key_pressed(input_key)
	_was_escape_down = Input.is_key_pressed(KEY_ESCAPE)


## Projects the current cursor onto world collision or the player's floor plane.
func get_mouse_world_position(character: CharacterBody3D):
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
