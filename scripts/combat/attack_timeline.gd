## Reusable timing state for attacks with a wind-up, impact, and recovery.
##
## The timeline does not know about targets, damage, animation, or networking.
## Player and NPC combat systems own those decisions and advance this clock.
class_name AttackTimeline
extends RefCounted

enum Phase {
	READY,
	WINDUP,
	RECOVERY,
}

enum TimelineEvent {
	NONE,
	IMPACT,
	READY,
}

var _phase := Phase.READY
var _remaining_seconds := 0.0
var _cycle_seconds := 0.0
var _windup_seconds := 0.0
var _recovery_seconds := 0.0


## Starts a new attack cycle. Returns false while another cycle is active.
func begin(
	cycle_seconds: float,
	windup_fraction: float,
	minimum_windup_seconds: float,
	maximum_windup_seconds: float
) -> bool:
	if not is_ready():
		return false

	_cycle_seconds = maxf(cycle_seconds, 0.01)
	var minimum_windup := clampf(minimum_windup_seconds, 0.0, _cycle_seconds)
	var maximum_windup := clampf(
		maxf(maximum_windup_seconds, minimum_windup),
		minimum_windup,
		_cycle_seconds
	)
	_windup_seconds = clampf(
		_cycle_seconds * clampf(windup_fraction, 0.0, 1.0),
		minimum_windup,
		maximum_windup
	)
	_recovery_seconds = maxf(_cycle_seconds - _windup_seconds, 0.0)
	_phase = Phase.WINDUP
	_remaining_seconds = _windup_seconds
	return true


## Advances the timeline and reports meaningful phase boundaries.
func advance(delta: float) -> TimelineEvent:
	var elapsed := maxf(delta, 0.0)
	match _phase:
		Phase.WINDUP:
			if elapsed >= _remaining_seconds:
				var overflow := elapsed - _remaining_seconds
				_phase = Phase.RECOVERY
				_remaining_seconds = maxf(_recovery_seconds - overflow, 0.0)
				if _remaining_seconds <= 0.0:
					_phase = Phase.READY
				return TimelineEvent.IMPACT
			_remaining_seconds -= elapsed
		Phase.RECOVERY:
			if elapsed >= _remaining_seconds:
				_remaining_seconds = 0.0
				_phase = Phase.READY
				return TimelineEvent.READY
			_remaining_seconds -= elapsed

	return TimelineEvent.NONE


## Cancels an uncommitted swing while preserving its recovery time.
##
## Keeping recovery prevents move/re-click spam from bypassing attack speed.
func interrupt_windup() -> bool:
	if not is_winding_up():
		return false

	_phase = Phase.RECOVERY
	_remaining_seconds = _recovery_seconds
	return true


## Clears all timing. Reserve this for death, respawn, or hard scene resets.
func reset() -> void:
	_phase = Phase.READY
	_remaining_seconds = 0.0
	_cycle_seconds = 0.0
	_windup_seconds = 0.0
	_recovery_seconds = 0.0


func is_ready() -> bool:
	return _phase == Phase.READY


func is_winding_up() -> bool:
	return _phase == Phase.WINDUP


func is_recovering() -> bool:
	return _phase == Phase.RECOVERY


func get_phase() -> Phase:
	return _phase


func get_remaining_seconds() -> float:
	return _remaining_seconds


func get_cycle_seconds() -> float:
	return _cycle_seconds


func get_windup_seconds() -> float:
	return _windup_seconds


func get_recovery_seconds() -> float:
	return _recovery_seconds
