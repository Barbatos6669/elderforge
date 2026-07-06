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
@onready var health = get_node_or_null("Health")
@onready var combat_state = get_node_or_null("CombatState")
@onready var respawn = get_node_or_null("Respawn")

var _pending_refining_station: Node
var _pending_loot_container: Node
var _is_respawn_locked := false


func _ready() -> void:
	add_to_group("player")
	camera_rig.set_target(camera_target)
	auto_attack.attack_started.connect(_on_auto_attack_started)
	auto_attack.attack_landed.connect(_on_auto_attack_landed)
	channeling.channel_started.connect(_on_channel_started)
	channeling.channel_completed.connect(_on_channel_completed)
	channeling.channel_cancelled.connect(_on_channel_cancelled)
	if health != null and health.has_signal("damage_taken"):
		health.damage_taken.connect(_on_health_damage_taken)
	if combat_state != null and combat_state.has_signal("combat_state_changed"):
		combat_state.combat_state_changed.connect(_on_combat_state_changed)
	if respawn != null and respawn.has_signal("death_started") and respawn.has_signal("respawned"):
		respawn.death_started.connect(_on_player_death_started)
		respawn.respawned.connect(_on_player_respawned)
	_sync_health_regeneration_with_combat()


func _physics_process(delta: float) -> void:
	if _is_player_respawn_locked():
		_pause_player_for_respawn()
		return

	if not input_enabled:
		movement_motor.stop(self)
		animation.set_moving(false)
		footstep_audio.set_moving(false)
		auto_attack.stop_attack()
		_cancel_gathering_action("Control disabled")
		_clear_pending_refining_station()
		_clear_pending_loot_container()
		return

	if _is_world_input_blocked():
		_pause_world_movement_for_ui(delta)
		return

	if input_reader.is_stop_requested():
		movement_motor.stop(self)
		auto_attack.stop_attack()
		_cancel_gathering_action("Stopped")
		_clear_pending_refining_station()
		_clear_pending_loot_container()
	else:
		var clicked_target: Node = targeting.try_select_on_click(self)
		if clicked_target != null:
			input_reader.block_click_move_until_mouse_release()
			if gathering.start_gather(clicked_target, self):
				auto_attack.stop_attack()
				_clear_pending_refining_station()
				_clear_pending_loot_container()
				if channeling.is_channeling():
					channeling.cancel_channel("New action")
			elif _start_refining_station_interaction(clicked_target):
				auto_attack.stop_attack()
				_cancel_gathering_action("New action")
				_clear_pending_loot_container()
			elif _start_loot_container_interaction(clicked_target):
				auto_attack.stop_attack()
				_cancel_gathering_action("New action")
				_clear_pending_refining_station()
			elif auto_attack.start_attack(clicked_target, self):
				_cancel_gathering_action("New action")
				_clear_pending_refining_station()
				_clear_pending_loot_container()
				movement_motor.stop(self)
		else:
			if input_reader.was_auto_attack_pressed():
				if auto_attack.start_attack(targeting.get_current_target(), self):
					_cancel_gathering_action("New action")
					_clear_pending_refining_station()
					_clear_pending_loot_container()
					movement_motor.stop(self)

			var move_target = input_reader.get_click_move_target(self)
			if move_target != null:
				if input_reader.was_click_move_started():
					auto_attack.stop_attack()
					_cancel_gathering_action("Moved")
					_clear_pending_refining_station()
					_clear_pending_loot_container()
				movement_motor.set_destination(move_target)
				if input_reader.was_click_move_started():
					click_feedback.spawn(move_target, self)

	_update_auto_attack_movement()
	_update_gathering_movement()
	_update_refining_station_movement()
	_update_loot_container_movement()

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
	elif _has_pending_loot_container() and _is_loot_container_in_range(_pending_loot_container):
		var loot_direction := _direction_to_loot_container(_pending_loot_container)
		if loot_direction != Vector3.ZERO:
			visual_direction = loot_direction

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var is_moving := horizontal_velocity.length_squared() > 0.01

	# Animation and footsteps use velocity, not destination intent, so stopping
	# and arrival states stay visually/audio synchronized.
	facing.face_direction(visual_direction)
	animation.set_moving(is_moving)
	footstep_audio.set_moving(is_moving)
	auto_attack.update_attack(self, delta)
	channeling.update_channel(delta)


func _is_player_respawn_locked() -> bool:
	return (
		_is_respawn_locked
		or (
			respawn != null
			and respawn.has_method("is_respawning")
			and bool(respawn.call("is_respawning"))
		)
	)


func _pause_player_for_respawn() -> void:
	input_reader.consume_current_action_state()
	targeting.consume_current_click_state()
	movement_motor.stop(self)
	animation.set_moving(false)
	footstep_audio.set_moving(false)
	auto_attack.stop_attack()
	_cancel_gathering_action("Defeated")
	_clear_pending_refining_station()
	_clear_pending_loot_container()


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


func _update_loot_container_movement() -> void:
	if not _has_pending_loot_container():
		_clear_pending_loot_container()
		return

	if _is_loot_container_in_range(_pending_loot_container):
		movement_motor.stop(self)
		_try_open_loot_container(_pending_loot_container)
		_clear_pending_loot_container()
		return

	movement_motor.set_destination(_loot_container_destination(_pending_loot_container))


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

	_clear_pending_loot_container()
	if _try_open_refining_station(station):
		_clear_pending_refining_station()
		movement_motor.stop(self)
	else:
		_pending_refining_station = station
		movement_motor.set_destination(_refining_station_destination(station))
	return true


func _start_loot_container_interaction(target: Node) -> bool:
	var loot_container := _find_loot_container(target)
	if loot_container == null:
		return false

	_clear_pending_refining_station()
	if _try_open_loot_container(loot_container):
		_clear_pending_loot_container()
		movement_motor.stop(self)
	else:
		_pending_loot_container = loot_container
		movement_motor.set_destination(_loot_container_destination(loot_container))
	return true


func _try_open_refining_station(target: Node) -> bool:
	var station := _find_refining_station(target)
	if station == null or not station.has_method("open_refining_menu"):
		return false

	return bool(station.call("open_refining_menu", self))


func _try_open_loot_container(target: Node) -> bool:
	var loot_container := _find_loot_container(target)
	if loot_container == null or not loot_container.has_method("open_loot_menu"):
		return false

	return bool(loot_container.call("open_loot_menu", self))


func _find_refining_station(target: Node) -> Node:
	var current := target
	while current != null:
		if current.has_method("open_refining_menu") and current.has_method("get_refining_recipe"):
			return current

		current = current.get_parent()

	return null


func _find_loot_container(target: Node) -> Node:
	var current := target
	while current != null:
		if current.has_method("open_loot_menu") and current.has_method("get_loot_data"):
			return current

		current = current.get_parent()

	return null


func _has_pending_refining_station() -> bool:
	return _pending_refining_station != null and is_instance_valid(_pending_refining_station)


func _clear_pending_refining_station() -> void:
	_pending_refining_station = null


func _has_pending_loot_container() -> bool:
	return _pending_loot_container != null and is_instance_valid(_pending_loot_container)


func _clear_pending_loot_container() -> void:
	_pending_loot_container = null


func _is_refining_station_in_range(station: Node) -> bool:
	if station == null or not station.has_method("can_interact_from"):
		return false

	return bool(station.call("can_interact_from", self))


func _is_loot_container_in_range(loot_container: Node) -> bool:
	if loot_container == null or not loot_container.has_method("can_interact_from"):
		return false

	return bool(loot_container.call("can_interact_from", self))


func _refining_station_destination(station: Node) -> Vector3:
	if station != null and station.has_method("get_interaction_destination"):
		return station.call("get_interaction_destination", self)

	var station_3d := station as Node3D
	return station_3d.global_position if station_3d != null else global_position


func _loot_container_destination(loot_container: Node) -> Vector3:
	if loot_container != null and loot_container.has_method("get_interaction_destination"):
		return loot_container.call("get_interaction_destination", self)

	var loot_3d := loot_container as Node3D
	return loot_3d.global_position if loot_3d != null else global_position


func _direction_to_refining_station(station: Node) -> Vector3:
	var station_3d := station as Node3D
	if station_3d == null:
		return Vector3.ZERO

	var direction := station_3d.global_position - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


func _direction_to_loot_container(loot_container: Node) -> Vector3:
	var loot_3d := loot_container as Node3D
	if loot_3d == null:
		return Vector3.ZERO

	var direction := loot_3d.global_position - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


func _on_auto_attack_started(_target: Node) -> void:
	_mark_combat_activity()


func _on_auto_attack_landed(_target: Node, _damage: float) -> void:
	_mark_combat_activity()
	animation.play_attack(_auto_attack_animation_speed_scale())


func _auto_attack_animation_speed_scale() -> float:
	if stats == null:
		return 1.0

	var attacks_per_second := stats.get_stat(PlayerStats.AUTO_ATTACK_SPEED)
	return maxf(attacks_per_second, 0.01)


func _on_health_damage_taken(_amount: float) -> void:
	_mark_combat_activity()


func _on_combat_state_changed(_is_in_combat: bool) -> void:
	_sync_health_regeneration_with_combat()


func _on_player_death_started(_respawn_delay: float) -> void:
	_is_respawn_locked = true
	input_reader.consume_current_action_state()
	targeting.consume_current_click_state()
	movement_motor.stop(self)
	velocity = Vector3.ZERO
	footstep_audio.set_moving(false)
	auto_attack.stop_attack()
	_cancel_gathering_action("Defeated")
	targeting.clear_current_target()
	_clear_pending_refining_station()
	_clear_pending_loot_container()
	if combat_state != null:
		combat_state.force_out_of_combat()
	_sync_health_regeneration_with_combat()


func _on_player_respawned() -> void:
	_is_respawn_locked = false
	input_reader.consume_current_action_state()
	targeting.consume_current_click_state()
	movement_motor.stop(self)
	animation.set_moving(false)
	footstep_audio.set_moving(false)
	_sync_health_regeneration_with_combat()


func _mark_combat_activity() -> void:
	if combat_state != null and combat_state.has_method("notify_combat_activity"):
		combat_state.call("notify_combat_activity")
	else:
		_sync_health_regeneration_with_combat()


func _sync_health_regeneration_with_combat() -> void:
	if health == null or not health.has_method("set_regeneration_enabled"):
		return

	var is_in_combat := (
		combat_state != null
		and combat_state.has_method("is_in_combat")
		and bool(combat_state.call("is_in_combat"))
	)
	health.call("set_regeneration_enabled", not is_in_combat)


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
