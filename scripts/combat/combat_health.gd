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
signal damage_immunity_changed(is_active: bool, remaining_seconds: float)
signal absorb_shield_changed(current_shield: float, max_shield: float, remaining_seconds: float)

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
var _damage_immunity_remaining_seconds := 0.0
var _absorb_shield_current := 0.0
var _absorb_shield_max := 0.0
var _absorb_shield_remaining_seconds := 0.0


func _ready() -> void:
	current_health = clampf(current_health, 0.0, max_health)
	_is_defeated = current_health <= 0.0
	_emit_health_changed()


func _process(delta: float) -> void:
	_tick_damage_immunity(maxf(delta, 0.0))
	_tick_absorb_shield(maxf(delta, 0.0))
	if not can_regenerate():
		return

	heal(health_regeneration_per_second * maxf(delta, 0.0))


## Applies damage and returns the amount that actually changed health.
func apply_damage(amount: float) -> float:
	if not can_take_damage or is_damage_immune() or amount <= 0.0 or _is_defeated:
		return 0.0

	var remaining_damage := _absorb_damage(amount)
	if remaining_damage <= 0.0:
		return 0.0

	var previous_health := current_health
	current_health = clampf(current_health - remaining_damage, 0.0, max_health)
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
##
## Replicated combat state can request damage/defeat signals so remote clients
## still show hit numbers and death visuals even when the attack happened
## somewhere else.
func set_current_health(value: float, emit_damage: bool = false) -> void:
	var previous_health := current_health
	var was_defeated := _is_defeated
	current_health = clampf(value, 0.0, max_health)
	_is_defeated = current_health <= 0.0
	if _is_defeated:
		clear_absorb_shield()

	var applied_damage := previous_health - current_health
	if emit_damage and applied_damage > 0.0:
		damage_taken.emit(applied_damage)

	_emit_health_changed()
	if _is_defeated and not was_defeated:
		defeated.emit()


## Updates maximum health while keeping current health valid.
func set_max_health(value: float, should_fill := false) -> void:
	max_health = maxf(value, 0.0)
	current_health = max_health if should_fill else clampf(current_health, 0.0, max_health)
	_is_defeated = current_health <= 0.0
	_emit_health_changed()


## Restores this health pool to full health.
func reset_to_full() -> void:
	clear_damage_immunity()
	clear_absorb_shield()
	set_current_health(max_health)


## Grants a temporary damage-immunity window, extending any active window when
## the new duration is longer. Permanent damage locks continue to use
## `can_take_damage`; this timer is for short ability effects.
func grant_damage_immunity(duration_seconds: float) -> void:
	var safe_duration := maxf(duration_seconds, 0.0)
	if safe_duration <= 0.0 or _is_defeated:
		return

	_damage_immunity_remaining_seconds = maxf(
		_damage_immunity_remaining_seconds,
		safe_duration
	)
	damage_immunity_changed.emit(true, _damage_immunity_remaining_seconds)


## Ends any active temporary damage-immunity window immediately.
func clear_damage_immunity() -> void:
	if _damage_immunity_remaining_seconds <= 0.0:
		return

	_damage_immunity_remaining_seconds = 0.0
	damage_immunity_changed.emit(false, 0.0)


## Grants a temporary finite damage shield. Incoming damage drains this pool
## before health changes, and overflow continues into health.
func grant_absorb_shield(amount: float, duration_seconds: float) -> void:
	var safe_amount := maxf(amount, 0.0)
	var safe_duration := maxf(duration_seconds, 0.0)
	if safe_amount <= 0.0 or safe_duration <= 0.0 or _is_defeated:
		return

	_absorb_shield_current = maxf(_absorb_shield_current, safe_amount)
	_absorb_shield_max = maxf(_absorb_shield_max, safe_amount)
	_absorb_shield_remaining_seconds = maxf(
		_absorb_shield_remaining_seconds,
		safe_duration
	)
	_emit_absorb_shield_changed()


## Ends any active finite damage shield immediately.
func clear_absorb_shield() -> void:
	if (
		_absorb_shield_current <= 0.0
		and _absorb_shield_max <= 0.0
		and _absorb_shield_remaining_seconds <= 0.0
	):
		return

	_absorb_shield_current = 0.0
	_absorb_shield_max = 0.0
	_absorb_shield_remaining_seconds = 0.0
	_emit_absorb_shield_changed()


## Returns whether short-lived ability protection currently blocks damage.
func is_damage_immune() -> bool:
	return _damage_immunity_remaining_seconds > 0.0


## Returns the remaining temporary protection time in seconds.
func get_damage_immunity_remaining_seconds() -> float:
	return maxf(_damage_immunity_remaining_seconds, 0.0)


## Returns whether a finite damage shield is currently active.
func has_absorb_shield() -> bool:
	return _absorb_shield_current > 0.0 and _absorb_shield_remaining_seconds > 0.0


## Returns the current finite shield amount.
func get_absorb_shield_current() -> float:
	return maxf(_absorb_shield_current, 0.0)


## Returns the maximum amount for the current finite shield.
func get_absorb_shield_max() -> float:
	return maxf(_absorb_shield_max, 0.0)


## Returns the remaining finite shield time in seconds.
func get_absorb_shield_remaining_seconds() -> float:
	return maxf(_absorb_shield_remaining_seconds, 0.0)


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


func _tick_damage_immunity(delta: float) -> void:
	if _damage_immunity_remaining_seconds <= 0.0:
		return

	_damage_immunity_remaining_seconds = maxf(
		_damage_immunity_remaining_seconds - delta,
		0.0
	)
	if _damage_immunity_remaining_seconds <= 0.0:
		damage_immunity_changed.emit(false, 0.0)


func _tick_absorb_shield(delta: float) -> void:
	if not has_absorb_shield():
		return

	_absorb_shield_remaining_seconds = maxf(
		_absorb_shield_remaining_seconds - delta,
		0.0
	)
	if _absorb_shield_remaining_seconds <= 0.0:
		clear_absorb_shield()


func _absorb_damage(amount: float) -> float:
	if not has_absorb_shield():
		return amount

	var absorbed := minf(amount, _absorb_shield_current)
	_absorb_shield_current = maxf(_absorb_shield_current - absorbed, 0.0)
	if _absorb_shield_current <= 0.0:
		clear_absorb_shield()
	else:
		_emit_absorb_shield_changed()
	return maxf(amount - absorbed, 0.0)


func _emit_absorb_shield_changed() -> void:
	absorb_shield_changed.emit(
		get_absorb_shield_current(),
		get_absorb_shield_max(),
		get_absorb_shield_remaining_seconds()
	)
