## Tracks whether an actor is currently in combat.
##
## Other systems call `notify_combat_activity()` when the actor attacks, takes
## damage, casts an offensive spell, or does anything else that should keep
## combat mode active. The state returns to out-of-combat after a quiet delay.
class_name CombatState
extends Node

signal combat_started
signal combat_ended
signal combat_state_changed(is_in_combat: bool)

## Seconds without combat activity before leaving combat mode.
@export_range(0.0, 60.0, 0.1) var out_of_combat_delay := 6.0
## Useful for testing scenes that should begin already flagged as in combat.
@export var starts_in_combat := false

var _is_in_combat := false
var _time_since_activity := 0.0


func _ready() -> void:
	_is_in_combat = starts_in_combat
	_time_since_activity = 0.0
	if _is_in_combat:
		combat_started.emit()
		combat_state_changed.emit(true)


func _process(delta: float) -> void:
	if not _is_in_combat:
		return

	_time_since_activity += maxf(delta, 0.0)
	if _time_since_activity >= out_of_combat_delay:
		force_out_of_combat()


## Keeps the owner in combat and resets the out-of-combat timer.
func notify_combat_activity() -> void:
	_time_since_activity = 0.0
	if _is_in_combat:
		return

	_is_in_combat = true
	combat_started.emit()
	combat_state_changed.emit(true)


## Immediately leaves combat mode.
func force_out_of_combat() -> void:
	if not _is_in_combat:
		return

	_is_in_combat = false
	_time_since_activity = 0.0
	combat_ended.emit()
	combat_state_changed.emit(false)


func is_in_combat() -> bool:
	return _is_in_combat
