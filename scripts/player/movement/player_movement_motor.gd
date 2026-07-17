## Click-to-move motor for the player CharacterBody3D.
##
## The motor owns destination tracking and velocity changes. It does not read
## input directly, which keeps it reusable for AI or server-authoritative tests.
class_name PlayerMovementMotor
extends Node

## Target horizontal speed while moving.
@export var movement_speed: float = 5.0
## Speed gain per second while accelerating toward a destination.
@export var acceleration: float = 28.0
## Speed loss per second while stopping without a destination.
@export var deceleration: float = 36.0
## Distance from destination where the character is considered arrived.
@export var arrival_distance: float = 0.12
## Dot-product threshold below which sharp turns snap immediately.
@export var direction_change_snap_angle: float = 0.65
## Downward acceleration keeps the player attached to slopes and ramps.
@export var gravity: float = 32.0
## Small downward velocity applied while grounded so descending ramps stay smooth.
@export var floor_stick_velocity: float = 2.0
## Maximum downward speed for future uneven terrain or ledges.
@export var terminal_fall_speed: float = 48.0

var _has_destination := false
var _destination := Vector3.ZERO
var _forced_direction := Vector3.ZERO
var _forced_speed := 0.0
var _forced_remaining_seconds := 0.0
var _speed_multipliers: Dictionary = {}


## Sets a new destination in world space.
func set_destination(destination: Vector3) -> void:
	_destination = destination
	_has_destination = true


## Starts collision-aware movement that temporarily owns the motor. This is
## used by committed mobility abilities such as Dodge Roll.
func start_forced_movement(direction: Vector3, distance: float, duration_seconds: float) -> bool:
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	var safe_distance := maxf(distance, 0.0)
	var safe_duration := maxf(duration_seconds, 0.01)
	if flat_direction.length_squared() <= 0.0001 or safe_distance <= 0.0:
		return false

	_forced_direction = flat_direction.normalized()
	_forced_speed = safe_distance / safe_duration
	_forced_remaining_seconds = safe_duration
	return true


func is_forced_moving() -> bool:
	return _forced_remaining_seconds > 0.0 and _forced_direction != Vector3.ZERO


## Adds or updates a named ordinary-movement multiplier. Independent systems
## use distinct source ids so removing one slow never clears another effect.
func set_speed_multiplier(source_id: StringName, multiplier: float) -> void:
	if String(source_id).is_empty():
		return
	_speed_multipliers[String(source_id)] = maxf(multiplier, 0.0)


## Removes one named movement effect without disturbing other modifiers.
func clear_speed_multiplier(source_id: StringName) -> void:
	_speed_multipliers.erase(String(source_id))


## Returns base movement speed after every active multiplier is applied.
func get_effective_movement_speed() -> float:
	var effective_speed := maxf(movement_speed, 0.0)
	for raw_multiplier in _speed_multipliers.values():
		effective_speed *= maxf(float(raw_multiplier), 0.0)
	return effective_speed


## Clears destination state and stops the character immediately.
func stop(character: CharacterBody3D) -> void:
	_has_destination = false
	_forced_direction = Vector3.ZERO
	_forced_speed = 0.0
	_forced_remaining_seconds = 0.0
	character.velocity = Vector3.ZERO


## Advances movement for one physics frame and returns intended direction.
func move_to_destination(character: CharacterBody3D, delta: float) -> Vector3:
	if is_forced_moving():
		return _move_forced(character, delta)

	if not _has_destination:
		return _decelerate(character, delta)

	var movement_direction := _direction_to_destination(character)
	if movement_direction == Vector3.ZERO:
		stop(character)
		_apply_vertical_velocity(character, delta)
		character.move_and_slide()
		return Vector3.ZERO

	var target_velocity := movement_direction * get_effective_movement_speed()
	var current_horizontal_velocity := Vector3(character.velocity.x, 0.0, character.velocity.z)

	if _should_snap_direction(current_horizontal_velocity, movement_direction):
		# Preserve current speed but rotate velocity instantly for responsive click-turns.
		var current_speed := current_horizontal_velocity.length()
		character.velocity.x = movement_direction.x * current_speed
		character.velocity.z = movement_direction.z * current_speed

	character.velocity.x = move_toward(character.velocity.x, target_velocity.x, acceleration * delta)
	_apply_vertical_velocity(character, delta)
	character.velocity.z = move_toward(character.velocity.z, target_velocity.z, acceleration * delta)
	character.move_and_slide()

	if _is_at_destination(character):
		stop(character)

	return movement_direction


func _move_forced(character: CharacterBody3D, delta: float) -> Vector3:
	var frame_delta := maxf(delta, 0.0)
	if frame_delta <= 0.0:
		return _forced_direction
	var elapsed := minf(frame_delta, _forced_remaining_seconds)
	var final_frame_scale := elapsed / frame_delta
	character.velocity.x = _forced_direction.x * _forced_speed * final_frame_scale
	_apply_vertical_velocity(character, elapsed)
	character.velocity.z = _forced_direction.z * _forced_speed * final_frame_scale
	character.move_and_slide()
	_forced_remaining_seconds = maxf(_forced_remaining_seconds - elapsed, 0.0)

	if _forced_remaining_seconds <= 0.0:
		var completed_direction := _forced_direction
		_forced_direction = Vector3.ZERO
		_forced_speed = 0.0
		if not _has_destination:
			character.velocity.x = 0.0
			character.velocity.z = 0.0
		return completed_direction

	return _forced_direction


## Returns the current horizontal velocity direction, or Vector3.ZERO if stopped.
func get_horizontal_velocity_direction(character: CharacterBody3D) -> Vector3:
	var horizontal_velocity := Vector3(character.velocity.x, 0.0, character.velocity.z)
	if horizontal_velocity.length_squared() <= 0.0001:
		return Vector3.ZERO

	return horizontal_velocity.normalized()


func _decelerate(character: CharacterBody3D, delta: float) -> Vector3:
	character.velocity.x = move_toward(character.velocity.x, 0.0, deceleration * delta)
	_apply_vertical_velocity(character, delta)
	character.velocity.z = move_toward(character.velocity.z, 0.0, deceleration * delta)
	character.move_and_slide()

	return Vector3.ZERO


func _should_snap_direction(
	current_horizontal_velocity: Vector3,
	new_direction: Vector3
) -> bool:
	if current_horizontal_velocity.length_squared() <= 0.0001:
		return false

	return current_horizontal_velocity.normalized().dot(new_direction) < direction_change_snap_angle


func _direction_to_destination(character: CharacterBody3D) -> Vector3:
	var offset := _destination - character.global_position
	offset.y = 0.0

	if offset.length() <= arrival_distance:
		return Vector3.ZERO

	return offset.normalized()


func _is_at_destination(character: CharacterBody3D) -> bool:
	var offset := _destination - character.global_position
	offset.y = 0.0
	return offset.length() <= arrival_distance


func _apply_vertical_velocity(character: CharacterBody3D, delta: float) -> void:
	if character.is_on_floor():
		character.velocity.y = -floor_stick_velocity
	else:
		character.velocity.y = maxf(
			character.velocity.y - gravity * delta,
			-terminal_fall_speed
		)
