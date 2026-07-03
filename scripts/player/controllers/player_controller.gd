## High-level coordinator for the reusable player prefab.
##
## This script intentionally delegates real work to child modules: input,
## movement, facing, animation, audio, feedback, stats, and camera.
class_name PlayerController
extends CharacterBody3D

const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"

## Allows scenes or tests to temporarily disable local player control.
@export var input_enabled: bool = true

@onready var input_reader = $Input
@onready var stats: PlayerStats = $Stats
@onready var targeting = $Targeting
@onready var auto_attack = $AutoAttack
@onready var channeling = $Channeling
@onready var gathering = $Gathering
@onready var movement_motor = $Movement
@onready var facing = $Facing
@onready var animation = $Animation
@onready var footstep_audio = $FootstepAudio
@onready var click_feedback = $ClickFeedback
@onready var camera_target: Node3D = $CameraTarget
@onready var camera_rig = $CameraRig

var _pending_refining_station: Node


func _ready() -> void:
	camera_rig.set_target(camera_target)
	auto_attack.attack_landed.connect(_on_auto_attack_landed)
	channeling.channel_started.connect(_on_channel_started)
	channeling.channel_completed.connect(_on_channel_completed)
	channeling.channel_cancelled.connect(_on_channel_cancelled)


func _physics_process(delta: float) -> void:
	if not input_enabled:
		movement_motor.stop(self)
		animation.set_moving(false)
		footstep_audio.set_moving(false)
		auto_attack.stop_attack()
		_cancel_gathering_action("Control disabled")
		_clear_pending_refining_station()
		return

	if _is_world_input_blocked():
		_pause_world_movement_for_ui(delta)
		return

	if input_reader.is_stop_requested():
		movement_motor.stop(self)
		auto_attack.stop_attack()
		_cancel_gathering_action("Stopped")
		_clear_pending_refining_station()
	else:
		var clicked_target: Node = targeting.try_select_on_click(self)
		if clicked_target != null:
			input_reader.block_click_move_until_mouse_release()
			if gathering.start_gather(clicked_target, self):
				auto_attack.stop_attack()
				_clear_pending_refining_station()
				if channeling.is_channeling():
					channeling.cancel_channel("New action")
			elif _start_refining_station_interaction(clicked_target):
				auto_attack.stop_attack()
				_cancel_gathering_action("New action")
			elif auto_attack.start_attack(clicked_target, self):
				_cancel_gathering_action("New action")
				_clear_pending_refining_station()
				movement_motor.stop(self)
		else:
			if input_reader.was_auto_attack_pressed():
				if auto_attack.start_attack(targeting.get_current_target(), self):
					_cancel_gathering_action("New action")
					_clear_pending_refining_station()
					movement_motor.stop(self)

			var move_target = input_reader.get_click_move_target(self)
			if move_target != null:
				if input_reader.was_click_move_started():
					auto_attack.stop_attack()
					_cancel_gathering_action("Moved")
					_clear_pending_refining_station()
				movement_motor.set_destination(move_target)
				if input_reader.was_click_move_started():
					click_feedback.spawn(move_target, self)

	_update_auto_attack_movement()
	_update_gathering_movement()
	_update_refining_station_movement()

	var movement_direction: Vector3 = movement_motor.move_to_destination(self, delta)
	var visual_direction: Vector3 = movement_motor.get_horizontal_velocity_direction(self)
	if visual_direction == Vector3.ZERO:
		visual_direction = movement_direction
	if auto_attack.has_active_target() and auto_attack.is_target_in_range(self):
		var target_direction: Vector3 = auto_attack.get_direction_to_target(self)
		if target_direction != Vector3.ZERO:
			visual_direction = target_direction
	elif gathering.has_active_target() and gathering.is_target_in_range(self):
		var gather_direction: Vector3 = gathering.get_direction_to_target(self)
		if gather_direction != Vector3.ZERO:
			visual_direction = gather_direction
	elif _has_pending_refining_station() and _is_refining_station_in_range(_pending_refining_station):
		var station_direction := _direction_to_refining_station(_pending_refining_station)
		if station_direction != Vector3.ZERO:
			visual_direction = station_direction

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var is_moving := horizontal_velocity.length_squared() > 0.01

	# Animation and footsteps use velocity, not destination intent, so stopping
	# and arrival states stay visually/audio synchronized.
	facing.face_direction(visual_direction)
	animation.set_moving(is_moving)
	footstep_audio.set_moving(is_moving)
	auto_attack.update_attack(self, delta)
	channeling.update_channel(delta)


func _pause_world_movement_for_ui(delta: float) -> void:
	input_reader.consume_current_action_state()
	targeting.consume_current_click_state()
	movement_motor.stop(self)
	animation.set_moving(false)
	footstep_audio.set_moving(false)
	auto_attack.update_attack(self, delta)
	channeling.update_channel(delta)


func _is_world_input_blocked() -> bool:
	if not is_inside_tree():
		return false

	for blocker in get_tree().get_nodes_in_group(WORLD_INPUT_BLOCKER_GROUP):
		if blocker == null or not is_instance_valid(blocker):
			continue
		if blocker.has_method("blocks_world_input") and bool(blocker.call("blocks_world_input")):
			return true

	return false


func _update_auto_attack_movement() -> void:
	if not auto_attack.has_active_target():
		return

	if auto_attack.is_target_in_range(self):
		movement_motor.stop(self)
	else:
		movement_motor.set_destination(auto_attack.get_approach_destination(self))


func _update_gathering_movement() -> void:
	if channeling.is_channel_type("gathering"):
		movement_motor.stop(self)
		return

	if not gathering.has_active_target():
		return

	if gathering.is_target_in_range(self):
		movement_motor.stop(self)
		gathering.start_channel_if_ready(self, channeling)
	else:
		movement_motor.set_destination(gathering.get_approach_destination(self))


func _update_refining_station_movement() -> void:
	if not _has_pending_refining_station():
		_clear_pending_refining_station()
		return

	if _is_refining_station_in_range(_pending_refining_station):
		movement_motor.stop(self)
		_try_open_refining_station(_pending_refining_station)
		_clear_pending_refining_station()
		return

	movement_motor.set_destination(_refining_station_destination(_pending_refining_station))


func _cancel_gathering_action(reason: String) -> void:
	gathering.cancel_gathering()
	if channeling.is_channeling():
		channeling.cancel_channel(reason)
	else:
		animation.set_gathering(false)


func _start_refining_station_interaction(target: Node) -> bool:
	var station := _find_refining_station(target)
	if station == null:
		return false

	if _try_open_refining_station(station):
		_clear_pending_refining_station()
		movement_motor.stop(self)
	else:
		_pending_refining_station = station
		movement_motor.set_destination(_refining_station_destination(station))
	return true


func _try_open_refining_station(target: Node) -> bool:
	var station := _find_refining_station(target)
	if station == null or not station.has_method("open_refining_menu"):
		return false

	return bool(station.call("open_refining_menu", self))


func _find_refining_station(target: Node) -> Node:
	var current := target
	while current != null:
		if current.has_method("open_refining_menu") and current.has_method("get_refining_recipe"):
			return current

		current = current.get_parent()

	return null


func _has_pending_refining_station() -> bool:
	return _pending_refining_station != null and is_instance_valid(_pending_refining_station)


func _clear_pending_refining_station() -> void:
	_pending_refining_station = null


func _is_refining_station_in_range(station: Node) -> bool:
	if station == null or not station.has_method("can_interact_from"):
		return false

	return bool(station.call("can_interact_from", self))


func _refining_station_destination(station: Node) -> Vector3:
	if station != null and station.has_method("get_interaction_destination"):
		return station.call("get_interaction_destination", self)

	var station_3d := station as Node3D
	return station_3d.global_position if station_3d != null else global_position


func _direction_to_refining_station(station: Node) -> Vector3:
	var station_3d := station as Node3D
	if station_3d == null:
		return Vector3.ZERO

	var direction := station_3d.global_position - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


func _on_auto_attack_landed(_target: Node, _damage: float) -> void:
	animation.play_attack()


func _on_channel_started(_action_name: String, _duration: float, context: Dictionary) -> void:
	if _is_gathering_channel_context(context):
		animation.set_gathering(true, context)


func _on_channel_completed(context: Dictionary) -> void:
	if _is_gathering_channel_context(context):
		animation.set_gathering(false)
	gathering.complete_gather(context)


func _on_channel_cancelled(_reason: String, context: Dictionary) -> void:
	if _is_gathering_channel_context(context):
		animation.set_gathering(false)


func _is_gathering_channel_context(context: Dictionary) -> bool:
	return String(context.get("type", "")) == "gathering"
