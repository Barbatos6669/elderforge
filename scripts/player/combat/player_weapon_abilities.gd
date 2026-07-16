## Executes active abilities supplied by the player's equipped items.
##
## The historical class name is kept for scene compatibility. Internally the
## component is slot-driven: weapons supply Q/W/E, chest armor supplies R,
## helmets supply D, and boots supply F.
class_name PlayerWeaponAbilities
extends Node

const AttackTimelineScript := preload("res://scripts/combat/attack_timeline.gd")
const DamageRequestScript := preload("res://scripts/combat/damage_request.gd")
const DamageResolverScript := preload("res://scripts/combat/damage_resolver.gd")
const PlayerStatsScript := preload("res://scripts/player/stats/player_stats.gd")
const WeaponAbilityCatalogScript := preload("res://scripts/combat/abilities/weapon_ability_catalog.gd")
const AbilitySlots := preload(
	"res://scripts/combat/abilities/equipment_ability_slots.gd"
)
const Q_SLOT := &"q"
const TARGETING_SELECTED := "selected_target"
const TARGETING_DIRECTION := "direction"
const TARGETING_SELF := "self"
const EXECUTION_DAMAGE := "damage"
const EXECUTION_DODGE := "dodge"
const EXECUTION_REGENERATION := "regeneration"
const EXECUTION_SHIELD := "shield"
const EQUIPMENT_CHANNEL_TYPE := "equipment_ability"

signal ability_changed(slot_id: StringName, definition: Resource)
signal cooldown_changed(slot_id: StringName, remaining_seconds: float, total_seconds: float)
signal ability_cast_started(slot_id: StringName, target: Node, definition: Resource)
signal ability_cast_landed(slot_id: StringName, target: Node, damage: float)
signal ability_cast_interrupted(slot_id: StringName, target: Node, reason: String)
signal ability_cast_finished(slot_id: StringName)
signal ability_channel_tick(slot_id: StringName, health_restored: float, energy_restored: float)
signal directional_targeting_started(slot_id: StringName, definition: Resource)
signal directional_targeting_cancelled(slot_id: StringName)
signal directional_movement_started(
	slot_id: StringName,
	direction: Vector3,
	distance: float,
	duration_seconds: float
)

## Optional inventory node. Empty uses the first `player_inventory` group member.
@export var inventory_path: NodePath
## Mana/energy ResourcePool charged when a committed cast begins.
@export var mana_path: NodePath = NodePath("../Mana")
## Shared timed-action node used by channeled equipment abilities.
@export var channeling_path: NodePath = NodePath("../Channeling")
## Ground preview controlled while a directional ability is being aimed.
@export var directional_indicator_path: NodePath = NodePath("../DirectionalAbilityIndicator")
## Equipment sources keyed by action-bar slot. Designers can add another slot
## without changing the inventory or HUD APIs.
@export var ability_equipment_slots: Dictionary = (
	AbilitySlots.EQUIPMENT_SLOT_BY_ABILITY.duplicate()
)
## Legacy Q source retained for old scene overrides and item definitions.
@export var weapon_equipment_slot_id := "main_hand"
## Fallback base damage when an attacker has no PlayerStats component.
@export_range(0.0, 10000.0, 0.1) var fallback_base_damage := 20.0

var _inventory: Node
var _directional_indicator: Node3D
var _channeling: Node
var _active_definitions: Dictionary = {}
var _active_definition_paths: Dictionary = {}
var _pending_slot: StringName = &""
var _pending_target: Node
var _cast_slot: StringName = &""
var _cast_target: Node
var _cast_definition: Resource
var _cast_direction := Vector3.ZERO
var _aiming_slot: StringName = &""
var _aim_direction := Vector3(0.0, 0.0, -1.0)
var _channel_slot: StringName = &""
var _channel_attacker: Node3D
var _channel_definition: Resource
var _channel_tick_count := 0
var _timeline = AttackTimelineScript.new()
var _damage_resolver = DamageResolverScript.new()
var _cooldowns_by_ability_id := {}


func _ready() -> void:
	_directional_indicator = get_node_or_null(directional_indicator_path) as Node3D
	_channeling = get_node_or_null(channeling_path)
	_connect_channeling()
	_hide_directional_indicator()
	call_deferred("_bind_inventory")


## Allows playable scenes and tests to bind an inventory explicitly.
func set_inventory(inventory: Node) -> void:
	if _inventory == inventory:
		_refresh_equipped_abilities(true)
		return

	_disconnect_inventory()
	_inventory = inventory
	_connect_inventory()
	_refresh_equipped_abilities(true)


## Requests an ability that acts on the selected hostile target. Out-of-range
## targets remain pending while PlayerController approaches them.
func request_cast(slot_id: StringName, target: Variant, attacker: Node3D) -> bool:
	var target_node := _valid_target_node(target)
	var definition := get_active_ability(slot_id)
	if definition == null or _targeting_mode(definition) != TARGETING_SELECTED:
		return false
	if not _can_begin_ability(slot_id, attacker, definition):
		return false
	if not _can_attack_target(target_node):
		return false

	cancel_directional_targeting()
	_pending_slot = slot_id
	_pending_target = target_node
	return true


## Commits an ability that acts on the wearer without entering a targeting mode.
## Regeneration channels use PlayerChanneling so the shared channel bar and
## interruption rules remain consistent with gathering and refining.
func request_self_cast(slot_id: StringName, attacker: Node3D) -> bool:
	var definition := get_active_ability(slot_id)
	if definition == null or _targeting_mode(definition) != TARGETING_SELF:
		return false
	if not _can_begin_ability(slot_id, attacker, definition):
		return false
	var execution_type := _execution_type(definition)
	if execution_type == EXECUTION_REGENERATION and _channeling == null:
		return false
	if execution_type != EXECUTION_REGENERATION and execution_type != EXECUTION_SHIELD:
		return false
	if not _pay_ability_cost(attacker, definition):
		ability_cast_interrupted.emit(slot_id, attacker, "Not enough mana")
		return false

	cancel_directional_targeting()
	_pending_slot = &""
	_pending_target = null
	_start_cooldown(attacker, slot_id, definition)

	match execution_type:
		EXECUTION_REGENERATION:
			if _channeling == null:
				return false
			_channel_slot = slot_id
			_channel_attacker = attacker
			_channel_definition = definition
			_channel_tick_count = 0
			_channeling.call(
				"start_channel",
				String(definition.get("display_name")),
				maxf(float(definition.get("cast_duration_seconds")), 0.01),
				_equipment_channel_context(slot_id, definition)
			)
			ability_cast_started.emit(slot_id, attacker, definition)
			return true
		EXECUTION_SHIELD:
			ability_cast_started.emit(slot_id, attacker, definition)
			ability_cast_finished.emit(slot_id)
			return true

	return false


## Enters cursor-driven direction targeting without spending energy or starting
## cooldown. The cost is committed only after the player confirms the preview.
func begin_directional_targeting(slot_id: StringName, attacker: Node3D) -> bool:
	var definition := get_active_ability(slot_id)
	if definition == null or _targeting_mode(definition) != TARGETING_DIRECTION:
		return false
	if not _can_begin_ability(slot_id, attacker, definition):
		return false

	_pending_slot = &""
	_pending_target = null
	_aiming_slot = slot_id
	_show_directional_indicator(definition)
	directional_targeting_started.emit(slot_id, definition)
	return true


## Updates the preview direction from a cursor hit in world space.
func update_directional_targeting(attacker: Node3D, world_position: Vector3) -> void:
	if attacker == null or not is_directional_targeting():
		return

	var offset := world_position - attacker.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.0001:
		return

	_aim_direction = offset.normalized()
	var definition := get_active_ability(_aiming_slot)
	if definition != null and _directional_indicator != null:
		_directional_indicator.call(
			"show_direction",
			_aim_direction,
			maxf(float(definition.get("movement_distance")), 0.0),
			maxf(float(definition.get("indicator_width")), 0.1)
		)


## Commits the currently aimed directional ability.
func confirm_directional_cast(attacker: Node3D) -> bool:
	if not is_directional_targeting():
		return false

	var slot_id := _aiming_slot
	var definition := get_active_ability(slot_id)
	if definition == null or not _can_begin_ability(slot_id, attacker, definition):
		cancel_directional_targeting()
		return false

	var cast_duration := maxf(float(definition.get("cast_duration_seconds")), 0.01)
	var impact_fraction := clampf(float(definition.get("impact_fraction")), 0.0, 1.0)
	if not _timeline.begin(cast_duration, impact_fraction, 0.0, cast_duration):
		return false
	if not _pay_ability_cost(attacker, definition):
		_timeline.reset()
		ability_cast_interrupted.emit(slot_id, null, "Not enough mana")
		cancel_directional_targeting()
		return false

	_cast_slot = slot_id
	_cast_target = null
	_cast_definition = definition
	_cast_direction = _aim_direction.normalized()
	_start_cooldown(attacker, slot_id, definition)
	_aiming_slot = &""
	_hide_directional_indicator()
	ability_cast_started.emit(slot_id, null, definition)
	if _execution_type(definition) == EXECUTION_DODGE:
		directional_movement_started.emit(
			slot_id,
			_cast_direction,
			maxf(float(definition.get("movement_distance")), 0.0),
			cast_duration
		)
	return true


func cancel_directional_targeting() -> void:
	if not is_directional_targeting():
		_hide_directional_indicator()
		return
	var cancelled_slot := _aiming_slot
	_aiming_slot = &""
	_hide_directional_indicator()
	directional_targeting_cancelled.emit(cancelled_slot)


## Advances cooldowns and the current cast. Call once per local physics frame.
func update_abilities(attacker: Node3D, delta: float) -> void:
	_advance_cooldowns(delta)
	if is_channeling_ability():
		if attacker == null or _is_attacker_defeated(attacker):
			cancel_active_channel("Wearer unavailable")
		elif _requires_out_of_combat(_channel_definition) and _is_attacker_in_combat(attacker):
			cancel_active_channel("Entered combat")

	if not _timeline.is_ready():
		if (
			_timeline.is_winding_up()
			and _execution_type(_cast_definition) == EXECUTION_DAMAGE
			and not _can_complete_current_cast(attacker)
		):
			_interrupt_current_cast("Target lost")

		var timeline_event: int = _timeline.advance(delta)
		if timeline_event == AttackTimelineScript.TimelineEvent.IMPACT:
			if _execution_type(_cast_definition) == EXECUTION_DAMAGE:
				_resolve_cast_impact(attacker)
		elif timeline_event == AttackTimelineScript.TimelineEvent.READY:
			_finish_current_cast()
		return

	var pending_target := _valid_target_node(_pending_target)
	if pending_target == null:
		_pending_slot = &""
		_pending_target = null
		return
	if not _can_attack_target(pending_target) or _is_target_defeated(pending_target):
		_pending_slot = &""
		_pending_target = null
		return
	if _is_target_in_range(attacker, pending_target):
		_begin_target_cast(attacker)


## Cancels an approach or uncommitted target wind-up. A committed dodge keeps
## running so ordinary click input cannot interrupt movement mid-roll. Callers
## can preserve a mobile channel when the new action is only a move order.
func cancel_current_action(reason := "Cancelled", cancel_channel := true) -> void:
	_pending_slot = &""
	_pending_target = null
	cancel_directional_targeting()
	if _timeline.is_winding_up() and _execution_type(_cast_definition) == EXECUTION_DAMAGE:
		_interrupt_current_cast(reason)
	if cancel_channel:
		cancel_active_channel(reason)


## Interrupts the currently owned equipment channel, if one exists.
func cancel_active_channel(reason := "Cancelled") -> void:
	if not is_channeling_ability():
		return
	if _channeling != null and _channeling.has_method("cancel_channel"):
		_channeling.call("cancel_channel", reason)
	else:
		_interrupt_active_channel(reason)


## Damage only interrupts channels whose item data opts into that rule.
func cancel_active_channel_on_damage() -> void:
	if (
		is_channeling_ability()
		and _channel_definition != null
		and bool(_channel_definition.get("cancel_on_damage"))
	):
		cancel_active_channel("Damaged")


## Out-of-combat channels are invalidated as soon as combat state changes.
func cancel_out_of_combat_channel() -> void:
	if is_channeling_ability() and _requires_out_of_combat(_channel_definition):
		cancel_active_channel("Entered combat")


## Clears active state for death, respawn, or equipment hard resets.
func reset_cast_state() -> void:
	cancel_active_channel("Reset")
	_pending_slot = &""
	_pending_target = null
	_cast_slot = &""
	_cast_target = null
	_cast_definition = null
	_cast_direction = Vector3.ZERO
	_aiming_slot = &""
	_clear_channel_state()
	_timeline.reset()
	_hide_directional_indicator()


func has_active_request() -> bool:
	return (
		is_directional_targeting()
		or (_pending_target != null and is_instance_valid(_pending_target))
		or not _timeline.is_ready()
	)


func is_casting() -> bool:
	return not _timeline.is_ready() or is_channeling_ability()


func is_channeling_ability() -> bool:
	return (
		not String(_channel_slot).is_empty()
		and _channel_definition != null
		and _channel_attacker != null
		and is_instance_valid(_channel_attacker)
	)


func is_directional_targeting() -> bool:
	return not String(_aiming_slot).is_empty()


func is_directional_movement_active() -> bool:
	return (
		not _timeline.is_ready()
		and _cast_definition != null
		and _execution_type(_cast_definition) == EXECUTION_DODGE
	)


func should_hold_position(attacker: Node3D) -> bool:
	if is_directional_targeting():
		return true
	if not _timeline.is_ready():
		return not is_directional_movement_active()
	var pending_target := _valid_target_node(_pending_target)
	return pending_target != null and _is_target_in_range(attacker, pending_target)


func get_direction_to_target(attacker: Node3D) -> Vector3:
	if is_directional_targeting():
		return _aim_direction
	if is_directional_movement_active():
		return _cast_direction

	var target: Variant = _current_action_target()
	var target_3d := _valid_target_node(target) as Node3D
	if attacker == null or target_3d == null:
		return Vector3.ZERO

	var direction := target_3d.global_position - attacker.global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


func get_approach_destination(attacker: Node3D) -> Vector3:
	var target: Variant = _current_action_target()
	var target_3d := _valid_target_node(target) as Node3D
	if attacker == null or target_3d == null:
		return attacker.global_position if attacker != null else Vector3.ZERO

	var direction := get_direction_to_target(attacker)
	if direction == Vector3.ZERO:
		return target_3d.global_position

	var definition := _definition_for_current_action()
	var approach_distance := float(definition.get("approach_distance")) if definition != null else 0.0
	var destination := target_3d.global_position - direction * approach_distance
	destination.y = attacker.global_position.y
	return destination


func get_active_ability(slot_id: StringName = Q_SLOT) -> Resource:
	return _active_definitions.get(String(slot_id)) as Resource


func get_known_ability(ability_id: String) -> Resource:
	return WeaponAbilityCatalogScript.get_definition(ability_id)


func get_cooldown_remaining(slot_id: StringName = Q_SLOT) -> float:
	var definition := get_active_ability(slot_id)
	if definition == null:
		return 0.0
	return maxf(float(_cooldowns_by_ability_id.get(String(definition.get("ability_id")), 0.0)), 0.0)


func get_cooldown_total(slot_id: StringName = Q_SLOT) -> float:
	var definition := get_active_ability(slot_id)
	return maxf(float(definition.get("cooldown_seconds")), 0.0) if definition != null else 0.0


func _begin_target_cast(attacker: Node3D) -> void:
	var definition := get_active_ability(_pending_slot)
	var pending_target := _valid_target_node(_pending_target)
	if definition == null or pending_target == null:
		_pending_slot = &""
		_pending_target = null
		return

	if not _can_pay_ability_cost(attacker, definition):
		var rejected_slot := _pending_slot
		var rejected_target := pending_target
		_pending_slot = &""
		_pending_target = null
		ability_cast_interrupted.emit(rejected_slot, rejected_target, "Not enough mana")
		return

	var cast_duration := maxf(float(definition.get("cast_duration_seconds")), 0.01)
	var impact_fraction := clampf(float(definition.get("impact_fraction")), 0.0, 1.0)
	if not _timeline.begin(cast_duration, impact_fraction, 0.0, cast_duration):
		return
	if not _pay_ability_cost(attacker, definition):
		_timeline.reset()
		var rejected_slot := _pending_slot
		var rejected_target := pending_target
		_pending_slot = &""
		_pending_target = null
		ability_cast_interrupted.emit(rejected_slot, rejected_target, "Not enough mana")
		return

	_cast_slot = _pending_slot
	_cast_definition = definition
	_cast_target = pending_target
	_cast_direction = Vector3.ZERO
	_pending_slot = &""
	_pending_target = null
	_start_cooldown(attacker, _cast_slot, _cast_definition)
	ability_cast_started.emit(_cast_slot, _cast_target, _cast_definition)


func _resolve_cast_impact(attacker: Node3D) -> void:
	var impact_target := _valid_target_node(_cast_target)
	if not _can_attack_target(impact_target) or _is_target_defeated(impact_target):
		ability_cast_interrupted.emit(_cast_slot, impact_target, "Target lost before impact")
		return
	if not _is_target_in_range(attacker, impact_target, _impact_range_leeway()):
		ability_cast_interrupted.emit(_cast_slot, impact_target, "Target left ability range")
		return

	var health := _find_target_health(impact_target)
	if health == null or not health.has_method("apply_damage"):
		ability_cast_interrupted.emit(_cast_slot, impact_target, "Target has no health component")
		return

	var request := DamageRequestScript.create(
		attacker,
		impact_target,
		_ability_damage(attacker),
		_ability_damage_type(_cast_definition),
		health
	)
	var result := _damage_resolver.resolve(request)
	if result.was_applied():
		ability_cast_landed.emit(_cast_slot, impact_target, result.applied_damage)


func _finish_current_cast() -> void:
	var finished_slot := _cast_slot
	_cast_slot = &""
	_cast_target = null
	_cast_definition = null
	_cast_direction = Vector3.ZERO
	ability_cast_finished.emit(finished_slot)


func _interrupt_current_cast(reason: String) -> void:
	if not _timeline.interrupt_windup():
		return
	var interrupted_slot := _cast_slot
	var interrupted_target := _valid_target_node(_cast_target)
	_cast_target = null
	ability_cast_interrupted.emit(interrupted_slot, interrupted_target, reason)


func _start_cooldown(attacker: Node3D, slot_id: StringName, definition: Resource) -> void:
	var ability_id := String(definition.get("ability_id"))
	var cooldown := _effective_cooldown_seconds(attacker, definition)
	_cooldowns_by_ability_id[ability_id] = cooldown
	cooldown_changed.emit(slot_id, cooldown, cooldown)


func _advance_cooldowns(delta: float) -> void:
	var elapsed := maxf(delta, 0.0)
	if elapsed <= 0.0:
		return

	for raw_ability_id in _cooldowns_by_ability_id.keys():
		var ability_id := String(raw_ability_id)
		var previous := maxf(float(_cooldowns_by_ability_id[raw_ability_id]), 0.0)
		var remaining := maxf(previous - elapsed, 0.0)
		if remaining <= 0.0:
			_cooldowns_by_ability_id.erase(raw_ability_id)
		else:
			_cooldowns_by_ability_id[raw_ability_id] = remaining

		for slot_key in _active_definitions:
			var definition := _active_definitions[slot_key] as Resource
			if definition != null and String(definition.get("ability_id")) == ability_id:
				var slot_id := StringName(String(slot_key))
				cooldown_changed.emit(slot_id, remaining, get_cooldown_total(slot_id))


func _can_begin_ability(slot_id: StringName, attacker: Node3D, definition: Resource) -> bool:
	return (
		definition != null
		and attacker != null
		and not _is_attacker_defeated(attacker)
		and _timeline.is_ready()
		and not is_channeling_ability()
		and get_cooldown_remaining(slot_id) <= 0.0
		and _can_pay_ability_cost(attacker, definition)
		and (
			not _requires_out_of_combat(definition)
			or not _is_attacker_in_combat(attacker)
		)
	)


func _effective_cooldown_seconds(attacker: Node3D, definition: Resource) -> float:
	var base_cooldown := maxf(float(definition.get("cooldown_seconds")), 0.0)
	var stats := attacker.get_node_or_null("Stats") if attacker != null else null
	if stats == null or not stats.has_method("get_stat"):
		return base_cooldown

	var cooldown_rate := maxf(float(stats.call("get_stat", PlayerStatsScript.COOLDOWN_RATE)), 0.0)
	return base_cooldown / (1.0 + cooldown_rate / 100.0)


func _effective_energy_cost(attacker: Node3D, definition: Resource) -> float:
	var base_cost := maxf(float(definition.get("energy_cost")), 0.0)
	var stats := attacker.get_node_or_null("Stats") if attacker != null else null
	if stats == null or not stats.has_method("get_stat"):
		return base_cost

	var reduction := clampf(
		float(stats.call("get_stat", PlayerStatsScript.ENERGY_COST_REDUCTION)),
		0.0,
		100.0
	)
	return base_cost * (1.0 - reduction / 100.0)


func _can_pay_ability_cost(attacker: Node3D, definition: Resource) -> bool:
	var cost := _effective_energy_cost(attacker, definition)
	if cost <= 0.0:
		return true
	var pool := _find_mana_pool(attacker)
	return pool != null and pool.has_method("can_spend") and bool(pool.call("can_spend", cost))


func _pay_ability_cost(attacker: Node3D, definition: Resource) -> bool:
	var cost := _effective_energy_cost(attacker, definition)
	if cost <= 0.0:
		return true
	var pool := _find_mana_pool(attacker)
	return pool != null and pool.has_method("try_spend") and bool(pool.call("try_spend", cost))


func _find_mana_pool(attacker: Node3D) -> Node:
	var pool := get_node_or_null(mana_path) if not mana_path.is_empty() else null
	if pool == null and attacker != null:
		pool = attacker.get_node_or_null("Mana")
	return pool


func _find_attacker_health(attacker: Node3D) -> Node:
	return attacker.get_node_or_null("Health") if attacker != null else null


func _connect_channeling() -> void:
	if _channeling == null:
		return
	var progress_callable := Callable(self, "_on_channel_progress_changed")
	if (
		_channeling.has_signal("channel_progress_changed")
		and not _channeling.is_connected("channel_progress_changed", progress_callable)
	):
		_channeling.connect("channel_progress_changed", progress_callable)
	var completed_callable := Callable(self, "_on_channel_completed")
	if (
		_channeling.has_signal("channel_completed")
		and not _channeling.is_connected("channel_completed", completed_callable)
	):
		_channeling.connect("channel_completed", completed_callable)
	var cancelled_callable := Callable(self, "_on_channel_cancelled")
	if (
		_channeling.has_signal("channel_cancelled")
		and not _channeling.is_connected("channel_cancelled", cancelled_callable)
	):
		_channeling.connect("channel_cancelled", cancelled_callable)


func _on_channel_progress_changed(_progress: float, elapsed: float, _remaining: float) -> void:
	if not is_channeling_ability() or not _owns_current_channel():
		return

	var tick_interval := maxf(
		float(_channel_definition.get("channel_tick_interval_seconds")),
		0.05
	)
	var duration := maxf(float(_channel_definition.get("cast_duration_seconds")), 0.01)
	var maximum_tick_count := floori((duration + 0.0001) / tick_interval)
	var elapsed_tick_count := mini(
		floori((maxf(elapsed, 0.0) + 0.0001) / tick_interval),
		maximum_tick_count
	)
	while _channel_tick_count < elapsed_tick_count and is_channeling_ability():
		_channel_tick_count += 1
		_apply_regeneration_tick()


func _on_channel_completed(context: Dictionary) -> void:
	if not _is_owned_channel_context(context):
		return
	var finished_slot := _channel_slot
	_clear_channel_state()
	ability_cast_finished.emit(finished_slot)


func _on_channel_cancelled(reason: String, context: Dictionary) -> void:
	if not _is_owned_channel_context(context):
		return
	_interrupt_active_channel(reason)


func _apply_regeneration_tick() -> void:
	if not is_channeling_ability() or _execution_type(_channel_definition) != EXECUTION_REGENERATION:
		return

	var health_restored := 0.0
	var energy_restored := 0.0
	var health := _find_attacker_health(_channel_attacker)
	if health != null and health.has_method("heal"):
		var max_health := maxf(float(health.get("max_health")), 0.0)
		health_restored = float(health.call(
			"heal",
			max_health * maxf(
				float(_channel_definition.get("health_restore_percent_per_tick")),
				0.0
			) / 100.0
		))

	var pool := _find_mana_pool(_channel_attacker)
	if pool != null and pool.has_method("restore"):
		var max_resource := maxf(float(pool.get("max_resource")), 0.0)
		energy_restored = float(pool.call(
			"restore",
			max_resource * maxf(
				float(_channel_definition.get("energy_restore_percent_per_tick")),
				0.0
			) / 100.0
		))

	ability_channel_tick.emit(_channel_slot, health_restored, energy_restored)


func _interrupt_active_channel(reason: String) -> void:
	if String(_channel_slot).is_empty():
		return
	var interrupted_slot := _channel_slot
	var interrupted_attacker := _valid_target_node(_channel_attacker)
	_clear_channel_state()
	ability_cast_interrupted.emit(interrupted_slot, interrupted_attacker, reason)


func _clear_channel_state() -> void:
	_channel_slot = &""
	_channel_attacker = null
	_channel_definition = null
	_channel_tick_count = 0


func _equipment_channel_context(slot_id: StringName, definition: Resource) -> Dictionary:
	return {
		"type": EQUIPMENT_CHANNEL_TYPE,
		"slot_id": String(slot_id),
		"ability_id": String(definition.get("ability_id")),
		"execution_type": _execution_type(definition),
	}


func _owns_current_channel() -> bool:
	if _channeling == null or not _channeling.has_method("get_context"):
		return false
	return _is_owned_channel_context(_channeling.call("get_context"))


func _is_owned_channel_context(context: Dictionary) -> bool:
	return (
		String(context.get("type", "")) == EQUIPMENT_CHANNEL_TYPE
		and String(context.get("slot_id", "")) == String(_channel_slot)
		and _channel_definition != null
		and String(context.get("ability_id", ""))
		== String(_channel_definition.get("ability_id"))
	)


func _ability_damage(attacker: Node3D) -> float:
	var attack_damage := fallback_base_damage
	var ability_bonus := 0.0
	var damage_type := _ability_damage_type(_cast_definition)
	var stats := attacker.get_node_or_null("Stats") if attacker != null else null
	if stats != null and stats.has_method("get_stat"):
		attack_damage = float(stats.call("get_stat", PlayerStatsScript.AUTO_ATTACK_DAMAGE))
		match damage_type:
			DamageRequestScript.TYPE_PHYSICAL:
				ability_bonus = float(stats.call(
					"get_stat",
					PlayerStatsScript.PHYSICAL_ABILITY_BONUS
				))
			DamageRequestScript.TYPE_MAGICAL:
				ability_bonus = float(stats.call(
					"get_stat",
					PlayerStatsScript.MAGICAL_ABILITY_BONUS
				))

	var ability_base_damage := float(_cast_definition.get("base_damage")) if _cast_definition != null else 0.0
	var multiplier := float(_cast_definition.get("damage_multiplier")) if _cast_definition != null else 1.0
	var scaled_damage := ability_base_damage + attack_damage * multiplier
	return maxf(scaled_damage * (1.0 + ability_bonus / 100.0), 0.0)


func _ability_damage_type(definition: Resource) -> StringName:
	if definition == null:
		return DamageRequestScript.TYPE_PHYSICAL

	return DamageRequestScript.normalize_damage_type(StringName(String(definition.get("damage_type"))))


func _can_complete_current_cast(attacker: Node3D) -> bool:
	return (
		_can_attack_target(_cast_target)
		and not _is_target_defeated(_cast_target)
		and _is_target_in_range(attacker, _cast_target, _impact_range_leeway())
	)



func _can_attack_target(target: Variant) -> bool:
	var target_node := _valid_target_node(target)
	return (
		target_node != null
		and target_node.has_method("is_hostile")
		and bool(target_node.call("is_hostile"))
	)


func _is_target_in_range(attacker: Node3D, target: Variant, extra_range := 0.0) -> bool:
	var target_3d := _valid_target_node(target) as Node3D
	var definition := _definition_for_current_action()
	if attacker == null or target_3d == null or definition == null:
		return false

	var offset := target_3d.global_position - attacker.global_position
	offset.y = 0.0
	return offset.length() <= float(definition.get("attack_range")) + maxf(extra_range, 0.0)


func _impact_range_leeway() -> float:
	return maxf(float(_cast_definition.get("impact_range_leeway")), 0.0) if _cast_definition != null else 0.0


func _definition_for_current_action() -> Resource:
	if _cast_definition != null:
		return _cast_definition
	if not String(_pending_slot).is_empty():
		return get_active_ability(_pending_slot)
	if not String(_aiming_slot).is_empty():
		return get_active_ability(_aiming_slot)
	return null



func _current_action_target() -> Variant:
	return _cast_target if not _timeline.is_ready() else _pending_target


func _targeting_mode(definition: Resource) -> String:
	return String(definition.get("targeting_mode")) if definition != null else ""


func _execution_type(definition: Resource) -> String:
	return String(definition.get("execution_type")) if definition != null else ""


func _requires_out_of_combat(definition: Resource) -> bool:
	return definition != null and bool(definition.get("requires_out_of_combat"))


func _is_attacker_in_combat(attacker: Node3D) -> bool:
	var state := attacker.get_node_or_null("CombatState") if attacker != null else null
	return (
		state != null
		and state.has_method("is_in_combat")
		and bool(state.call("is_in_combat"))
	)


func _find_target_health(target: Variant) -> Node:
	var target_node := _valid_target_node(target)
	if target_node == null:
		return null
	if target_node.has_method("apply_damage"):
		return target_node

	var child_health := target_node.get_node_or_null("Health")
	if child_health != null:
		return child_health

	var parent_node := target_node.get_parent()
	return parent_node.get_node_or_null("Health") if parent_node != null else null


func _is_attacker_defeated(attacker: Node3D) -> bool:
	return _is_health_defeated(attacker.get_node_or_null("Health")) if attacker != null else true


func _is_target_defeated(target: Variant) -> bool:
	return _is_health_defeated(_find_target_health(target))


func _valid_target_node(target: Variant) -> Node:
	if typeof(target) != TYPE_OBJECT or not is_instance_valid(target):
		return null
	return target as Node


func _is_health_defeated(health: Node) -> bool:
	return health != null and health.has_method("is_defeated") and bool(health.call("is_defeated"))


func _show_directional_indicator(definition: Resource) -> void:
	if _directional_indicator == null or definition == null:
		return
	_directional_indicator.call(
		"show_direction",
		_aim_direction,
		maxf(float(definition.get("movement_distance")), 0.0),
		maxf(float(definition.get("indicator_width")), 0.1)
	)


func _hide_directional_indicator() -> void:
	if _directional_indicator != null:
		_directional_indicator.call("hide_indicator")


func _bind_inventory() -> void:
	if _inventory != null:
		_refresh_equipped_abilities(true)
		return

	var inventory := get_node_or_null(inventory_path) if not inventory_path.is_empty() else null
	if inventory == null and is_inside_tree():
		inventory = get_tree().get_first_node_in_group("player_inventory")
	set_inventory(inventory)


func _connect_inventory() -> void:
	if _inventory == null or not _inventory.has_signal("equipped_slots_changed"):
		return
	var callable := Callable(self, "_on_equipped_slots_changed")
	if not _inventory.is_connected("equipped_slots_changed", callable):
		_inventory.connect("equipped_slots_changed", callable)


func _disconnect_inventory() -> void:
	if _inventory == null or not _inventory.has_signal("equipped_slots_changed"):
		return
	var callable := Callable(self, "_on_equipped_slots_changed")
	if _inventory.is_connected("equipped_slots_changed", callable):
		_inventory.disconnect("equipped_slots_changed", callable)


func _on_equipped_slots_changed() -> void:
	_refresh_equipped_abilities()


func _refresh_equipped_abilities(force_refresh := false) -> void:
	var next_paths := {}
	for raw_slot_id in ability_equipment_slots:
		var slot_id := String(raw_slot_id).strip_edges().to_lower()
		var equipment_slot_id := String(ability_equipment_slots[raw_slot_id])
		if slot_id.is_empty() or equipment_slot_id.is_empty():
			continue
		if slot_id == String(Q_SLOT) and equipment_slot_id == "main_hand":
			equipment_slot_id = weapon_equipment_slot_id

		var equipped_item := {}
		if _inventory != null and _inventory.has_method("get_equipped_slot"):
			equipped_item = _inventory.call("get_equipped_slot", equipment_slot_id)

		var ability_paths := equipped_item.get("ability_paths", {}) as Dictionary
		var definition_path := String(ability_paths.get(slot_id, "")) if ability_paths != null else ""
		if definition_path.is_empty() and slot_id == String(Q_SLOT):
			definition_path = String(equipped_item.get("q_ability_path", ""))
		next_paths[slot_id] = definition_path

	if not force_refresh and next_paths == _active_definition_paths:
		return

	reset_cast_state()
	var changed_slots := {}
	for slot_key in _active_definition_paths:
		changed_slots[String(slot_key)] = true
	for slot_key in next_paths:
		changed_slots[String(slot_key)] = true

	_active_definition_paths = next_paths
	_active_definitions.clear()
	for slot_key in next_paths:
		var definition := _load_ability_definition(String(next_paths[slot_key]))
		if definition != null:
			_active_definitions[String(slot_key)] = definition

	for slot_key in changed_slots:
		var slot_id := StringName(String(slot_key))
		ability_changed.emit(slot_id, get_active_ability(slot_id))
		cooldown_changed.emit(slot_id, get_cooldown_remaining(slot_id), get_cooldown_total(slot_id))


func _load_ability_definition(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Resource
