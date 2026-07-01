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

var _has_destination := false
var _destination := Vector3.ZERO


## Sets a new destination in world space.
func set_destination(destination: Vector3) -> void:
	_destination = destination
	_has_destination = true


## Clears destination state and stops the character immediately.
func stop(character: CharacterBody3D) -> void:
	_has_destination = false
	character.velocity = Vector3.ZERO


## Advances movement for one physics frame and returns intended direction.
func move_to_destination(character: CharacterBody3D, delta: float) -> Vector3:
	if not _has_destination:
		return _decelerate(character, delta)

	var movement_direction := _direction_to_destination(character)
	if movement_direction == Vector3.ZERO:
		stop(character)
		character.move_and_slide()
		return Vector3.ZERO

	var target_velocity := movement_direction * movement_speed
	var current_horizontal_velocity := Vector3(character.velocity.x, 0.0, character.velocity.z)

	if _should_snap_direction(current_horizontal_velocity, movement_direction):
		# Preserve current speed but rotate velocity instantly for responsive click-turns.
		var current_speed := current_horizontal_velocity.length()
		character.velocity.x = movement_direction.x * current_speed
		character.velocity.z = movement_direction.z * current_speed

	character.velocity.x = move_toward(character.velocity.x, target_velocity.x, acceleration * delta)
	character.velocity.y = 0.0
	character.velocity.z = move_toward(character.velocity.z, target_velocity.z, acceleration * delta)
	character.move_and_slide()

	if _is_at_destination(character):
		stop(character)

	return movement_direction


## Returns the current horizontal velocity direction, or Vector3.ZERO if stopped.
func get_horizontal_velocity_direction(character: CharacterBody3D) -> Vector3:
	var horizontal_velocity := Vector3(character.velocity.x, 0.0, character.velocity.z)
	if horizontal_velocity.length_squared() <= 0.0001:
		return Vector3.ZERO

	return horizontal_velocity.normalized()


func _decelerate(character: CharacterBody3D, delta: float) -> Vector3:
	character.velocity.x = move_toward(character.velocity.x, 0.0, deceleration * delta)
	character.velocity.y = 0.0
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
