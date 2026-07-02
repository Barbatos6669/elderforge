## Reusable timed-action state for casts, gathering, and other channels.
##
## This node owns only channel timing. Gameplay systems decide when to start or
## cancel a channel, then listen for completion and apply their own results.
class_name PlayerChanneling
extends Node

signal channel_started(action_name: String, duration: float, context: Dictionary)
signal channel_progress_changed(progress: float, elapsed: float, remaining: float)
signal channel_completed(context: Dictionary)
signal channel_cancelled(reason: String, context: Dictionary)

var _is_channeling := false
var _action_name := ""
var _duration := 0.0
var _elapsed := 0.0
var _context := {}


## Starts a new channel and replaces any existing one.
func start_channel(action_name: String, duration: float, context: Dictionary = {}) -> void:
	if _is_channeling:
		cancel_channel("Interrupted")

	_action_name = action_name
	_duration = maxf(duration, 0.01)
	_elapsed = 0.0
	_context = context.duplicate(true)
	_is_channeling = true
	channel_started.emit(_action_name, _duration, _context)
	channel_progress_changed.emit(0.0, 0.0, _duration)


## Cancels the current channel, if any.
func cancel_channel(reason: String = "Cancelled") -> void:
	if not _is_channeling:
		return

	var cancelled_context := _context.duplicate(true)
	_reset()
	channel_cancelled.emit(reason, cancelled_context)


## Advances the active channel by one frame.
func update_channel(delta: float) -> void:
	if not _is_channeling:
		return

	_elapsed = minf(_elapsed + maxf(delta, 0.0), _duration)
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	var remaining := maxf(_duration - _elapsed, 0.0)
	channel_progress_changed.emit(progress, _elapsed, remaining)

	if _elapsed >= _duration:
		var completed_context := _context.duplicate(true)
		_reset()
		channel_completed.emit(completed_context)


func is_channeling() -> bool:
	return _is_channeling


func get_action_name() -> String:
	return _action_name


func get_progress() -> float:
	if not _is_channeling or _duration <= 0.0:
		return 0.0

	return clampf(_elapsed / _duration, 0.0, 1.0)


func get_context() -> Dictionary:
	return _context.duplicate(true)


func is_channel_type(channel_type: String) -> bool:
	return _is_channeling and String(_context.get("type", "")) == channel_type


func _reset() -> void:
	_is_channeling = false
	_action_name = ""
	_duration = 0.0
	_elapsed = 0.0
	_context = {}
