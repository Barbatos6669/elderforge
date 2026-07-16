## Local-player auto-attack coordinator.
##
## Targeting and movement remain in their player modules. This component owns
## target validation, melee range, and a wind-up/impact/recovery attack cycle.
class_name PlayerAutoAttack
extends Node

const AttackTimelineScript := preload("res://scripts/combat/attack_timeline.gd")
const DamageRequestScript := preload("res://scripts/combat/damage_request.gd")
const DamageResolverScript := preload("res://scripts/combat/damage_resolver.gd")

## Emitted when a real swing begins, after the player has reached attack range.
signal attack_started(target: Node)
## Emitted at the impact point after damage actually changes target health.
signal attack_landed(target: Node, damage: float)
## Emitted when a wind-up loses its target or range before impact.
signal attack_interrupted(target: Node)
signal attack_stopped

## Fallback damage when the attacker does not expose a PlayerStats node.
@export var attack_damage: float = 20.0
## Fallback seconds between hits when the attacker does not expose Auto-Attack Speed.
@export var attack_interval: float = 1.0
## Maximum horizontal distance at which a new melee swing can begin.
@export var attack_range: float = 1.8
## Desired stopping distance while moving into melee range.
@export var approach_distance: float = 1.35
## Extra range allowed after wind-up starts so tiny movement does not cancel a hit.
@export_range(0.0, 2.0, 0.05) var impact_range_leeway := 0.3
## Portion of each attack cycle spent winding up before damage lands.
@export_range(0.0, 0.95, 0.01) var windup_fraction := 0.32
## Lower timing bound keeps very fast attacks readable.
@export_range(0.0, 2.0, 0.01) var minimum_windup_seconds := 0.1
## Upper timing bound keeps very slow attacks from feeling unresponsive.
@export_range(0.01, 3.0, 0.01) var maximum_windup_seconds := 0.45
## Keeps this module from attacking friendly or neutral selectables.
@export var require_hostile_target: bool = true

var _target: Node
var _swing_target: Node
var _timeline = AttackTimelineScript.new()
var _damage_resolver = DamageResolverScript.new()


## Engages a valid target. The first swing begins after moving into range.
##
## Re-clicking the same target is idempotent. Switching targets during wind-up
## interrupts that swing but preserves recovery, preventing click-spam attacks.
func start_attack(target: Variant, attacker: Node3D) -> bool:
	var target_node := _valid_target_node(target)
	if attacker == null or _is_attacker_defeated(attacker) or not can_attack_target(target_node):
		return false

	if target_node == _valid_target_node(_target) and has_active_target():
		return true

	if _timeline.is_winding_up():
		_interrupt_current_swing()

	_target = target_node
	return true


## Clears the target while preserving any active recovery timer.
func stop_attack() -> void:
	var had_attack := has_active_target() or _timeline.is_winding_up()
	if _timeline.is_winding_up():
		_interrupt_current_swing()

	_target = null
	_swing_target = null
	if had_attack:
		attack_stopped.emit()


## Clears target and timing after death, respawn, or another hard reset.
func reset_attack_cycle() -> void:
	var had_attack := has_active_target() or not _timeline.is_ready()
	_target = null
	_swing_target = null
	_timeline.reset()
	if had_attack:
		attack_stopped.emit()


## Advances attack timing and resolves an impact when wind-up completes.
func update_attack(attacker: Node3D, delta: float) -> void:
	if attacker == null or _is_attacker_defeated(attacker):
		reset_attack_cycle()
		return

	if _timeline.is_winding_up() and not _can_complete_current_swing(attacker):
		_interrupt_current_swing()

	var timeline_event: int = _timeline.advance(delta)
	if timeline_event == AttackTimelineScript.TimelineEvent.IMPACT:
		_resolve_attack_impact(attacker)

	var active_target := _valid_target_node(_target)
	if active_target == null:
		_target = null
		return
	if not can_attack_target(active_target) or _is_target_defeated(active_target):
		stop_attack()
		return

	if _timeline.is_ready() and is_target_in_range(attacker):
		_begin_swing(attacker)


## Returns true when this module can initiate attacks against the given target.
func can_attack_target(target: Variant) -> bool:
	var target_node := _valid_target_node(target)
	if target_node == null:
		return false

	if require_hostile_target:
		return target_node.has_method("is_hostile") and target_node.call("is_hostile") == true

	return true


func get_current_attack_target() -> Node:
	return _valid_target_node(_target)


func has_active_target() -> bool:
	return _valid_target_node(_target) != null


## Returns true when close enough to begin a new attack.
func is_target_in_range(attacker: Node3D) -> bool:
	return _is_in_attack_range(attacker, _target)


## Keeps the actor planted through a valid wind-up and while recovering in range.
func should_hold_position(attacker: Node3D) -> bool:
	if not has_active_target():
		return false
	if _timeline.is_winding_up():
		return true

	return is_target_in_range(attacker)


func is_winding_up() -> bool:
	return _timeline.is_winding_up()


func is_recovering() -> bool:
	return _timeline.is_recovering()


func get_attack_phase() -> int:
	return _timeline.get_phase()


func get_phase_remaining_seconds() -> float:
	return _timeline.get_remaining_seconds()


## Returns the horizontal direction from the attacker to the active target.
func get_direction_to_target(attacker: Node3D) -> Vector3:
	var target_3d := _valid_target_node(_target) as Node3D
	if attacker == null or target_3d == null:
		return Vector3.ZERO

	var direction := target_3d.global_position - attacker.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return Vector3.ZERO

	return direction.normalized()


## Returns a world destination just outside the target, suitable for melee chase.
func get_approach_destination(attacker: Node3D) -> Vector3:
	if attacker == null:
		return Vector3.ZERO

	var target_3d := _valid_target_node(_target) as Node3D
	if target_3d == null:
		return attacker.global_position

	var direction_to_target := get_direction_to_target(attacker)
	if direction_to_target == Vector3.ZERO:
		return target_3d.global_position

	var destination := target_3d.global_position - direction_to_target * approach_distance
	destination.y = attacker.global_position.y
	return destination


func _begin_swing(attacker: Node3D) -> void:
	var active_target := _valid_target_node(_target)
	var attack_interval_seconds := _attack_interval(attacker)
	var impact_fraction_override := _attack_impact_fraction_override(attacker)
	var active_windup_fraction := windup_fraction
	var active_minimum_windup := minimum_windup_seconds
	var active_maximum_windup := maximum_windup_seconds
	if impact_fraction_override >= 0.0:
		active_windup_fraction = impact_fraction_override
		# Authored contact timing must remain normalized at every attack speed.
		active_minimum_windup = 0.0
		active_maximum_windup = attack_interval_seconds

	if active_target == null or not _timeline.begin(
		attack_interval_seconds,
		active_windup_fraction,
		active_minimum_windup,
		active_maximum_windup
	):
		return

	_swing_target = active_target
	attack_started.emit(_swing_target)


func _resolve_attack_impact(attacker: Node3D) -> void:
	var impact_target := _valid_target_node(_swing_target)
	_swing_target = null
	if not can_attack_target(impact_target) or _is_target_defeated(impact_target):
		attack_interrupted.emit(impact_target)
		return
	if not _is_in_attack_range(attacker, impact_target, impact_range_leeway):
		attack_interrupted.emit(impact_target)
		return

	var health := _find_target_health(impact_target)
	if health == null or not health.has_method("apply_damage"):
		attack_interrupted.emit(impact_target)
		return

	var request := DamageRequestScript.create(
		attacker,
		impact_target,
		_attack_damage(attacker),
		DamageRequestScript.TYPE_PHYSICAL,
		health
	)
	var result := _damage_resolver.resolve(request)
	if not result.was_applied():
		return

	attack_landed.emit(impact_target, result.applied_damage)
	if _is_health_defeated(health):
		stop_attack()


func _interrupt_current_swing() -> void:
	if not _timeline.interrupt_windup():
		return

	var interrupted_target := _valid_target_node(_swing_target)
	_swing_target = null
	attack_interrupted.emit(interrupted_target)


func _can_complete_current_swing(attacker: Node3D) -> bool:
	return (
		can_attack_target(_swing_target)
		and not _is_target_defeated(_swing_target)
		and _is_in_attack_range(attacker, _swing_target, impact_range_leeway)
	)


func _attack_damage(attacker: Node3D) -> float:
	var stats := attacker.get_node_or_null("Stats") if attacker != null else null
	if stats != null and stats.has_method("get_stat"):
		return maxf(float(stats.call("get_stat", PlayerStats.AUTO_ATTACK_DAMAGE)), 0.0)

	return maxf(attack_damage, 0.0)


func _attack_interval(attacker: Node3D) -> float:
	var stats := attacker.get_node_or_null("Stats") if attacker != null else null
	if stats != null and stats.has_method("get_stat"):
		var attacks_per_second := float(stats.call("get_stat", PlayerStats.AUTO_ATTACK_SPEED))
		if attacks_per_second > 0.0:
			return 1.0 / attacks_per_second

	return maxf(attack_interval, 0.01)


func _attack_impact_fraction_override(attacker: Node3D) -> float:
	var animation := attacker.get_node_or_null("Animation") if attacker != null else null
	if (
		animation == null
		or not animation.has_method("has_attack_impact_timing_override")
		or not bool(animation.call("has_attack_impact_timing_override"))
		or not animation.has_method("get_attack_impact_fraction")
	):
		return -1.0

	return clampf(float(animation.call("get_attack_impact_fraction", windup_fraction)), 0.0, 0.95)


func _is_in_attack_range(attacker: Node3D, target: Variant, extra_range := 0.0) -> bool:
	var target_3d := _valid_target_node(target) as Node3D
	if attacker == null or target_3d == null:
		return false

	var offset := target_3d.global_position - attacker.global_position
	offset.y = 0.0
	return offset.length() <= attack_range + maxf(extra_range, 0.0)


func _find_target_health(target: Variant) -> Node:
	var target_node := _valid_target_node(target)
	if target_node == null:
		return null
	if target_node.has_method("apply_damage"):
		return target_node

	var parent_node := target_node.get_parent()
	if parent_node != null:
		var sibling_health := parent_node.get_node_or_null("Health")
		if sibling_health != null:
			return sibling_health

	return null


func _is_attacker_defeated(attacker: Node3D) -> bool:
	if attacker == null:
		return true

	return _is_health_defeated(attacker.get_node_or_null("Health"))


func _is_target_defeated(target: Variant) -> bool:
	return _is_health_defeated(_find_target_health(target))


func _valid_target_node(target: Variant) -> Node:
	if typeof(target) != TYPE_OBJECT or not is_instance_valid(target):
		return null
	return target as Node


func _is_health_defeated(health: Node) -> bool:
	return (
		health != null
		and health.has_method("is_defeated")
		and health.call("is_defeated") == true
	)
