## First-pass hostile mob brain.
##
## This module owns aggro, chase, melee attack timing, and leash behavior for a
## single CharacterBody3D mob. Health, selection, visuals, and animation remain
## separate child components so future enemy types can swap pieces independently.
class_name EnemyMobAI
extends Node

const AttackTimelineScript := preload("res://scripts/combat/attack_timeline.gd")
const AbilityImpactScheduleScript := preload(
	"res://scripts/combat/abilities/ability_impact_schedule.gd"
)
const AbilityTargetingMathScript := preload(
	"res://scripts/combat/abilities/ability_targeting_math.gd"
)
const DamageRequestScript := preload("res://scripts/combat/damage_request.gd")
const DamageResolverScript := preload("res://scripts/combat/damage_resolver.gd")
const AbilitySlots := preload("res://scripts/combat/abilities/equipment_ability_slots.gd")
const AbilityTelegraphScript := preload("res://scripts/effects/ability_telegraph_3d.gd")
const TARGETING_SELECTED := "selected_target"
const TARGETING_DIRECTION := "direction"
const TARGETING_SELF := "self"
const EXECUTION_DAMAGE := "damage"
const EXECUTION_DODGE := "dodge"
const EXECUTION_REGENERATION := "regeneration"
const EXECUTION_SHIELD := "shield"
const SWORD_SLASH_ABILITY_ID := "one_handed_sword_q"

enum AbilityAttemptResult {
	NONE,
	WAITING,
	STARTED,
}

signal aggro_started(target: Node)
signal aggro_dropped
signal attack_started(target: Node, speed_scale: float)
signal attack_landed(target: Node, damage: float)
signal ability_cast_started(slot_id: StringName, target: Node, definition: Resource)
signal ability_cast_landed(slot_id: StringName, target: Node, damage: float)
signal ability_cast_interrupted(slot_id: StringName, target: Node, reason: String)
signal ability_cast_finished(slot_id: StringName)
signal respawned

## Group used to find player characters that can draw aggro.
@export var target_group := "player"
## Health component on this mob.
@export var health_path: NodePath = NodePath("../Health")
## Optional shared stat component. When present, it overrides local combat exports.
@export var stats_path: NodePath = NodePath("../Stats")
## Animation controller used for idle, move, and attack playback.
@export var animation_path: NodePath = NodePath("../Animation")
## Selectable component disabled when the mob is defeated.
@export var selectable_path: NodePath = NodePath("../Selectable")
## Visual root rotated toward movement and attack direction.
@export var visuals_path: NodePath = NodePath("../Visuals")
## Optional component that spawns a loot bag when this mob dies.
@export var loot_dropper_path: NodePath = NodePath("../LootDropper")
## Optional mob-only equipment loadout that exposes equipped item ability data.
@export var equipment_loadout_path: NodePath = NodePath("../EquipmentLoadout")
## Optional energy pool used by equipment abilities.
@export var resource_pool_path: NodePath = NodePath("../Mana")
## Optional debug ring that visualizes `aggro_radius`.
@export var debug_aggro_zone_path: NodePath = NodePath("../DebugAggroZone")
## Optional debug ring that visualizes the home-centered de-aggro/leash radius.
@export var debug_deaggro_zone_path: NodePath = NodePath("../DebugLeashZone")

@export_group("Aggro")
## Distance from the mob where players first pull aggro.
@export_range(0.5, 30.0, 0.1) var aggro_radius := 4.0
## Maximum distance from the home point before the mob drops aggro and returns.
@export_range(1.0, 60.0, 0.1) var leash_radius := 4.0
## Distance from home where the mob stops returning and idles.
@export_range(0.05, 2.0, 0.01) var home_arrival_distance := 0.18
## Shows the aggro radius as a debug ground ring.
@export var debug_show_aggro_zone := false
## Shows the home-centered de-aggro/leash radius as a debug ground ring.
@export var debug_show_deaggro_zone := false

@export_group("Movement")
@export_range(0.1, 12.0, 0.1) var movement_speed := 3.2
@export_range(0.1, 80.0, 0.1) var acceleration := 10.0
@export_range(0.1, 80.0, 0.1) var deceleration := 16.0
## Distance where the mob starts easing into its destination instead of snapping.
@export_range(0.05, 5.0, 0.05) var slowdown_distance := 0.8
## Radians per second used when turning the visual model toward movement/target.
@export_range(0.1, 40.0, 0.1) var turn_speed := 10.0
## Distance the mob tries to stand from its target.
@export_range(0.1, 5.0, 0.05) var approach_distance := 1.25

@export_group("Combat")
@export_range(0.1, 5.0, 0.05) var attack_range := 1.6
@export_range(0.0, 500.0, 1.0) var attack_damage := 20.0
## Attacks per second. This also drives attack animation speed.
@export_range(0.1, 5.0, 0.05) var attack_speed := 1.0

@export_group("Equipment Abilities")
## Equipment sources keyed by ability slot. Weapons own Q/W/E, chest R, head D, boots F.
@export var ability_equipment_slots: Dictionary = (
	AbilitySlots.EQUIPMENT_SLOT_BY_ABILITY.duplicate()
)
## Briefly holds a chosen combat ability so mobs do not react on the exact decision frame.
@export_range(0.0, 2.0, 0.05) var ability_reaction_delay_seconds := 0.3
## Defensive self-casts are saved until the mob has actually been pressured.
@export_range(0.05, 1.0, 0.05) var defensive_ability_health_ratio := 0.5
## Mobs use healing/restoration channels only after combat drops.
@export_range(0.05, 1.0, 0.05) var recovery_ability_health_ratio := 0.55
## Dodge rolls become defensive at low health and offensive as a gap closer.
@export_range(0.05, 1.0, 0.05) var dodge_ability_health_ratio := 0.45
@export_range(0.1, 5.0, 0.05) var defensive_dodge_distance := 1.4
## Shows hostile ground warnings while mob equipment abilities are winding up.
@export var show_hostile_ability_telegraphs := true
## Radius used for selected-target warnings when an ability has no wider hint.
@export_range(0.2, 5.0, 0.05) var target_ability_telegraph_radius := 1.1

@export_group("Death")
## Minimum time the defeated body stays visible before hiding for respawn.
@export_range(0.0, 5.0, 0.05) var minimum_death_visible_time := 1.2

@export_group("Respawn")
## Seconds after defeat before this mob reappears at its home position.
@export_range(0.0, 300.0, 0.1) var respawn_delay := 30.0
## Hides the full mob tree while waiting to respawn.
@export var hide_while_defeated := true

var _body: CharacterBody3D
var _health: Node
var _stats: Node
var _animation: Node
var _selectable: Node
var _visuals: Node3D
var _loot_dropper: Node
var _equipment_loadout: Node
var _resource_pool: Node
var _debug_aggro_zone: Node
var _debug_deaggro_zone: Node
var _target: Node3D
var _collision_shapes: Array[CollisionShape3D] = []
var _home_position := Vector3.ZERO
var _cooldown_remaining := 0.0
var _pending_ability_reaction_id := ""
var _ability_reaction_remaining_seconds := 0.0
var _original_collision_layer := 0
var _original_collision_mask := 0
var _is_respawning := false
var _suppress_next_loot_drop := false
var _network_control_timeout := 0.0
var _damage_resolver = DamageResolverScript.new()
var _ability_timeline = AttackTimelineScript.new()
var _ability_impact_schedule = AbilityImpactScheduleScript.new()
var _active_definitions: Dictionary = {}
var _active_definition_paths: Dictionary = {}
var _ability_cooldowns_by_id: Dictionary = {}
var _ability_cast_slot: StringName = &""
var _ability_cast_target: Node
var _ability_cast_definition: Resource
var _ability_cast_direction := Vector3.ZERO
var _ability_cast_movement_distance := 0.0
var _ability_cast_landing_position := Vector3.ZERO
var _ability_movement_remaining_seconds := 0.0
var _ability_movement_speed := 0.0
var _dodge_slot: StringName = &""
var _dodge_definition: Resource
var _dodge_direction := Vector3.ZERO
var _dodge_remaining_seconds := 0.0
var _dodge_speed := 0.0
var _channel_slot: StringName = &""
var _channel_definition: Resource
var _channel_remaining_seconds := 0.0
var _channel_tick_count := 0
var _active_ability_telegraph: Node3D


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_warning("EnemyMobAI must be a child of a CharacterBody3D.")
		return

	_body.add_to_group("network_mobs")
	_home_position = _body.global_position
	_original_collision_layer = _body.collision_layer
	_original_collision_mask = _body.collision_mask
	_health = get_node_or_null(health_path)
	_stats = get_node_or_null(stats_path)
	_animation = get_node_or_null(animation_path)
	_selectable = get_node_or_null(selectable_path)
	_visuals = get_node_or_null(visuals_path) as Node3D
	_loot_dropper = get_node_or_null(loot_dropper_path)
	_equipment_loadout = get_node_or_null(equipment_loadout_path)
	_resource_pool = get_node_or_null(resource_pool_path)
	_debug_aggro_zone = get_node_or_null(debug_aggro_zone_path)
	_debug_deaggro_zone = get_node_or_null(debug_deaggro_zone_path)
	_collect_collision_shapes(_body)

	if _health != null and _health.has_signal("defeated"):
		_health.defeated.connect(_on_defeated)
	if _health != null and _health.has_signal("damage_taken"):
		_health.damage_taken.connect(_on_damage_taken)
	_connect_equipment_loadout()
	_refresh_equipped_abilities(true)
	_connect_stats_signals()
	_sync_health_stats(true)
	_sync_debug_zones(true)


func _process(_delta: float) -> void:
	_sync_debug_zones()


func _physics_process(delta: float) -> void:
	if _network_control_timeout > 0.0:
		_network_control_timeout = maxf(_network_control_timeout - delta, 0.0)
		return
	if _body == null or _is_respawning or _is_self_defeated():
		return

	_advance_ability_cooldowns(delta)
	_advance_ability_reaction(delta)
	if _update_active_ability(delta):
		return

	if _has_target():
		_update_aggro(delta)
		return

	if _try_out_of_combat_recovery_ability():
		return

	_target = _find_aggro_target()
	if _target != null:
		_cooldown_remaining = 0.0
		aggro_started.emit(_target)
		_update_aggro(delta)
		return

	_return_home_or_idle(delta)


func _update_aggro(delta: float) -> void:
	if not _has_target() or _is_target_defeated(_target):
		_drop_aggro()
		_return_home_or_idle(delta)
		return

	if _distance_from_home() > leash_radius:
		_drop_aggro()
		_return_home_or_idle(delta)
		return

	var distance_to_target := _horizontal_distance_to(_target.global_position)
	var self_ability_result := _attempt_combat_self_ability()
	if self_ability_result != AbilityAttemptResult.NONE:
		_stop_moving(delta)
		_face_direction(_direction_to(_target.global_position), delta)
		return

	var dodge_ability_result := _attempt_combat_dodge_ability(distance_to_target)
	if dodge_ability_result == AbilityAttemptResult.WAITING:
		_stop_moving(delta)
		_face_direction(_direction_to(_target.global_position), delta)
		return
	if dodge_ability_result == AbilityAttemptResult.STARTED:
		return

	var ready_damage_ability := _best_ready_damage_ability()
	var ready_damage_ability_range := (
		_ability_activation_range(ready_damage_ability)
		if ready_damage_ability != null
		else 0.0
	)
	var desired_attack_range := maxf(attack_range, ready_damage_ability_range)
	if distance_to_target <= desired_attack_range:
		_stop_moving(delta)
		_face_direction(_direction_to(_target.global_position), delta)
		var damage_ability_result := _attempt_damage_ability(ready_damage_ability)
		if damage_ability_result != AbilityAttemptResult.NONE:
			return
		_clear_ability_reaction()
		if distance_to_target > attack_range:
			return
		_update_attack(delta)
		return

	var chase_distance := approach_distance
	if ready_damage_ability != null:
		chase_distance = float(ready_damage_ability.get("approach_distance"))
	var chase_destination := _target.global_position - _direction_to(_target.global_position) * chase_distance
	chase_destination.y = _body.global_position.y
	_clear_ability_reaction()
	_move_toward(chase_destination, delta)


func _update_attack(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining > 0.0:
		return

	var target_health := _find_health(_target)
	if target_health == null or not target_health.has_method("apply_damage"):
		_drop_aggro()
		return

	var attack_speed_value := _attack_speed()
	if _animation != null and _animation.has_method("play_attack"):
		_animation.call("play_attack", attack_speed_value)
	attack_started.emit(_target, attack_speed_value)

	var request := DamageRequestScript.create(
		_body if _body != null else self,
		_target,
		_attack_damage(),
		DamageRequestScript.TYPE_PHYSICAL,
		target_health
	)
	var result := _damage_resolver.resolve(request)
	_cooldown_remaining = _attack_interval()
	if not result.was_applied():
		return

	attack_landed.emit(_target, result.applied_damage)


func _return_home_or_idle(delta: float) -> void:
	if _horizontal_distance_to(_home_position) > home_arrival_distance:
		_move_toward(_home_position, delta)
		return

	_stop_moving(delta)
	_body.global_position.y = _home_position.y


func _move_toward(destination: Vector3, delta: float) -> void:
	var direction := _direction_to(destination)
	if direction == Vector3.ZERO:
		_stop_moving(delta)
		return

	var distance := _horizontal_distance_to(destination)
	var speed_ratio := clampf(distance / maxf(slowdown_distance, 0.01), 0.0, 1.0)
	var target_velocity := direction * _movement_speed() * speed_ratio
	var horizontal_velocity := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	_body.velocity.x = horizontal_velocity.x
	_body.velocity.y = 0.0
	_body.velocity.z = horizontal_velocity.z
	_body.move_and_slide()

	_face_direction(direction, delta)
	var is_still_moving := Vector2(_body.velocity.x, _body.velocity.z).length_squared() > 0.0025
	_set_moving_animation(is_still_moving)


func _stop_moving(delta: float) -> void:
	var horizontal_velocity := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, deceleration * delta)
	_body.velocity.x = horizontal_velocity.x
	_body.velocity.y = 0.0
	_body.velocity.z = horizontal_velocity.z
	_body.move_and_slide()

	var is_still_moving := Vector2(_body.velocity.x, _body.velocity.z).length_squared() > 0.0025
	_set_moving_animation(is_still_moving)


func _find_aggro_target() -> Node3D:
	if not is_inside_tree():
		return null

	var closest_target: Node3D = null
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group(target_group):
		var candidate_3d := candidate as Node3D
		if candidate_3d == null or _is_target_defeated(candidate_3d):
			continue

		var distance := _horizontal_distance_to(candidate_3d.global_position)
		if distance <= aggro_radius and distance < closest_distance:
			closest_target = candidate_3d
			closest_distance = distance

	return closest_target


func _drop_aggro() -> void:
	_clear_ability_reaction()
	if _target == null:
		return

	_target = null
	_cooldown_remaining = 0.0
	aggro_dropped.emit()


func _on_defeated() -> void:
	if _is_respawning:
		return

	_drop_aggro()
	_reset_active_ability_state()
	if _body != null:
		_body.velocity = Vector3.ZERO
	if _animation != null and _animation.has_method("set_moving"):
		_animation.call("set_moving", false)
	_begin_respawn()


func _begin_respawn() -> void:
	_is_respawning = true
	_set_defeated_state(true, false)
	_drop_loot()

	var death_duration := _play_death_animation()
	var visible_duration := maxf(death_duration, minimum_death_visible_time)
	if visible_duration > 0.0:
		await get_tree().create_timer(visible_duration).timeout
		if not is_inside_tree():
			return

	if hide_while_defeated and _body != null:
		_body.visible = false

	var remaining_respawn_delay := maxf(respawn_delay - visible_duration, 0.0)
	if remaining_respawn_delay <= 0.0:
		_respawn()
		return

	await get_tree().create_timer(remaining_respawn_delay).timeout
	if not is_inside_tree():
		return

	_respawn()


func _respawn() -> void:
	if not _is_respawning:
		return

	_drop_aggro()
	if _body != null:
		_body.global_position = _home_position
		_body.velocity = Vector3.ZERO
	if _health != null and _health.has_method("reset_to_full"):
		_health.call("reset_to_full")

	_set_defeated_state(false)
	if _animation != null and _animation.has_method("reset_animation_state"):
		_animation.call("reset_animation_state")

	_cooldown_remaining = 0.0
	_reset_active_ability_state()
	_is_respawning = false
	_sync_debug_zones(true)
	respawned.emit()


## Restores visible/collidable state when the server replicates a mob respawn.
func apply_network_alive_state() -> void:
	if _body == null:
		return
	if not _is_respawning and _body.visible:
		return

	_drop_aggro()
	_is_respawning = false
	_body.global_position = _home_position
	_body.velocity = Vector3.ZERO
	_set_defeated_state(false)
	if _animation != null and _animation.has_method("reset_animation_state"):
		_animation.call("reset_animation_state")
	_cooldown_remaining = 0.0
	_reset_active_ability_state()
	_sync_debug_zones(true)
	respawned.emit()


## Prevents replicated death visuals from spawning local-only loot copies.
func suppress_next_network_loot_drop() -> void:
	_suppress_next_loot_drop = true


## Returns compact state for the temporary playtest mob animation sync.
func get_network_state() -> Dictionary:
	var visual_yaw := _visuals.global_rotation.y if _visuals != null else 0.0
	var is_moving := (
		_body != null
		and Vector2(_body.velocity.x, _body.velocity.z).length_squared() > 0.0025
	)
	return {
		"position": _body.global_position if _body != null else Vector3.ZERO,
		"visual_yaw": visual_yaw,
		"is_moving": is_moving,
	}


## Returns true while this client has meaningful mob motion to share.
func has_network_activity() -> bool:
	if _body == null or _is_respawning or _is_self_defeated():
		return false

	return (
		_has_target()
		or Vector2(_body.velocity.x, _body.velocity.z).length_squared() > 0.0025
	)


## Applies movement/facing from another peer and briefly pauses local AI drift.
func apply_network_motion_state(position: Vector3, visual_yaw: float, is_moving: bool) -> void:
	if _body == null or _is_respawning or _is_self_defeated():
		return

	_network_control_timeout = 0.35
	_body.global_position = position
	_body.velocity = Vector3.ZERO
	if _visuals != null:
		_visuals.global_rotation.y = visual_yaw
	_set_moving_animation(is_moving)


## Plays an attack animation reported by the peer currently fighting this mob.
func play_network_attack(speed_scale: float = 1.0) -> void:
	if _animation == null or _is_respawning or _is_self_defeated():
		return

	_network_control_timeout = maxf(_network_control_timeout, 0.35)
	if _animation.has_method("play_attack"):
		_animation.call("play_attack", speed_scale)


func get_active_ability(slot_id: StringName) -> Resource:
	return _active_definitions.get(String(slot_id)) as Resource


func get_ability_cooldown_remaining(slot_id: StringName) -> float:
	var definition := get_active_ability(slot_id)
	if definition == null:
		return 0.0
	return maxf(float(_ability_cooldowns_by_id.get(String(definition.get("ability_id")), 0.0)), 0.0)


func get_ability_cooldown_total(slot_id: StringName) -> float:
	var definition := get_active_ability(slot_id)
	return maxf(float(definition.get("cooldown_seconds")), 0.0) if definition != null else 0.0


func _connect_equipment_loadout() -> void:
	if _equipment_loadout == null or not _equipment_loadout.has_signal("equipped_slots_changed"):
		return

	var callable := Callable(self, "_on_equipped_slots_changed")
	if not _equipment_loadout.is_connected("equipped_slots_changed", callable):
		_equipment_loadout.connect("equipped_slots_changed", callable)


func _on_equipped_slots_changed() -> void:
	_refresh_equipped_abilities()


func _refresh_equipped_abilities(force_refresh := false) -> void:
	var next_paths := {}
	for raw_slot_id in ability_equipment_slots:
		var slot_id := String(raw_slot_id).strip_edges().to_lower()
		var equipment_slot_id := String(ability_equipment_slots[raw_slot_id])
		if slot_id.is_empty() or equipment_slot_id.is_empty():
			continue

		var equipped_item := {}
		if _equipment_loadout != null and _equipment_loadout.has_method("get_equipped_slot"):
			equipped_item = _equipment_loadout.call("get_equipped_slot", equipment_slot_id)

		var ability_paths := equipped_item.get("ability_paths", {}) as Dictionary
		var definition_path := String(ability_paths.get(slot_id, "")) if ability_paths != null else ""
		if definition_path.is_empty() and slot_id == "q":
			definition_path = String(equipped_item.get("q_ability_path", ""))
		next_paths[slot_id] = definition_path

	if not force_refresh and next_paths == _active_definition_paths:
		return

	_reset_active_ability_state()
	_active_definition_paths = next_paths
	_active_definitions.clear()
	for slot_key in _active_definition_paths:
		var definition_path := String(_active_definition_paths[slot_key])
		if definition_path.is_empty() or not ResourceLoader.exists(definition_path):
			continue
		var definition := load(definition_path) as Resource
		if definition != null:
			_active_definitions[String(slot_key)] = definition


func _advance_ability_cooldowns(delta: float) -> void:
	var elapsed := maxf(delta, 0.0)
	if elapsed <= 0.0:
		return

	for raw_ability_id in _ability_cooldowns_by_id.keys():
		var previous := maxf(float(_ability_cooldowns_by_id[raw_ability_id]), 0.0)
		var remaining := maxf(previous - elapsed, 0.0)
		if remaining <= 0.0:
			_ability_cooldowns_by_id.erase(raw_ability_id)
		else:
			_ability_cooldowns_by_id[raw_ability_id] = remaining


func _update_active_ability(delta: float) -> bool:
	if _update_dodge_ability(delta):
		return true
	if _update_channel_ability(delta):
		return true
	if _ability_timeline.is_ready():
		return false

	if not _update_directional_damage_movement(delta):
		_stop_moving(delta)
	var target_3d := _ability_cast_target as Node3D
	if _targeting_mode(_ability_cast_definition) == TARGETING_DIRECTION:
		_face_direction(_ability_cast_direction, delta)
	elif target_3d != null and is_instance_valid(target_3d):
		_face_direction(_direction_to(target_3d.global_position), delta)

	if (
		_ability_timeline.is_winding_up()
		and _targeting_mode(_ability_cast_definition) == TARGETING_SELECTED
		and not _can_complete_current_ability()
	):
		_interrupt_current_ability("Target lost")

	var timeline_event: int = _ability_timeline.advance(delta)
	var crossed_impacts := _ability_impact_schedule.advance(delta)
	if _execution_type(_ability_cast_definition) == EXECUTION_DAMAGE:
		for impact_index in crossed_impacts:
			_resolve_ability_impact(impact_index)
	if timeline_event == AttackTimelineScript.TimelineEvent.READY or _ability_timeline.is_ready():
		_finish_current_ability()
	return true


func _attempt_combat_self_ability() -> int:
	if _health_ratio() > defensive_ability_health_ratio or _has_active_absorb_shield():
		return AbilityAttemptResult.NONE

	for slot_id in AbilitySlots.ACTIVE_SLOT_IDS:
		var definition := get_active_ability(slot_id)
		if (
			definition != null
			and _targeting_mode(definition) == TARGETING_SELF
			and _execution_type(definition) == EXECUTION_SHIELD
			and _can_begin_mob_ability(slot_id, definition)
		):
			if _should_wait_for_ability_reaction(definition):
				return AbilityAttemptResult.WAITING
			return _started_ability_result(_begin_self_ability(slot_id, definition))
	return AbilityAttemptResult.NONE


func _try_out_of_combat_recovery_ability() -> bool:
	if _health_ratio() > recovery_ability_health_ratio:
		return false
	if _find_aggro_target() != null:
		return false

	for slot_id in AbilitySlots.ACTIVE_SLOT_IDS:
		var definition := get_active_ability(slot_id)
		if (
			definition != null
			and _targeting_mode(definition) == TARGETING_SELF
			and _execution_type(definition) == EXECUTION_REGENERATION
			and _can_begin_mob_ability(slot_id, definition)
		):
			_stop_moving(0.0)
			return _begin_self_ability(slot_id, definition)
	return false


func _attempt_combat_dodge_ability(distance_to_target: float) -> int:
	var definition := _best_ready_dodge_ability()
	if definition == null or not _has_target():
		return AbilityAttemptResult.NONE

	var direction := Vector3.ZERO
	var target_direction := _direction_to(_target.global_position)
	var movement_distance := maxf(float(definition.get("movement_distance")), 0.0)
	if _health_ratio() <= dodge_ability_health_ratio and distance_to_target <= defensive_dodge_distance:
		direction = -target_direction
	elif distance_to_target > attack_range and distance_to_target <= movement_distance + attack_range:
		direction = target_direction
	if direction == Vector3.ZERO:
		return AbilityAttemptResult.NONE

	if _should_wait_for_ability_reaction(definition):
		return AbilityAttemptResult.WAITING
	return _started_ability_result(
		_begin_dodge_ability(_slot_for_definition(definition), definition, direction)
	)


func _attempt_damage_ability(preferred_definition: Resource = null) -> int:
	var definition := preferred_definition
	if definition == null:
		definition = _best_ready_damage_ability()
	if definition == null or not _has_target():
		return AbilityAttemptResult.NONE
	if not _is_target_in_ability_activation_range(definition, _target):
		return AbilityAttemptResult.NONE
	if _should_wait_for_ability_reaction(definition):
		return AbilityAttemptResult.WAITING

	var slot_id := _slot_for_definition(definition)
	if _targeting_mode(definition) == TARGETING_DIRECTION:
		return _started_ability_result(
			_begin_direction_damage_ability(
				slot_id,
				definition,
				_direction_to(_target.global_position)
			)
		)
	return _started_ability_result(
		_begin_target_ability(slot_id, _target, definition)
	)


func _best_ready_damage_ability() -> Resource:
	if not _has_target():
		return null

	var fallback: Resource = null
	var gap_closer: Resource = null
	for slot_id in AbilitySlots.ACTIVE_SLOT_IDS:
		var definition := get_active_ability(slot_id)
		if (
			definition != null
			and _execution_type(definition) == EXECUTION_DAMAGE
			and _targeting_mode(definition) in [TARGETING_SELECTED, TARGETING_DIRECTION]
			and _can_begin_mob_ability(slot_id, definition)
		):
			if (
				_targeting_mode(definition) == TARGETING_DIRECTION
				and _directional_target_count(
					definition,
					_direction_to(_target.global_position)
				) >= 2
			):
				return definition
			if _is_useful_directional_gap_closer(definition):
				gap_closer = definition
			if (
				_targeting_mode(definition) == TARGETING_DIRECTION
				and maxf(float(definition.get("movement_distance")), 0.0) > 0.0
			):
				continue
			if fallback == null:
				fallback = definition
	return gap_closer if gap_closer != null else fallback


func _best_ready_dodge_ability() -> Resource:
	for slot_id in AbilitySlots.ACTIVE_SLOT_IDS:
		var definition := get_active_ability(slot_id)
		if (
			definition != null
			and _targeting_mode(definition) == TARGETING_DIRECTION
			and _execution_type(definition) == EXECUTION_DODGE
			and _can_begin_mob_ability(slot_id, definition)
		):
			return definition
	return null


func _begin_target_ability(slot_id: StringName, target: Node, definition: Resource) -> bool:
	var cast_duration := maxf(float(definition.get("cast_duration_seconds")), 0.01)
	var impact_fraction := AbilityImpactScheduleScript.first_impact_fraction(definition)
	if not _ability_timeline.begin(cast_duration, impact_fraction, 0.0, cast_duration):
		return false
	if not _pay_ability_cost(definition):
		_ability_timeline.reset()
		ability_cast_interrupted.emit(slot_id, target, "Not enough resource")
		return false

	_ability_cast_slot = slot_id
	_ability_cast_target = target
	_ability_cast_definition = definition
	_ability_cast_direction = Vector3.ZERO
	_ability_impact_schedule.begin(definition, cast_duration)
	_start_ability_cooldown(definition)
	_show_target_ability_telegraph(target, definition, _telegraph_warning_duration(definition, cast_duration))
	_play_ability_animation(definition, cast_duration)
	ability_cast_started.emit(slot_id, target, definition)
	attack_started.emit(target, 1.0 / cast_duration)
	return true


func _begin_direction_damage_ability(
	slot_id: StringName,
	definition: Resource,
	direction: Vector3
) -> bool:
	var safe_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if safe_direction == Vector3.ZERO:
		return false

	var cast_duration := maxf(float(definition.get("cast_duration_seconds")), 0.01)
	var impact_fraction := AbilityImpactScheduleScript.first_impact_fraction(definition)
	if not _ability_timeline.begin(cast_duration, impact_fraction, 0.0, cast_duration):
		return false
	if not _pay_ability_cost(definition):
		_ability_timeline.reset()
		ability_cast_interrupted.emit(slot_id, _target, "Not enough resource")
		return false

	_ability_cast_slot = slot_id
	_ability_cast_target = _target
	_ability_cast_definition = definition
	_ability_cast_direction = safe_direction
	_ability_cast_movement_distance = _directional_damage_movement_distance(definition)
	_ability_cast_landing_position = (
		_body.global_position + safe_direction * _ability_cast_movement_distance
	)
	_ability_impact_schedule.begin(definition, cast_duration)
	_begin_directional_damage_movement(
		_ability_cast_movement_distance,
		cast_duration,
		impact_fraction
	)
	_start_ability_cooldown(definition)
	_show_direction_damage_telegraph(definition, safe_direction, 0)
	_play_ability_animation(definition, cast_duration)
	ability_cast_started.emit(slot_id, _target, definition)
	attack_started.emit(_target, 1.0 / cast_duration)
	return true


func _begin_self_ability(slot_id: StringName, definition: Resource) -> bool:
	if not _pay_ability_cost(definition):
		ability_cast_interrupted.emit(slot_id, _body, "Not enough resource")
		return false

	_start_ability_cooldown(definition)
	ability_cast_started.emit(slot_id, _body, definition)
	match _execution_type(definition):
		EXECUTION_SHIELD:
			_apply_ability_protection(definition)
			_apply_missing_resource_restore(definition)
			ability_cast_finished.emit(slot_id)
			return true
		EXECUTION_REGENERATION:
			_channel_slot = slot_id
			_channel_definition = definition
			_channel_remaining_seconds = maxf(float(definition.get("cast_duration_seconds")), 0.01)
			_channel_tick_count = 0
			return true

	return false


func _begin_dodge_ability(slot_id: StringName, definition: Resource, direction: Vector3) -> bool:
	var safe_direction := direction.normalized()
	if safe_direction == Vector3.ZERO or not _pay_ability_cost(definition):
		return false

	var duration := maxf(float(definition.get("cast_duration_seconds")), 0.01)
	var distance := maxf(float(definition.get("movement_distance")), 0.0)
	_start_ability_cooldown(definition)
	_apply_ability_protection(definition)
	_dodge_slot = slot_id
	_dodge_definition = definition
	_dodge_direction = safe_direction
	_dodge_remaining_seconds = duration
	_dodge_speed = distance / duration
	_show_direction_ability_telegraph(definition, safe_direction, duration)
	_play_ability_animation(definition, duration)
	ability_cast_started.emit(slot_id, _target, definition)
	return true


func _update_dodge_ability(delta: float) -> bool:
	if _dodge_remaining_seconds <= 0.0 or _dodge_definition == null:
		return false

	_dodge_remaining_seconds = maxf(_dodge_remaining_seconds - maxf(delta, 0.0), 0.0)
	_body.velocity.x = _dodge_direction.x * _dodge_speed
	_body.velocity.y = 0.0
	_body.velocity.z = _dodge_direction.z * _dodge_speed
	_body.move_and_slide()
	_face_direction(_dodge_direction, delta)
	_set_moving_animation(true)

	if _dodge_remaining_seconds <= 0.0:
		var finished_slot := _dodge_slot
		_dodge_slot = &""
		_dodge_definition = null
		_dodge_direction = Vector3.ZERO
		_dodge_speed = 0.0
		_clear_ability_telegraph()
		ability_cast_finished.emit(finished_slot)
	return true


func _begin_directional_damage_movement(
	distance: float,
	cast_duration: float,
	impact_fraction: float
) -> void:
	var safe_distance := maxf(distance, 0.0)
	if safe_distance <= 0.0:
		_clear_directional_damage_movement()
		return
	var movement_duration := maxf(cast_duration * clampf(impact_fraction, 0.0, 1.0), 0.01)
	_ability_movement_remaining_seconds = movement_duration
	_ability_movement_speed = safe_distance / movement_duration


func _update_directional_damage_movement(delta: float) -> bool:
	if (
		_ability_movement_remaining_seconds <= 0.0
		or _ability_movement_speed <= 0.0
		or _ability_cast_direction == Vector3.ZERO
	):
		return false

	var frame_delta := maxf(delta, 0.0)
	if frame_delta <= 0.0:
		return true
	var elapsed := minf(frame_delta, _ability_movement_remaining_seconds)
	var final_frame_scale := elapsed / frame_delta
	_body.velocity.x = _ability_cast_direction.x * _ability_movement_speed * final_frame_scale
	_body.velocity.y = 0.0
	_body.velocity.z = _ability_cast_direction.z * _ability_movement_speed * final_frame_scale
	_body.move_and_slide()
	_ability_movement_remaining_seconds = maxf(
		_ability_movement_remaining_seconds - elapsed,
		0.0
	)
	_face_direction(_ability_cast_direction, delta)
	_set_moving_animation(true)
	return true


func _clear_directional_damage_movement() -> void:
	_ability_movement_remaining_seconds = 0.0
	_ability_movement_speed = 0.0


func _update_channel_ability(delta: float) -> bool:
	if _channel_definition == null:
		return false
	if _requires_out_of_combat(_channel_definition) and _find_aggro_target() != null:
		_interrupt_active_channel("Entered combat")
		return true

	_stop_moving(delta)
	_channel_remaining_seconds = maxf(_channel_remaining_seconds - maxf(delta, 0.0), 0.0)
	var tick_interval := maxf(float(_channel_definition.get("channel_tick_interval_seconds")), 0.05)
	var duration := maxf(float(_channel_definition.get("cast_duration_seconds")), 0.01)
	var elapsed := clampf(duration - _channel_remaining_seconds, 0.0, duration)
	var maximum_tick_count := floori((duration + 0.0001) / tick_interval)
	var elapsed_tick_count := mini(
		floori((elapsed + 0.0001) / tick_interval),
		maximum_tick_count
	)
	while _channel_tick_count < elapsed_tick_count:
		_channel_tick_count += 1
		_apply_regeneration_tick(_channel_definition)

	if _channel_remaining_seconds <= 0.0:
		var finished_slot := _channel_slot
		_clear_channel_state()
		ability_cast_finished.emit(finished_slot)
	return true


func _resolve_ability_impact(impact_index: int) -> void:
	if _targeting_mode(_ability_cast_definition) == TARGETING_DIRECTION:
		_resolve_directional_ability_impact(impact_index)
		var next_impact_index := impact_index + 1
		if next_impact_index < _ability_impact_schedule.get_impact_count():
			_show_direction_damage_telegraph(
				_ability_cast_definition,
				_ability_cast_direction,
				next_impact_index
			)
		else:
			_clear_ability_telegraph()
		return

	var impact_target := _ability_cast_target
	_clear_ability_telegraph()
	if not _can_complete_current_ability():
		ability_cast_interrupted.emit(_ability_cast_slot, impact_target, "Target left ability range")
		_ability_impact_schedule.reset()
		return

	_resolve_ability_damage(impact_target, impact_index)


func _resolve_directional_ability_impact(impact_index: int) -> void:
	if _body == null or _ability_cast_direction == Vector3.ZERO or not is_inside_tree():
		return

	for candidate in _directional_target_candidates():
		var target_3d := candidate as Node3D
		if target_3d == null or _is_target_defeated(target_3d):
			continue
		if not _is_target_in_directional_area(
			_ability_cast_definition,
			_ability_cast_direction,
			target_3d
		):
			continue
		_resolve_ability_damage(target_3d, impact_index)


func _resolve_ability_damage(impact_target: Node, impact_index: int) -> void:
	var target_health := _find_health(impact_target)
	if target_health == null or not target_health.has_method("apply_damage"):
		return

	var request := DamageRequestScript.create(
		_body if _body != null else self,
		impact_target,
		_ability_damage(_ability_cast_definition)
		* _ability_impact_schedule.get_damage_scale(impact_index),
		_ability_damage_type(_ability_cast_definition),
		target_health
	)
	var result := _damage_resolver.resolve(request)
	if result.was_applied():
		ability_cast_landed.emit(_ability_cast_slot, impact_target, result.applied_damage)
		attack_landed.emit(impact_target, result.applied_damage)


func _finish_current_ability() -> void:
	var finished_slot := _ability_cast_slot
	_clear_directional_damage_movement()
	_ability_cast_movement_distance = 0.0
	_ability_cast_landing_position = Vector3.ZERO
	_ability_cast_slot = &""
	_ability_cast_target = null
	_ability_cast_definition = null
	_ability_cast_direction = Vector3.ZERO
	_ability_impact_schedule.reset()
	_clear_ability_telegraph()
	ability_cast_finished.emit(finished_slot)


func _interrupt_current_ability(reason: String) -> void:
	if not _ability_timeline.interrupt_windup():
		return
	var interrupted_slot := _ability_cast_slot
	var interrupted_target := _ability_cast_target
	_clear_directional_damage_movement()
	_ability_cast_movement_distance = 0.0
	_ability_cast_landing_position = Vector3.ZERO
	_ability_impact_schedule.reset()
	_clear_ability_telegraph()
	ability_cast_interrupted.emit(interrupted_slot, interrupted_target, reason)


func _interrupt_active_channel(reason: String) -> void:
	var interrupted_slot := _channel_slot
	_clear_channel_state()
	ability_cast_interrupted.emit(interrupted_slot, _body, reason)


func _clear_channel_state() -> void:
	_channel_slot = &""
	_channel_definition = null
	_channel_remaining_seconds = 0.0
	_channel_tick_count = 0


func _reset_active_ability_state() -> void:
	_ability_timeline.reset()
	_ability_impact_schedule.reset()
	_ability_cooldowns_by_id.clear()
	_clear_ability_reaction()
	_ability_cast_slot = &""
	_ability_cast_target = null
	_ability_cast_definition = null
	_ability_cast_direction = Vector3.ZERO
	_ability_cast_movement_distance = 0.0
	_ability_cast_landing_position = Vector3.ZERO
	_clear_directional_damage_movement()
	_dodge_slot = &""
	_dodge_definition = null
	_dodge_direction = Vector3.ZERO
	_dodge_remaining_seconds = 0.0
	_dodge_speed = 0.0
	_clear_ability_telegraph()
	_clear_channel_state()


func _advance_ability_reaction(delta: float) -> void:
	_ability_reaction_remaining_seconds = maxf(
		_ability_reaction_remaining_seconds - maxf(delta, 0.0),
		0.0
	)


func _should_wait_for_ability_reaction(definition: Resource) -> bool:
	var reaction_delay := maxf(ability_reaction_delay_seconds, 0.0)
	var ability_id := String(definition.get("ability_id")) if definition != null else ""
	if reaction_delay <= 0.0 or ability_id.is_empty():
		_clear_ability_reaction()
		return false

	if _pending_ability_reaction_id != ability_id:
		_pending_ability_reaction_id = ability_id
		_ability_reaction_remaining_seconds = reaction_delay

	if _ability_reaction_remaining_seconds > 0.0:
		return true

	_clear_ability_reaction()
	return false


func _clear_ability_reaction() -> void:
	_pending_ability_reaction_id = ""
	_ability_reaction_remaining_seconds = 0.0


func _started_ability_result(did_start: bool) -> int:
	return AbilityAttemptResult.STARTED if did_start else AbilityAttemptResult.NONE


func _start_ability_cooldown(definition: Resource) -> void:
	var ability_id := String(definition.get("ability_id"))
	if ability_id.is_empty():
		return
	_ability_cooldowns_by_id[ability_id] = maxf(float(definition.get("cooldown_seconds")), 0.0)


func _can_begin_mob_ability(slot_id: StringName, definition: Resource) -> bool:
	return (
		definition != null
		and _body != null
		and not _is_self_defeated()
		and _ability_timeline.is_ready()
		and _dodge_definition == null
		and _channel_definition == null
		and get_ability_cooldown_remaining(slot_id) <= 0.0
		and _can_pay_ability_cost(definition)
		and (not _requires_out_of_combat(definition) or not _has_target())
	)


func _can_complete_current_ability() -> bool:
	if _ability_cast_definition == null or _ability_cast_target == null:
		return false
	if _is_target_defeated(_ability_cast_target):
		return false
	return _is_target_in_ability_range(
		_ability_cast_definition,
		_ability_cast_target,
		maxf(float(_ability_cast_definition.get("impact_range_leeway")), 0.0)
	)


func _can_pay_ability_cost(definition: Resource) -> bool:
	var cost := maxf(float(definition.get("energy_cost")), 0.0)
	if cost <= 0.0:
		return true
	return (
		_resource_pool != null
		and _resource_pool.has_method("can_spend")
		and bool(_resource_pool.call("can_spend", cost))
	)


func _pay_ability_cost(definition: Resource) -> bool:
	var cost := maxf(float(definition.get("energy_cost")), 0.0)
	if cost <= 0.0:
		return true
	return (
		_resource_pool != null
		and _resource_pool.has_method("try_spend")
		and bool(_resource_pool.call("try_spend", cost))
	)


func _apply_ability_protection(definition: Resource) -> void:
	if _health == null:
		return
	var immunity_seconds := maxf(float(definition.get("damage_immunity_seconds")), 0.0)
	if immunity_seconds > 0.0 and _health.has_method("grant_damage_immunity"):
		_health.call("grant_damage_immunity", immunity_seconds)

	var shield_amount := maxf(float(definition.get("absorb_shield_amount")), 0.0)
	var shield_seconds := maxf(float(definition.get("absorb_shield_duration_seconds")), 0.0)
	if shield_amount > 0.0 and shield_seconds > 0.0 and _health.has_method("grant_absorb_shield"):
		_health.call("grant_absorb_shield", shield_amount, shield_seconds)


func _apply_missing_resource_restore(definition: Resource) -> void:
	if _resource_pool == null or not _resource_pool.has_method("restore"):
		return
	var restore_percent := maxf(float(definition.get("missing_energy_restore_percent")), 0.0)
	if restore_percent <= 0.0:
		return

	var max_resource := maxf(float(_resource_pool.get("max_resource")), 0.0)
	var current_resource := clampf(float(_resource_pool.get("current_resource")), 0.0, max_resource)
	var missing_resource := maxf(max_resource - current_resource, 0.0)
	_resource_pool.call("restore", missing_resource * restore_percent / 100.0)


func _apply_regeneration_tick(definition: Resource) -> void:
	if definition == null:
		return
	if _health != null and _health.has_method("heal"):
		var max_health := maxf(float(_health.get("max_health")), 0.0)
		_health.call(
			"heal",
			max_health * maxf(float(definition.get("health_restore_percent_per_tick")), 0.0) / 100.0
		)
	if _resource_pool != null and _resource_pool.has_method("restore"):
		var max_resource := maxf(float(_resource_pool.get("max_resource")), 0.0)
		_resource_pool.call(
			"restore",
			max_resource * maxf(float(definition.get("energy_restore_percent_per_tick")), 0.0) / 100.0
		)


func _play_ability_animation(definition: Resource, duration_seconds: float) -> void:
	if _animation == null or definition == null:
		return
	if _animation.has_method("play_weapon_ability"):
		_animation.call(
			"play_weapon_ability",
			String(definition.get("animation_scene_path")),
			StringName(String(definition.get("animation_name"))),
			duration_seconds,
			StringName(String(definition.get("recovery_animation_name")))
		)
	elif _animation.has_method("play_attack"):
		_animation.call("play_attack", 1.0 / maxf(duration_seconds, 0.01))


func _show_target_ability_telegraph(target: Node, definition: Resource, duration_seconds: float) -> void:
	if not show_hostile_ability_telegraphs:
		return

	var target_3d := target as Node3D
	if target_3d == null:
		return

	var telegraph := _create_ability_telegraph()
	if telegraph == null:
		return

	if _uses_swing_telegraph(definition):
		var direction := _direction_to(target_3d.global_position)
		var radius := maxf(
			float(definition.get("attack_range")) if definition != null else 0.0,
			target_ability_telegraph_radius
		)
		telegraph.call("show_swing_arc", _body.global_position, direction, radius, duration_seconds)
	else:
		var radius := maxf(
			target_ability_telegraph_radius,
			maxf(float(definition.get("indicator_width")) * 0.5, 0.0) if definition != null else 0.0
		)
		telegraph.call("show_following_circle", target_3d, radius, duration_seconds)


func _show_direction_ability_telegraph(definition: Resource, direction: Vector3, duration_seconds: float) -> void:
	if not show_hostile_ability_telegraphs or _body == null or definition == null:
		return

	var telegraph := _create_ability_telegraph()
	if telegraph == null:
		return

	telegraph.call(
		"show_direction",
		_body.global_position,
		direction,
		maxf(float(definition.get("movement_distance")), 0.4),
		maxf(float(definition.get("indicator_width")), 0.2),
		duration_seconds
	)


func _show_direction_damage_telegraph(
	definition: Resource,
	direction: Vector3,
	impact_index: int
) -> void:
	if not show_hostile_ability_telegraphs or _body == null or definition == null:
		return

	var telegraph := _active_ability_telegraph
	if telegraph == null or not is_instance_valid(telegraph):
		telegraph = _create_ability_telegraph()
	if telegraph == null:
		return

	var previous_impact_index := impact_index - 1
	var warning_duration := maxf(
		_ability_impact_schedule.get_seconds_between_impacts(
			previous_impact_index,
			impact_index
		),
		0.05
	)
	var movement_distance := _ability_cast_movement_distance
	if movement_distance > 0.0:
		telegraph.call(
			"show_circle",
			_ability_cast_landing_position,
			maxf(float(definition.get("attack_range")), 0.35),
			warning_duration
		)
		return
	telegraph.call(
		"show_swing_arc",
		_body.global_position,
		direction,
		maxf(float(definition.get("attack_range")), 0.35),
		warning_duration,
		float(definition.get("area_arc_degrees")),
		impact_index % 2 == 1
	)


func _telegraph_warning_duration(definition: Resource, cast_duration: float) -> float:
	var safe_cast_duration := maxf(cast_duration, 0.05)
	if _execution_type(definition) == EXECUTION_DAMAGE:
		var impact_fraction := clampf(float(definition.get("impact_fraction")), 0.0, 1.0)
		return maxf(safe_cast_duration * impact_fraction, minf(safe_cast_duration, 0.2))

	return safe_cast_duration


func _uses_swing_telegraph(definition: Resource) -> bool:
	return definition != null and String(definition.get("ability_id")) == SWORD_SLASH_ABILITY_ID


func _create_ability_telegraph() -> Node3D:
	_clear_ability_telegraph()
	var parent := _telegraph_parent()
	if parent == null:
		return null

	var telegraph := AbilityTelegraphScript.new() as Node3D
	telegraph.name = "HostileAbilityTelegraph"
	parent.add_child(telegraph)
	_active_ability_telegraph = telegraph
	return telegraph


func _clear_ability_telegraph() -> void:
	if _active_ability_telegraph == null:
		return
	if is_instance_valid(_active_ability_telegraph):
		if _active_ability_telegraph.has_method("hide_telegraph"):
			_active_ability_telegraph.call("hide_telegraph")
		_active_ability_telegraph.queue_free()
	_active_ability_telegraph = null


func _telegraph_parent() -> Node:
	if _body != null and _body.get_parent() != null:
		return _body.get_parent()
	var tree := get_tree()
	if tree != null:
		return tree.current_scene
	return null


func _ability_damage(definition: Resource) -> float:
	if definition == null:
		return 0.0
	var ability_base_damage := maxf(float(definition.get("base_damage")), 0.0)
	var multiplier := maxf(float(definition.get("damage_multiplier")), 0.0)
	return maxf(ability_base_damage + _attack_damage() * multiplier, 0.0)


func _ability_damage_type(definition: Resource) -> StringName:
	if definition == null:
		return DamageRequestScript.TYPE_PHYSICAL
	return DamageRequestScript.normalize_damage_type(StringName(String(definition.get("damage_type"))))


func _slot_for_definition(definition: Resource) -> StringName:
	for slot_key in _active_definitions:
		if _active_definitions[slot_key] == definition:
			return StringName(String(slot_key))
	return StringName(String(definition.get("input_slot"))) if definition != null else &""


func _is_target_in_ability_range(definition: Resource, target: Node, extra_range := 0.0) -> bool:
	var target_3d := target as Node3D
	if _body == null or target_3d == null or definition == null:
		return false
	var offset := target_3d.global_position - _body.global_position
	offset.y = 0.0
	return offset.length() <= float(definition.get("attack_range")) + maxf(extra_range, 0.0)


func _ability_activation_range(definition: Resource) -> float:
	if definition == null:
		return 0.0
	var result := maxf(float(definition.get("attack_range")), 0.0)
	if (
		_targeting_mode(definition) == TARGETING_DIRECTION
		and _execution_type(definition) == EXECUTION_DAMAGE
	):
		result += maxf(float(definition.get("movement_distance")), 0.0)
	return result


func _directional_damage_movement_distance(definition: Resource) -> float:
	if definition == null:
		return 0.0
	var maximum_distance := maxf(float(definition.get("movement_distance")), 0.0)
	if not bool(definition.get("aim_landing_point")):
		return maximum_distance
	var target_3d := _target as Node3D
	if _body == null or target_3d == null:
		return maximum_distance
	return minf(_horizontal_distance_to(target_3d.global_position), maximum_distance)


func _is_target_in_ability_activation_range(definition: Resource, target: Node) -> bool:
	var target_3d := target as Node3D
	if _body == null or target_3d == null or definition == null:
		return false
	return _horizontal_distance_to(target_3d.global_position) <= _ability_activation_range(definition)


func _is_useful_directional_gap_closer(definition: Resource) -> bool:
	if (
		definition == null
		or _body == null
		or not _has_target()
		or _targeting_mode(definition) != TARGETING_DIRECTION
		or _execution_type(definition) != EXECUTION_DAMAGE
	):
		return false
	var movement_distance := maxf(float(definition.get("movement_distance")), 0.0)
	if movement_distance <= 0.0:
		return false
	var distance_to_target := _horizontal_distance_to(_target.global_position)
	var landing_radius := maxf(float(definition.get("attack_range")), 0.0)
	return distance_to_target > landing_radius and distance_to_target <= movement_distance + landing_radius


func _directional_target_count(definition: Resource, direction: Vector3) -> int:
	var count := 0
	var origin := _body.global_position if _body != null else Vector3.ZERO
	if definition != null:
		origin += direction.normalized() * _directional_damage_movement_distance(definition)
	for candidate in _directional_target_candidates():
		var target_3d := candidate as Node3D
		if (
			target_3d != null
			and not _is_target_defeated(target_3d)
			and _is_target_in_directional_area_from_origin(
				definition,
				direction,
				target_3d,
				origin
			)
		):
			count += 1
	return count


func _directional_target_candidates() -> Array[Node]:
	var candidates: Array[Node] = []
	if is_inside_tree():
		for candidate in get_tree().get_nodes_in_group(target_group):
			if candidate is Node and not candidates.has(candidate):
				candidates.append(candidate as Node)
	if _ability_cast_target != null and is_instance_valid(_ability_cast_target):
		if not candidates.has(_ability_cast_target):
			candidates.append(_ability_cast_target)
	return candidates


func _is_target_in_directional_area(
	definition: Resource,
	direction: Vector3,
	target: Node3D
) -> bool:
	if _body == null or definition == null or target == null:
		return false
	return _is_target_in_directional_area_from_origin(
		definition,
		direction,
		target,
		_body.global_position
	)


func _is_target_in_directional_area_from_origin(
	definition: Resource,
	direction: Vector3,
	target: Node3D,
	origin: Vector3
) -> bool:
	if definition == null or target == null:
		return false
	return AbilityTargetingMathScript.is_point_in_arc(
		origin,
		direction,
		target.global_position,
		maxf(float(definition.get("attack_range")), 0.0),
		float(definition.get("area_arc_degrees")),
		maxf(float(definition.get("impact_range_leeway")), 0.0)
	)


func _targeting_mode(definition: Resource) -> String:
	return String(definition.get("targeting_mode")) if definition != null else ""


func _execution_type(definition: Resource) -> String:
	return String(definition.get("execution_type")) if definition != null else ""


func _requires_out_of_combat(definition: Resource) -> bool:
	return definition != null and bool(definition.get("requires_out_of_combat"))


func _health_ratio() -> float:
	if _health == null:
		return 1.0
	if _health.has_method("get_health_ratio"):
		return float(_health.call("get_health_ratio"))
	var max_health := maxf(float(_health.get("max_health")), 0.0)
	if max_health <= 0.0:
		return 0.0
	return clampf(float(_health.get("current_health")) / max_health, 0.0, 1.0)


func _has_active_absorb_shield() -> bool:
	return _health != null and _health.has_method("has_absorb_shield") and bool(_health.call("has_absorb_shield"))


func _on_damage_taken(_amount: float) -> void:
	if _channel_definition != null and bool(_channel_definition.get("cancel_on_damage")):
		_interrupt_active_channel("Damaged")


func _set_defeated_state(is_defeated: bool, should_hide_body: bool = true) -> void:
	if _body != null:
		_body.collision_layer = 0 if is_defeated else _original_collision_layer
		_body.collision_mask = 0 if is_defeated else _original_collision_mask
		if hide_while_defeated and should_hide_body:
			_body.visible = not is_defeated

	_set_collision_shapes_disabled(is_defeated)
	if _selectable != null:
		_selectable.set("selection_enabled", not is_defeated)
		if is_defeated and _selectable.has_method("set_selected"):
			_selectable.call("set_selected", false)
	_sync_debug_zones(true)


func _play_death_animation() -> float:
	if _animation == null or not _animation.has_method("play_death"):
		return 0.0

	return maxf(float(_animation.call("play_death")), 0.0)


func _drop_loot() -> void:
	if _suppress_next_loot_drop:
		_suppress_next_loot_drop = false
		return
	if _loot_dropper == null or not _loot_dropper.has_method("drop_loot"):
		return

	var drop_position := Vector3.ZERO
	if _body != null:
		drop_position = _body.global_position
	else:
		var parent_3d := get_parent() as Node3D
		if parent_3d != null:
			drop_position = parent_3d.global_position
	_loot_dropper.call("drop_loot", drop_position)


func _collect_collision_shapes(node: Node) -> void:
	if node is CollisionShape3D:
		_collision_shapes.append(node as CollisionShape3D)

	for child in node.get_children():
		_collect_collision_shapes(child)


func _set_collision_shapes_disabled(is_disabled: bool) -> void:
	for collision_shape in _collision_shapes:
		if is_instance_valid(collision_shape):
			collision_shape.set_deferred("disabled", is_disabled)


func _has_target() -> bool:
	return _target != null and is_instance_valid(_target)


func _is_self_defeated() -> bool:
	return _health != null and _health.has_method("is_defeated") and _health.call("is_defeated") == true


func _is_target_defeated(target: Node) -> bool:
	var target_health := _find_health(target)
	return (
		target_health != null
		and target_health.has_method("is_defeated")
		and target_health.call("is_defeated") == true
	)


func _find_health(target: Node) -> Node:
	if target == null:
		return null
	if target.has_method("apply_damage"):
		return target

	return target.get_node_or_null("Health")


func _direction_to(destination: Vector3) -> Vector3:
	var direction := destination - _body.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return Vector3.ZERO

	return direction.normalized()


func _horizontal_distance_to(destination: Vector3) -> float:
	var offset := destination - _body.global_position
	offset.y = 0.0
	return offset.length()


func _distance_from_home() -> float:
	return _horizontal_distance_to(_home_position)


func _attack_interval() -> float:
	return 1.0 / _attack_speed()


func _face_direction(direction: Vector3, delta: float = -1.0) -> void:
	if direction == Vector3.ZERO or _visuals == null:
		return

	var target_yaw := atan2(-direction.x, -direction.z)
	if delta <= 0.0:
		_visuals.rotation.y = target_yaw
		return

	var turn_weight := clampf(turn_speed * delta, 0.0, 1.0)
	_visuals.rotation.y = lerp_angle(_visuals.rotation.y, target_yaw, turn_weight)


func _set_moving_animation(is_moving: bool) -> void:
	if _animation != null and _animation.has_method("set_moving"):
		_animation.call("set_moving", is_moving)


func _sync_debug_zones(force_refresh := false) -> void:
	var mob_world_center := Vector3.ZERO
	if _body != null:
		mob_world_center = _body.global_position
	elif get_parent() is Node3D:
		mob_world_center = (get_parent() as Node3D).global_position

	_sync_debug_radius_zone(
		&"_debug_aggro_zone",
		debug_aggro_zone_path,
		aggro_radius,
		debug_show_aggro_zone,
		mob_world_center,
		true,
		force_refresh
	)
	_sync_debug_radius_zone(
		&"_debug_deaggro_zone",
		debug_deaggro_zone_path,
		leash_radius,
		debug_show_deaggro_zone,
		_home_position,
		true,
		force_refresh
	)


func _sync_debug_radius_zone(
	cache_property: StringName,
	zone_path: NodePath,
	radius: float,
	should_be_enabled: bool,
	world_center: Vector3,
	uses_world_center: bool,
	force_refresh := false
) -> void:
	var zone := get(cache_property) as Node
	if zone == null and not zone_path.is_empty():
		zone = get_node_or_null(zone_path)
		set(cache_property, zone)
	if zone == null:
		return

	if (
		zone.has_method("set_radius")
		and (
			force_refresh
			or not zone.has_method("get_radius")
			or not is_equal_approx(float(zone.call("get_radius")), radius)
		)
	):
		zone.call("set_radius", radius)

	if uses_world_center and zone.has_method("set_world_center"):
		zone.call("set_world_center", world_center)

	var should_show := (
		should_be_enabled
		and not _is_respawning
		and not _is_self_defeated()
	)
	if zone.has_method("set_debug_visible"):
		zone.call("set_debug_visible", should_show)
	else:
		zone.visible = should_show


func _connect_stats_signals() -> void:
	if _stats == null or not _stats.has_signal("stat_changed"):
		return

	var callable := Callable(self, "_on_stat_changed")
	if not _stats.is_connected("stat_changed", callable):
		_stats.connect("stat_changed", callable)


func _on_stat_changed(stat_id: StringName, _value: float) -> void:
	match stat_id:
		&"max_health", &"health_regeneration":
			_sync_health_stats(false)


func _sync_health_stats(should_fill := false) -> void:
	if _health == null:
		return

	var max_health := _stat_value(&"max_health", float(_health.get("max_health")))
	if _health.has_method("set_max_health"):
		_health.call("set_max_health", max_health, should_fill)
	else:
		_health.set("max_health", max_health)
	_health.set("health_regeneration_per_second", maxf(_stat_value(&"health_regeneration", 0.0), 0.0))


func _movement_speed() -> float:
	return maxf(_stat_value(&"move_speed", movement_speed), 0.0)


func _attack_damage() -> float:
	return maxf(_stat_value(&"auto_attack_damage", attack_damage), 0.0)


func _attack_speed() -> float:
	return maxf(_stat_value(&"auto_attack_speed", attack_speed), 0.01)


func _stat_value(stat_id: StringName, fallback: float) -> float:
	if _stats != null and _stats.has_method("get_stat"):
		var value := float(_stats.call("get_stat", stat_id))
		if value > 0.0:
			return value

	return fallback
