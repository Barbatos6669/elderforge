## High-level coordinator for the reusable player prefab.
##
## This script intentionally delegates real work to child modules: input,
## movement, facing, animation, audio, feedback, stats, and camera.
class_name PlayerController
extends CharacterBody3D

## Allows scenes or tests to temporarily disable local player control.
@export var input_enabled: bool = true

@onready var input_reader = $Input
@onready var stats: PlayerStats = $Stats
@onready var movement_motor = $Movement
@onready var facing = $Facing
@onready var animation = $Animation
@onready var footstep_audio = $FootstepAudio
@onready var click_feedback = $ClickFeedback
@onready var camera_target: Node3D = $CameraTarget
@onready var camera_rig = $CameraRig


func _ready() -> void:
	camera_rig.set_target(camera_target)


func _physics_process(delta: float) -> void:
	if not input_enabled:
		movement_motor.stop(self)
		animation.set_moving(false)
		footstep_audio.set_moving(false)
		return

	if input_reader.is_stop_requested():
		movement_motor.stop(self)
	else:
		var move_target = input_reader.get_click_move_target(self)
		if move_target != null:
			movement_motor.set_destination(move_target)
			if input_reader.was_click_move_started():
				click_feedback.spawn(move_target, self)

	var movement_direction: Vector3 = movement_motor.move_to_destination(self, delta)
	var visual_direction: Vector3 = movement_motor.get_horizontal_velocity_direction(self)
	if visual_direction == Vector3.ZERO:
		visual_direction = movement_direction

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var is_moving := horizontal_velocity.length_squared() > 0.01

	# Animation and footsteps use velocity, not destination intent, so stopping
	# and arrival states stay visually/audio synchronized.
	facing.face_direction(visual_direction)
	animation.set_moving(is_moving)
	footstep_audio.set_moving(is_moving)
