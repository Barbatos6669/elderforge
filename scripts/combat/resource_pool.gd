## Reusable current/max resource pool.
##
## Use this for mana, energy, stamina, or any future resource that regenerates,
## can be spent, and needs to drive HUD bars.
class_name ResourcePool
extends Node

signal resource_changed(current_resource: float, max_resource: float, resource_ratio: float)
signal resource_spent(amount: float)
signal resource_gained(amount: float)

## Display/debug name for this pool, such as Mana or Energy.
@export var display_name := "Resource"
## Maximum amount this pool can hold.
@export var max_resource: float = 100.0
## Current amount, clamped against `max_resource`.
@export var current_resource: float = 100.0
## Passive resource restored per second.
@export var regeneration_per_second: float = 0.0
## Allows combat state or debuffs to pause passive regeneration.
@export var regeneration_enabled := true


func _ready() -> void:
	current_resource = clampf(current_resource, 0.0, max_resource)
	_emit_resource_changed()


func _process(delta: float) -> void:
	if not can_regenerate():
		return

	restore(regeneration_per_second * maxf(delta, 0.0))


## Attempts to spend resource and returns the amount actually spent.
func spend(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var previous_resource := current_resource
	current_resource = clampf(current_resource - amount, 0.0, max_resource)
	var spent_amount := previous_resource - current_resource
	if spent_amount <= 0.0:
		return 0.0

	resource_spent.emit(spent_amount)
	_emit_resource_changed()
	return spent_amount


## Restores resource and returns the amount actually restored.
func restore(amount: float) -> float:
	if amount <= 0.0:
		return 0.0

	var previous_resource := current_resource
	current_resource = clampf(current_resource + amount, 0.0, max_resource)
	var restored_amount := current_resource - previous_resource
	if restored_amount <= 0.0:
		return 0.0

	resource_gained.emit(restored_amount)
	_emit_resource_changed()
	return restored_amount


func set_current_resource(value: float) -> void:
	current_resource = clampf(value, 0.0, max_resource)
	_emit_resource_changed()


func set_max_resource(value: float, should_fill := false) -> void:
	max_resource = maxf(value, 0.0)
	current_resource = max_resource if should_fill else clampf(current_resource, 0.0, max_resource)
	_emit_resource_changed()


func set_regeneration_enabled(value: bool) -> void:
	regeneration_enabled = value


func can_regenerate() -> bool:
	return (
		regeneration_enabled
		and regeneration_per_second > 0.0
		and current_resource < max_resource
	)


func get_resource_ratio() -> float:
	if max_resource <= 0.0:
		return 0.0

	return clampf(current_resource / max_resource, 0.0, 1.0)


func _emit_resource_changed() -> void:
	resource_changed.emit(current_resource, max_resource, get_resource_ratio())
