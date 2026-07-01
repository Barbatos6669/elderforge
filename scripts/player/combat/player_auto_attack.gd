## Local-player auto-attack prototype.
##
## This owns only the attack loop: validation, range checks, cooldown timing,
## and applying damage to a target health component. Target selection and
## movement stay in their existing player modules.
class_name PlayerAutoAttack
extends Node

signal attack_started(target: Node)
signal attack_landed(target: Node, damage: float)
signal attack_stopped

## Damage dealt by each prototype auto-attack hit.
@export var attack_damage: float = 12.0
## Seconds between auto-attack hits.
@export var attack_interval: float = 1.2
## Maximum distance from player origin to target origin for attacks to land.
@export var attack_range: float = 1.8
## Desired stopping distance while moving into melee range.
@export var approach_distance: float = 1.35
## Keeps this module from attacking friendly or neutral selectables.
@export var require_hostile_target: bool = true

var _target: Node
var _cooldown_remaining := 0.0


## Starts attacking the target if it is valid. Returns true on success.
func start_attack(target: Node, attacker: Node3D) -> bool:
	if not can_attack_target(target):
		return false

	_target = target
	_cooldown_remaining = 0.0
	attack_started.emit(_target)
	return true


## Stops the current auto-attack loop.
func stop_attack() -> void:
	if _target == null:
		return

	_target = null
	_cooldown_remaining = 0.0
	attack_stopped.emit()


## Advances cooldown and lands attacks while the current target remains valid.
func update_attack(attacker: Node3D, delta: float) -> void:
	if _target == null:
		return

	if not can_attack_target(_target) or _is_target_defeated(_target):
		stop_attack()
		return

	if not is_target_in_range(attacker):
		_cooldown_remaining = 0.0
		return

	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining <= 0.0:
		_try_land_attack(attacker)


## Returns true when this module can initiate attacks against the given target.
func can_attack_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	if require_hostile_target:
		return target.has_method("is_hostile") and target.call("is_hostile") == true

	return true


## Returns the target currently being auto-attacked.
func get_current_attack_target() -> Node:
	return _target


## Returns true while this module has an active target.
func has_active_target() -> bool:
	return _target != null and is_instance_valid(_target)


## Returns true when the attacker is close enough to land auto-attacks.
func is_target_in_range(attacker: Node3D) -> bool:
	return _target != null and _is_in_attack_range(attacker, _target)


## Returns the horizontal direction from the attacker to the active target.
func get_direction_to_target(attacker: Node3D) -> Vector3:
	if attacker == null or _target == null:
		return Vector3.ZERO

	var target_3d := _target as Node3D
	if target_3d == null:
		return Vector3.ZERO

	var direction := target_3d.global_position - attacker.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return Vector3.ZERO

	return direction.normalized()


## Returns a world destination just outside the target, suitable for melee chase.
func get_approach_destination(attacker: Node3D) -> Vector3:
	if attacker == null or _target == null:
		return Vector3.ZERO

	var target_3d := _target as Node3D
	if target_3d == null:
		return attacker.global_position

	var direction_to_target := get_direction_to_target(attacker)
	if direction_to_target == Vector3.ZERO:
		return target_3d.global_position

	var destination := target_3d.global_position - direction_to_target * approach_distance
	destination.y = attacker.global_position.y
	return destination


func _try_land_attack(attacker: Node3D) -> void:
	if _target == null or attacker == null:
		return

	if not _is_in_attack_range(attacker, _target):
		return

	var health := _find_target_health(_target)
	if health == null or not health.has_method("apply_damage"):
		return

	var applied_damage: float = health.call("apply_damage", attack_damage)
	if applied_damage <= 0.0:
		return

	_cooldown_remaining = attack_interval
	attack_landed.emit(_target, applied_damage)

	if _is_health_defeated(health):
		stop_attack()


func _is_in_attack_range(attacker: Node3D, target: Node) -> bool:
	var target_3d := target as Node3D
	if target_3d == null:
		return false

	var offset := target_3d.global_position - attacker.global_position
	offset.y = 0.0
	return offset.length() <= attack_range


func _find_target_health(target: Node) -> Node:
	if target.has_method("apply_damage"):
		return target

	var parent_node := target.get_parent()
	if parent_node != null:
		var sibling_health := parent_node.get_node_or_null("Health")
		if sibling_health != null:
			return sibling_health

	return null


func _is_target_defeated(target: Node) -> bool:
	var health := _find_target_health(target)
	return _is_health_defeated(health)


func _is_health_defeated(health: Node) -> bool:
	return (
		health != null
		and health.has_method("is_defeated")
		and health.call("is_defeated") == true
	)
