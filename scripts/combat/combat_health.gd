## Reusable health pool for selectable combat entities.
##
## This is intentionally small for the first combat pass: it stores current and
## maximum health, accepts damage, and emits ratio changes for UI such as target
## health bars.
class_name CombatHealth
extends Node

signal health_changed(current_health: float, max_health: float, health_ratio: float)
signal damage_taken(amount: float)
signal defeated

## Maximum health for this combat entity.
@export var max_health: float = 100.0
## Current health. Values are clamped against `max_health`.
@export var current_health: float = 100.0
## Passive health restored per second. Leave at zero for entities that do not regenerate.
@export var health_regeneration_per_second: float = 0.0
## Allows combat state or debuffs to pause passive regeneration.
@export var regeneration_enabled: bool = true
## Allows combat systems to temporarily prevent damage.
@export var can_take_damage: bool = true

var _is_defeated := false


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	_is_defeated = current_health <= 0.0
	_emit_health_changed()


func _process(delta: float) -> void:
	if not can_regenerate():
		return

	heal(health_regeneration_per_second * maxf(delta, 0.0))


## Applies damage and returns the amount that actually changed health.
func apply_damage(amount: float) -> float:
	if not can_take_damage or amount <= 0.0 or _is_defeated:
		return 0.0

	var previous_health := current_health
	current_health = clampf(current_health - amount, 0.0, max_health)
	var applied_damage := previous_health - current_health
	if applied_damage <= 0.0:
		return 0.0

	damage_taken.emit(applied_damage)
	_emit_health_changed()
	if current_health <= 0.0 and not _is_defeated:
		_is_defeated = true
		defeated.emit()

	return applied_damage


## Restores health and returns the amount that actually changed health.
func heal(amount: float) -> float:
	if amount <= 0.0 or _is_defeated:
		return 0.0

	var previous_health := current_health
	current_health = clampf(current_health + amount, 0.0, max_health)
	var applied_healing := current_health - previous_health
	if applied_healing <= 0.0:
		return 0.0

	_emit_health_changed()
	return applied_healing


## Restores this health pool to a specific value, clamped against max health.
func set_current_health(value: float) -> void:
	current_health = clampf(value, 0.0, max_health)
	_is_defeated = current_health <= 0.0
	_emit_health_changed()


## Restores this health pool to full health.
func reset_to_full() -> void:
	set_current_health(max_health)


## Enables or disables passive regeneration without changing the regen stat.
func set_regeneration_enabled(value: bool) -> void:
	regeneration_enabled = value


## Returns true when passive regeneration can tick this frame.
func can_regenerate() -> bool:
	return (
		regeneration_enabled
		and health_regeneration_per_second > 0.0
		and not _is_defeated
		and current_health < max_health
	)


## Returns current health divided by max health.
func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0

	return clampf(current_health / max_health, 0.0, 1.0)


## Returns whether this health pool has reached zero.
func is_defeated() -> bool:
	return _is_defeated


func _emit_health_changed() -> void:
	health_changed.emit(current_health, max_health, get_health_ratio())
