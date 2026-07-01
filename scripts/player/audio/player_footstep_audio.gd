## Plays player footsteps using a surface set and animation contact points.
##
## The preferred path is animation-synced playback. If the animation controller
## is unavailable, the script falls back to a simple timer from the surface set.
class_name PlayerFootstepAudio
extends AudioStreamPlayer

## Current footstep sound set, such as grass or hard surface.
@export var surface_set: FootstepSurfaceSet
## PlayerAnimationController used for animation-synced foot contact timing.
@export var animation_controller_path: NodePath = NodePath("../Animation")
## Normalized jog animation positions where feet contact the ground.
@export var foot_contact_points := PackedFloat32Array([0.12, 0.62])

@onready var _animation_controller := get_node_or_null(animation_controller_path)

var _is_moving := false
var _fallback_time_until_step := 0.0
var _last_animation_progress := -1.0
var _next_stream_index := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_apply_surface_set()


## Swaps the active footstep surface at runtime.
##
## Terrain detection can call this later when the player crosses surface types.
func set_surface_set(new_surface_set: FootstepSurfaceSet) -> void:
	surface_set = new_surface_set
	_next_stream_index = 0
	_apply_surface_set()


## Enables or disables footstep playback based on player movement state.
func set_moving(is_moving: bool) -> void:
	if _is_moving == is_moving:
		return

	_is_moving = is_moving
	_fallback_time_until_step = 0.0
	_last_animation_progress = -1.0


func _physics_process(delta: float) -> void:
	if not _is_moving or surface_set == null or not surface_set.has_streams():
		return

	if _sync_to_animation_contacts():
		return

	_play_fallback_step(delta)


func _sync_to_animation_contacts() -> bool:
	if _animation_controller == null:
		return false

	if not _animation_controller.is_playing_move_animation():
		# Animation exists but is not in a step-producing state, so suppress fallback.
		_last_animation_progress = -1.0
		return true

	var current_progress: float = _animation_controller.get_current_animation_progress()
	if _last_animation_progress < 0.0:
		_last_animation_progress = current_progress
		return true

	for contact_point in foot_contact_points:
		if _did_pass_contact_point(_last_animation_progress, current_progress, contact_point):
			_play_step()
			break

	_last_animation_progress = current_progress
	return true


func _did_pass_contact_point(previous: float, current: float, contact_point: float) -> bool:
	if current >= previous:
		return previous < contact_point and contact_point <= current

	# Handle loop wrap, for example from 0.98 back to 0.02.
	return contact_point > previous or contact_point <= current


func _play_fallback_step(delta: float) -> void:
	_fallback_time_until_step -= delta
	if _fallback_time_until_step > 0.0:
		return

	_play_step()
	_fallback_time_until_step = surface_set.fallback_step_interval


func _play_step() -> void:
	stream = surface_set.streams[_next_stream_index]
	_next_stream_index = (_next_stream_index + 1) % surface_set.streams.size()
	pitch_scale = _rng.randf_range(
		1.0 - surface_set.pitch_variation,
		1.0 + surface_set.pitch_variation
	)
	# Restart the stream so rapid contact changes never layer old footstep tails.
	stop()
	play()


func _apply_surface_set() -> void:
	if surface_set == null:
		return

	volume_db = surface_set.volume_db
