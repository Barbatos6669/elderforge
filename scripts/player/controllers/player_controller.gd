## High-level coordinator for the reusable player prefab.
##
## This script intentionally delegates real work to child modules: input,
## movement, facing, animation, audio, feedback, stats, and camera.
class_name PlayerController
extends CharacterBody3D

const AbilitySlots := preload(
	"res://scripts/combat/abilities/equipment_ability_slots.gd"
)
const WORLD_INPUT_BLOCKER_GROUP := "blocking_world_input"
const NETWORK_ACTION_NONE := ""
const NETWORK_ACTION_GATHERING := "gathering"
const NETWORK_ACTION_EQUIPMENT_ABILITY := "equipment_ability"
const EQUIPMENT_CHANNEL_SPEED_SOURCE := &"equipment_channel"

## Allows scenes or tests to temporarily disable local player control.
@export var input_enabled: bool = true
## Local players read input and own the active camera. Remote network copies are visual only.
@export var is_local_player: bool = true
## Multiplayer peer id represented by this player. Zero means not assigned yet.
@export var network_peer_id: int = 0
## How quickly visual-only remote players catch up to received network positions.
@export_range(1.0, 60.0, 0.5) var remote_position_smoothing_hz: float = 18.0
## How quickly visual-only remote players turn toward received network facing.
@export_range(1.0, 60.0, 0.5) var remote_rotation_smoothing_hz: float = 24.0
## Large corrections beyond this distance snap instead of smoothing across the map.
@export var remote_snap_distance: float = 5.0

@onready var input_reader = $Input
@onready var stats: PlayerStats = $Stats
@onready var targeting = $Targeting
@onready var auto_attack = $AutoAttack
@onready var weapon_abilities = $WeaponAbilities
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
@onready var mana = get_node_or_null("Mana")
@onready var combat_state = get_node_or_null("CombatState")
@onready var respawn = get_node_or_null("Respawn")
@onready var visuals: Node3D = $Visuals
@onready var visual_style = get_node_or_null("VisualStyle")
@onready var moonleaf_channel_aura = get_node_or_null("MoonleafChannelAura")

var _pending_refining_station: Node
var _pending_loot_container: Node
var _is_respawn_locked := false
var _has_remote_network_state := false
var _remote_target_position := Vector3.ZERO
var _remote_target_visual_yaw := 0.0
var _remote_target_is_moving := false
var _remote_target_action_state := NETWORK_ACTION_NONE
var _remote_target_action_context := {}
var _remote_target_vitals := {}
var _remote_is_defeated := false


func _ready() -> void:
	_connect_stats_runtime_signals()
	_sync_stats_to_runtime_components(true)

	if is_local_player:
		add_to_group("player")
		camera_rig.set_target(camera_target)
	else:
		_configure_remote_runtime()

	if not is_local_player:
		return

	auto_attack.attack_started.connect(_on_auto_attack_started)
	auto_attack.attack_landed.connect(_on_auto_attack_landed)
	weapon_abilities.ability_cast_started.connect(_on_weapon_ability_cast_started)
	weapon_abilities.ability_cast_landed.connect(_on_weapon_ability_cast_landed)
	weapon_abilities.ability_cast_interrupted.connect(_on_weapon_ability_cast_interrupted)
	weapon_abilities.ability_cast_finished.connect(_on_weapon_ability_cast_finished)
	weapon_abilities.directional_movement_started.connect(_on_directional_ability_movement_started)
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
	if not is_local_player:
		_update_remote_network_interpolation(delta)
		return

	weapon_abilities.update_abilities(self, delta)

	if _is_player_respawn_locked():
		_pause_player_for_respawn()
		return

	if not input_enabled:
		movement_motor.stop(self)
		animation.set_moving(false)
		footstep_audio.set_moving(false)
		auto_attack.stop_attack()
		weapon_abilities.cancel_current_action("Control disabled")
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
		weapon_abilities.cancel_current_action("Stopped")
		_cancel_gathering_action("Stopped")
		_clear_pending_refining_station()
		_clear_pending_loot_container()
	elif weapon_abilities.is_directional_movement_active():
		# The roll owns velocity, while held right-click keeps refreshing the
		# destination that should take over as soon as the roll ends.
		var followup_move_target = input_reader.get_mobility_followup_move_target(self)
		if followup_move_target is Vector3:
			_apply_directional_aim_movement(
				followup_move_target as Vector3,
				input_reader.was_click_move_started()
			)
		targeting.consume_current_click_state()
	else:
		for ability_slot in AbilitySlots.ACTIVE_SLOT_IDS:
			if input_reader.was_ability_slot_pressed(ability_slot):
				request_ability_activation(ability_slot)

		if weapon_abilities.is_directional_targeting():
			_update_directional_ability_targeting()
		else:
			_process_standard_world_input()

	_update_weapon_ability_movement()
	_update_auto_attack_movement()
	_update_gathering_movement()
	_update_refining_station_movement()
	_update_loot_container_movement()

	var movement_direction: Vector3 = movement_motor.move_to_destination(self, delta)
	var visual_direction: Vector3 = movement_motor.get_horizontal_velocity_direction(self)
	if visual_direction == Vector3.ZERO:
		visual_direction = movement_direction
	if weapon_abilities.has_active_request():
		var ability_direction: Vector3 = weapon_abilities.get_direction_to_target(self)
		if ability_direction != Vector3.ZERO:
			visual_direction = ability_direction
	elif auto_attack.has_active_target() and auto_attack.should_hold_position(self):
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
	if not weapon_abilities.is_directional_movement_active():
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
	weapon_abilities.reset_cast_state()
	_cancel_gathering_action("Defeated")
	_clear_pending_refining_station()
	_clear_pending_loot_container()


func _pause_world_movement_for_ui(delta: float) -> void:
	input_reader.consume_current_action_state()
	targeting.consume_current_click_state()
	movement_motor.stop(self)
	animation.set_moving(false)
	footstep_audio.set_moving(false)
	weapon_abilities.cancel_directional_targeting()
	auto_attack.update_attack(self, delta)
	channeling.update_channel(delta)


## Public entry point shared by keyboard hotkeys and clickable HUD slots.
## `from_pointer` prevents the HUD click that opened an aim preview from also
## confirming it on the same press.
func request_ability_activation(slot_id: StringName, from_pointer := false) -> bool:
	var definition: Resource = weapon_abilities.get_active_ability(slot_id)
	if definition == null:
		return false

	var targeting_mode := String(definition.get("targeting_mode"))
	var accepted := false
	if targeting_mode == "direction":
		accepted = weapon_abilities.begin_directional_targeting(slot_id, self)
	elif targeting_mode == "self":
		accepted = weapon_abilities.request_self_cast(slot_id, self)
	else:
		accepted = weapon_abilities.request_cast(slot_id, targeting.get_current_target(), self)
	if not accepted:
		return false

	if targeting_mode == "direction":
		if from_pointer:
			input_reader.block_click_move_until_mouse_release()
		return true

	auto_attack.stop_attack()
	_cancel_gathering_action("Equipment ability")
	_clear_pending_refining_station()
	_clear_pending_loot_container()
	return true


func _update_directional_ability_targeting() -> void:
	var aim_input: Dictionary = input_reader.get_directional_aim_input(self)
	var world_position: Variant = aim_input.get("world_position")
	if world_position is Vector3:
		weapon_abilities.update_directional_targeting(self, world_position as Vector3)
	var movement_world_position: Variant = aim_input.get("movement_world_position")
	if movement_world_position is Vector3:
		_apply_directional_aim_movement(
			movement_world_position as Vector3,
			bool(aim_input.get("movement_started", false))
		)

	if bool(aim_input.get("cancelled", false)):
		weapon_abilities.cancel_directional_targeting()
	elif bool(aim_input.get("confirmed", false)):
		weapon_abilities.confirm_directional_cast(self)
		input_reader.block_click_move_until_mouse_release(MOUSE_BUTTON_LEFT)


func _apply_directional_aim_movement(move_target: Vector3, movement_started: bool) -> void:
	if movement_started:
		auto_attack.stop_attack()
		_cancel_gathering_action("Moved")
		_clear_pending_refining_station()
		_clear_pending_loot_container()
		click_feedback.spawn(move_target, self)
	movement_motor.set_destination(move_target)


func _process_standard_world_input() -> void:
	var clicked_target: Node = targeting.try_select_on_click(self)
	if clicked_target != null:
		input_reader.block_click_move_until_mouse_release()
		if gathering.start_gather(clicked_target, self):
			auto_attack.stop_attack()
			weapon_abilities.cancel_current_action("New action")
			_clear_pending_refining_station()
			_clear_pending_loot_container()
			if channeling.is_channeling():
				channeling.cancel_channel("New action")
		elif _start_refining_station_interaction(clicked_target):
			auto_attack.stop_attack()
			weapon_abilities.cancel_current_action("New action")
			_cancel_gathering_action("New action")
			_clear_pending_loot_container()
		elif _start_loot_container_interaction(clicked_target):
			auto_attack.stop_attack()
			weapon_abilities.cancel_current_action("New action")
			_cancel_gathering_action("New action")
			_clear_pending_refining_station()
		elif auto_attack.start_attack(clicked_target, self):
			weapon_abilities.cancel_current_action("New action")
			_cancel_gathering_action("New action")
			_clear_pending_refining_station()
			_clear_pending_loot_container()
			movement_motor.stop(self)
		return

	if input_reader.was_auto_attack_pressed():
		if auto_attack.start_attack(targeting.get_current_target(), self):
			weapon_abilities.cancel_current_action("New action")
			_cancel_gathering_action("New action")
			_clear_pending_refining_station()
			_clear_pending_loot_container()
			movement_motor.stop(self)

	var move_target = input_reader.get_click_move_target(self)
	if move_target == null:
		return
	if input_reader.was_click_move_started():
		auto_attack.stop_attack()
		weapon_abilities.cancel_current_action("Moved", false)
		_cancel_gathering_action("Moved")
		_clear_pending_refining_station()
		_clear_pending_loot_container()
	movement_motor.set_destination(move_target)
	if input_reader.was_click_move_started():
		click_feedback.spawn(move_target, self)


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
	if (
		weapon_abilities.has_active_request()
		and not weapon_abilities.is_directional_targeting()
	):
		return
	if not auto_attack.has_active_target():
		return

	if auto_attack.should_hold_position(self):
		movement_motor.stop(self)
	else:
		movement_motor.set_destination(auto_attack.get_approach_destination(self))


func _update_weapon_ability_movement() -> void:
	if not weapon_abilities.has_active_request():
		return
	if (
		weapon_abilities.is_directional_targeting()
		or weapon_abilities.is_directional_movement_active()
	):
		return

	if weapon_abilities.should_hold_position(self):
		movement_motor.stop(self)
	else:
		movement_motor.set_destination(weapon_abilities.get_approach_destination(self))


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
	if channeling.is_channel_type("gathering"):
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
	if station == null:
		return false

	if station.has_method("open_refining_menu"):
		return bool(station.call("open_refining_menu", self))
	if station.has_method("open_service_interaction"):
		return bool(station.call("open_service_interaction", self))

	return false


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
		if current.has_method("open_service_interaction") and current.has_method("can_interact_from"):
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
	animation.play_attack(_auto_attack_animation_speed_scale())


func _on_auto_attack_landed(_target: Node, _damage: float) -> void:
	_mark_combat_activity()


func _on_weapon_ability_cast_started(_slot_id: StringName, target: Node, definition: Resource) -> void:
	_apply_ability_start_effects(definition)
	var execution_type := String(definition.get("execution_type"))
	if execution_type == "damage":
		_mark_combat_activity()
		movement_motor.stop(self)
	else:
		_cancel_gathering_action("Equipment ability")
		_clear_pending_refining_station()
		_clear_pending_loot_container()
	if execution_type == "regeneration":
		movement_motor.set_speed_multiplier(
			EQUIPMENT_CHANNEL_SPEED_SOURCE,
			maxf(float(definition.get("movement_speed_multiplier")), 0.0)
		)
	var target_3d := target as Node3D
	if target_3d != null:
		var direction := target_3d.global_position - global_position
		direction.y = 0.0
		facing.face_direction(direction)
	_play_weapon_ability_animation(definition)


func _on_directional_ability_movement_started(
	_slot_id: StringName,
	direction: Vector3,
	distance: float,
	duration_seconds: float
) -> void:
	if direction.length_squared() <= 0.0001:
		return
	facing.face_direction(direction)
	movement_motor.start_forced_movement(direction, distance, duration_seconds)


func _on_weapon_ability_cast_landed(_slot_id: StringName, _target: Node, _damage: float) -> void:
	_mark_combat_activity()


func _on_weapon_ability_cast_interrupted(
	_slot_id: StringName,
	_target: Node,
	_reason: String
) -> void:
	movement_motor.clear_speed_multiplier(EQUIPMENT_CHANNEL_SPEED_SOURCE)


func _on_weapon_ability_cast_finished(_slot_id: StringName) -> void:
	movement_motor.clear_speed_multiplier(EQUIPMENT_CHANNEL_SPEED_SOURCE)


## Plays a swing on a visual-only remote player when another peer begins its wind-up.
func play_remote_attack(speed_scale: float = 1.0) -> void:
	if is_local_player:
		return
	if animation != null:
		animation.play_attack(speed_scale)


## Mirrors an equipped weapon spell on a visual-only remote player.
func play_remote_weapon_ability(ability_id: String) -> void:
	if is_local_player or weapon_abilities == null:
		return
	var definition: Resource = weapon_abilities.get_known_ability(ability_id)
	_apply_ability_start_effects(definition)
	_play_weapon_ability_animation(definition)


func _apply_ability_start_effects(definition: Resource) -> void:
	_apply_ability_damage_immunity(definition)
	_apply_ability_absorb_shield(definition)
	_apply_ability_missing_energy_restore(definition)


func _apply_ability_damage_immunity(definition: Resource) -> void:
	if definition == null or health == null or not health.has_method("grant_damage_immunity"):
		return

	var duration_seconds := maxf(float(definition.get("damage_immunity_seconds")), 0.0)
	if duration_seconds > 0.0:
		health.call("grant_damage_immunity", duration_seconds)


func _apply_ability_absorb_shield(definition: Resource) -> void:
	if definition == null or health == null or not health.has_method("grant_absorb_shield"):
		return

	var shield_amount := maxf(float(definition.get("absorb_shield_amount")), 0.0)
	var duration_seconds := maxf(float(definition.get("absorb_shield_duration_seconds")), 0.0)
	if shield_amount > 0.0 and duration_seconds > 0.0:
		health.call("grant_absorb_shield", shield_amount, duration_seconds)


func _apply_ability_missing_energy_restore(definition: Resource) -> void:
	if definition == null or mana == null or not mana.has_method("restore"):
		return

	var restore_percent := maxf(float(definition.get("missing_energy_restore_percent")), 0.0)
	if restore_percent <= 0.0:
		return

	var max_resource := maxf(float(mana.get("max_resource")), 0.0)
	var current_resource := clampf(float(mana.get("current_resource")), 0.0, max_resource)
	var missing_resource := maxf(max_resource - current_resource, 0.0)
	mana.call("restore", missing_resource * restore_percent / 100.0)


func _play_weapon_ability_animation(definition: Resource) -> void:
	if animation == null or definition == null or not animation.has_method("play_weapon_ability"):
		return
	var animation_name := StringName(String(definition.get("animation_name")))
	if String(animation_name).is_empty():
		return
	animation.call(
		"play_weapon_ability",
		String(definition.get("animation_scene_path")),
		animation_name,
		maxf(float(definition.get("cast_duration_seconds")), 0.01),
		StringName(String(definition.get("recovery_animation_name")))
	)


func _auto_attack_animation_speed_scale() -> float:
	if stats == null:
		return 1.0

	var attacks_per_second := stats.get_stat(PlayerStats.AUTO_ATTACK_SPEED)
	return maxf(attacks_per_second, 0.01)


func _on_health_damage_taken(_amount: float) -> void:
	weapon_abilities.cancel_active_channel_on_damage()
	_mark_combat_activity()


func _on_combat_state_changed(is_in_combat: bool) -> void:
	if is_in_combat:
		weapon_abilities.cancel_out_of_combat_channel()
	_sync_health_regeneration_with_combat()


func _on_player_death_started(_respawn_delay: float) -> void:
	_is_respawn_locked = true
	input_reader.consume_current_action_state()
	targeting.consume_current_click_state()
	movement_motor.stop(self)
	velocity = Vector3.ZERO
	footstep_audio.set_moving(false)
	auto_attack.reset_attack_cycle()
	weapon_abilities.reset_cast_state()
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
	auto_attack.reset_attack_cycle()
	weapon_abilities.reset_cast_state()
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


func _connect_stats_runtime_signals() -> void:
	if stats == null or not stats.has_signal("stat_changed"):
		return

	var callable := Callable(self, "_on_player_stat_changed")
	if not stats.is_connected("stat_changed", callable):
		stats.connect("stat_changed", callable)


func _sync_stats_to_runtime_components(should_fill_pools := false) -> void:
	if stats == null:
		return

	var max_health := maxf(stats.get_stat(PlayerStats.MAX_HEALTH), 1.0)
	if health != null:
		if health.has_method("set_max_health"):
			health.call("set_max_health", max_health, should_fill_pools)
		else:
			health.set("max_health", max_health)
		health.set("health_regeneration_per_second", maxf(stats.get_stat(PlayerStats.HEALTH_REGENERATION), 0.0))

	if mana != null:
		var max_energy := maxf(stats.get_stat(PlayerStats.MAX_ENERGY), 0.0)
		if mana.has_method("set_max_resource"):
			mana.call("set_max_resource", max_energy, should_fill_pools)
		else:
			mana.set("max_resource", max_energy)
		mana.set("regeneration_per_second", maxf(stats.get_stat(PlayerStats.ENERGY_REGENERATION), 0.0))

	if movement_motor != null:
		var move_speed := stats.get_stat(PlayerStats.MOVE_SPEED)
		if move_speed > 0.0:
			movement_motor.movement_speed = move_speed

	_sync_health_regeneration_with_combat()


func _on_player_stat_changed(stat_id: StringName, _value: float) -> void:
	match stat_id:
		PlayerStats.MAX_HEALTH, \
		PlayerStats.HEALTH_REGENERATION, \
		PlayerStats.MAX_ENERGY, \
		PlayerStats.ENERGY_REGENERATION, \
		PlayerStats.MOVE_SPEED:
			_sync_stats_to_runtime_components(false)


## Converts this prefab instance into a visual-only network copy.
func configure_as_remote_player(peer_id: int, player_name: String = "") -> void:
	is_local_player = false
	network_peer_id = peer_id
	input_enabled = false
	if is_inside_tree():
		_configure_remote_runtime()
	_set_nameplate_player_name(_remote_display_name(peer_id, player_name))


## Returns compact state used by the prototype multiplayer presence sync.
func get_network_state() -> Dictionary:
	var visual_yaw := 0.0
	if visuals != null:
		visual_yaw = visuals.global_rotation.y
	var action_state := NETWORK_ACTION_NONE
	var action_context := {}
	if channeling != null and channeling.is_channel_type(NETWORK_ACTION_GATHERING):
		action_state = NETWORK_ACTION_GATHERING
		action_context = _network_action_context_from_channel(channeling.get_context())
	elif channeling != null and channeling.is_channel_type(NETWORK_ACTION_EQUIPMENT_ABILITY):
		action_state = NETWORK_ACTION_EQUIPMENT_ABILITY
		action_context = _network_action_context_from_channel(channeling.get_context())

	return {
		"position": global_position,
		"visual_yaw": visual_yaw,
		"is_moving": Vector3(velocity.x, 0.0, velocity.z).length_squared() > 0.01,
		"action_state": action_state,
		"action_context": action_context,
		"vitals": _network_vitals(),
	}


## Applies a network update to a remote visual copy.
func apply_remote_network_state(
	position_value: Vector3,
	visual_yaw: float,
	is_moving: bool,
	action_state: String = NETWORK_ACTION_NONE,
	action_context: Dictionary = {},
	vitals: Dictionary = {}
) -> void:
	if is_local_player:
		return

	_remote_target_position = position_value
	_remote_target_visual_yaw = visual_yaw
	_remote_target_is_moving = is_moving
	_remote_target_action_state = action_state
	_remote_target_action_context = action_context.duplicate(true)
	_remote_target_vitals = vitals.duplicate(true)
	_apply_remote_vitals(_remote_target_vitals)

	if not _has_remote_network_state:
		_has_remote_network_state = true
		global_position = _remote_target_position
		_apply_remote_visual_yaw(_remote_target_visual_yaw)
		if _remote_is_defeated:
			_set_remote_moving(false)
			_set_remote_action_state(NETWORK_ACTION_NONE, {})
		else:
			_set_remote_moving(false)
			_set_remote_action_state(_remote_target_action_state, _remote_target_action_context)


func _configure_remote_runtime() -> void:
	input_enabled = false
	collision_layer = 0
	collision_mask = 0
	remove_from_group("player")
	add_to_group("remote_player")
	_disable_remote_node(input_reader)
	_disable_remote_node(targeting)
	_disable_remote_node(auto_attack)
	_disable_remote_node(weapon_abilities)
	_disable_remote_node(channeling)
	_disable_remote_node(gathering)
	_disable_remote_node(movement_motor)
	_disable_remote_node(click_feedback)
	_disable_remote_node(respawn)
	_disable_remote_regeneration(health)
	_disable_remote_regeneration(mana)
	if respawn != null:
		respawn.set("enabled", false)
	if camera_rig != null:
		camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
		var camera := camera_rig.get_node_or_null("Camera3D") as Camera3D
		if camera != null:
			camera.current = false
	if has_node("ChannelBar"):
		$ChannelBar.visible = false


func _update_remote_network_interpolation(delta: float) -> void:
	if not _has_remote_network_state:
		return

	var distance_to_target := global_position.distance_to(_remote_target_position)
	if distance_to_target >= remote_snap_distance:
		global_position = _remote_target_position
	elif distance_to_target > 0.01:
		var position_blend := _exponential_blend(remote_position_smoothing_hz, delta)
		global_position = global_position.lerp(_remote_target_position, position_blend)
	else:
		global_position = _remote_target_position

	if visuals != null:
		var rotation_blend := _exponential_blend(remote_rotation_smoothing_hz, delta)
		visuals.global_rotation.y = lerp_angle(
			visuals.global_rotation.y,
			_remote_target_visual_yaw,
			rotation_blend
		)

	var is_action_locked := _remote_target_action_state == NETWORK_ACTION_GATHERING
	if _remote_is_defeated:
		_set_remote_moving(false)
		_set_remote_action_state(NETWORK_ACTION_NONE, {})
	else:
		_set_remote_moving(not is_action_locked and (_remote_target_is_moving or distance_to_target > 0.04))
		_set_remote_action_state(_remote_target_action_state, _remote_target_action_context)


func _apply_remote_visual_yaw(visual_yaw: float) -> void:
	if visuals != null:
		visuals.global_rotation.y = visual_yaw


func _set_remote_moving(is_moving: bool) -> void:
	if animation != null:
		animation.set_moving(is_moving)
	if footstep_audio != null:
		footstep_audio.set_moving(is_moving)


func _set_remote_action_state(action_state: String, action_context: Dictionary) -> void:
	if animation != null and action_state == NETWORK_ACTION_GATHERING:
		var context := action_context.duplicate(true)
		context["type"] = NETWORK_ACTION_GATHERING
		animation.set_gathering(true, context)
	elif animation != null:
		animation.set_gathering(false)

	if moonleaf_channel_aura != null and moonleaf_channel_aura.has_method("set_remote_channel_state"):
		moonleaf_channel_aura.call("set_remote_channel_state", action_state, action_context)


func _network_action_context_from_channel(context: Dictionary) -> Dictionary:
	return {
		"type": String(context.get("type", "")),
		"slot_id": String(context.get("slot_id", "")),
		"ability_id": String(context.get("ability_id", "")),
		"execution_type": String(context.get("execution_type", "")),
		"resource_family_id": String(context.get("resource_family_id", "")),
		"required_tool_family_id": String(context.get("required_tool_family_id", "")),
		"tool_family_id": String(context.get("tool_family_id", "")),
		"tool_animation_profile_path": String(context.get("tool_animation_profile_path", "")),
		"tool_tier": int(context.get("tool_tier", 0)),
		"resource_tier": int(context.get("resource_tier", 0)),
	}


func _network_vitals() -> Dictionary:
	var vitals := {}
	if health != null:
		vitals["health_current"] = float(health.get("current_health"))
		vitals["health_max"] = float(health.get("max_health"))
		vitals["health_defeated"] = bool(health.call("is_defeated")) if health.has_method("is_defeated") else false
	if mana != null:
		vitals["mana_current"] = float(mana.get("current_resource"))
		vitals["mana_max"] = float(mana.get("max_resource"))
	if visual_style != null and visual_style.has_method("get_network_appearance"):
		vitals["appearance"] = visual_style.call("get_network_appearance")

	return vitals


func _apply_remote_vitals(vitals: Dictionary) -> void:
	if vitals.is_empty():
		return

	var is_defeated := _remote_is_defeated
	if health != null:
		var max_health := maxf(float(vitals.get("health_max", health.get("max_health"))), 1.0)
		var current_health := clampf(float(vitals.get("health_current", max_health)), 0.0, max_health)
		health.set("max_health", max_health)
		if health.has_method("set_current_health"):
			health.call("set_current_health", current_health, false)
		else:
			health.set("current_health", current_health)
		is_defeated = bool(vitals.get("health_defeated", current_health <= 0.0))

	if mana != null:
		var max_mana := maxf(float(vitals.get("mana_max", mana.get("max_resource"))), 0.0)
		var current_mana := clampf(float(vitals.get("mana_current", max_mana)), 0.0, max_mana)
		if mana.has_method("set_max_resource"):
			mana.call("set_max_resource", max_mana, false)
		else:
			mana.set("max_resource", max_mana)
		if mana.has_method("set_current_resource"):
			mana.call("set_current_resource", current_mana)
		else:
			mana.set("current_resource", current_mana)

	var appearance_value: Variant = vitals.get("appearance", {})
	if visual_style != null and appearance_value is Dictionary and visual_style.has_method("apply_appearance"):
		visual_style.call("apply_appearance", appearance_value as Dictionary)

	if is_defeated and not _remote_is_defeated:
		_remote_is_defeated = true
		_set_remote_moving(false)
		_set_remote_action_state(NETWORK_ACTION_NONE, {})
		if animation != null and animation.has_method("play_death"):
			animation.call("play_death")
	elif not is_defeated and _remote_is_defeated:
		_remote_is_defeated = false
		if animation != null and animation.has_method("reset_animation_state"):
			animation.call("reset_animation_state")


func _exponential_blend(rate_hz: float, delta: float) -> float:
	return 1.0 - exp(-maxf(rate_hz, 0.01) * maxf(delta, 0.0))


func _disable_remote_node(node: Node) -> void:
	if node != null:
		node.process_mode = Node.PROCESS_MODE_DISABLED


func _disable_remote_regeneration(pool: Node) -> void:
	if pool == null:
		return

	pool.process_mode = Node.PROCESS_MODE_DISABLED
	if pool.has_method("set_regeneration_enabled"):
		pool.call("set_regeneration_enabled", false)


func _set_nameplate_player_name(player_name: String) -> void:
	var nameplate := get_node_or_null("Nameplate")
	if nameplate != null and nameplate.has_method("set_player_name"):
		nameplate.call("set_player_name", player_name)


func _remote_display_name(peer_id: int, player_name: String) -> String:
	var trimmed_name := player_name.strip_edges()
	return trimmed_name if not trimmed_name.is_empty() else "Player %d" % peer_id


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
