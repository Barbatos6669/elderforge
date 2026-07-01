class_name PlayerMovementMotor
extends Node

@export var movement_speed: float = 5.0
@export var acceleration: float = 28.0
@export var deceleration: float = 36.0
@export var arrival_distance: float = 0.12
@export var direction_change_snap_angle: float = 0.65

var _has_destination := false
var _destination := Vector3.ZERO


func set_destination(destination: Vector3) -> void:
	_destination = destination
	_has_destination = true


func stop(character: CharacterBody3D) -> void:
	_has_destination = false
	character.velocity = Vector3.ZERO


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
