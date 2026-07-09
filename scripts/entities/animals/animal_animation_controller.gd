## Runtime animation bridge for imported animal models.
##
## Animal GLBs often bring their own AnimationPlayer and clip names. This
## wrapper keeps animal AI code from knowing those import details; AI asks for
## idle, walk, attack, or death states and this node handles playback.
class_name AnimalAnimationController
extends Node

## Root node of the instantiated animal model.
@export var model_root_path: NodePath = NodePath("../Visuals/RatModel")
## Animation name used while standing still.
@export var idle_animation_name: StringName = &"Idle"
## Animation name used while moving.
@export var walk_animation_name: StringName = &"Walk"
## Optional one-shot attack animation.
@export var attack_animation_name: StringName = &"Attack"
## One-shot animation played when the animal is defeated.
@export var death_animation_name: StringName = &"Death"
## Blend time used when switching between states.
@export var blend_time: float = 0.12
## Playback speed for idle animation.
@export var idle_speed_scale: float = 1.0
## Playback speed for walk animation.
@export var walk_speed_scale: float = 1.0
## Playback speed for one-shot attack animation.
@export var attack_speed_scale: float = 1.0
## Playback speed for death animation.
@export var death_speed_scale: float = 1.0

var _animation_player: AnimationPlayer
var _is_moving := false
var _is_attacking := false
var _is_dead := false


func _ready() -> void:
	call_deferred("_setup_animation_player")


## Switches the animal between idle and walk loops.
func set_moving(is_moving: bool) -> void:
	if _is_dead:
		_is_moving = false
		return

	_is_moving = is_moving
	if _is_attacking:
		return

	_play_current_state()


## Plays the configured one-shot attack clip, if the model has one.
func play_attack(speed_scale: float = 1.0) -> void:
	if _is_dead or _animation_player == null:
		return
	if not _animation_player.has_animation(attack_animation_name):
		return

	_is_attacking = true
	_animation_player.speed_scale = maxf(speed_scale, 0.01) * attack_speed_scale
	_animation_player.play(attack_animation_name, blend_time)


## Plays the configured death clip and returns its effective duration.
func play_death(speed_scale: float = 1.0) -> float:
	_is_dead = true
	_is_attacking = false
	_is_moving = false

	if _animation_player == null or not _animation_player.has_animation(death_animation_name):
		return 0.0

	var effective_speed := maxf(speed_scale, 0.01) * death_speed_scale
	_animation_player.speed_scale = effective_speed
	_animation_player.play(death_animation_name, blend_time)

	var animation := _animation_player.get_animation(death_animation_name)
	return animation.length / effective_speed if animation != null else 0.0


## Restores the animal to its idle state after respawn.
func reset_animation_state() -> void:
	_is_dead = false
	_is_attacking = false
	_is_moving = false
	_play_current_state(true)


func _setup_animation_player() -> void:
	var model_root := get_node_or_null(model_root_path)
	if model_root == null:
		return

	_animation_player = _find_animation_player(model_root)
	if _animation_player == null:
		push_warning("AnimalAnimationController could not find an AnimationPlayer under %s." % model_root_path)
		return

	_make_animation_loop(idle_animation_name)
	_make_animation_loop(walk_animation_name)
	if _animation_player.has_signal("animation_finished"):
		_animation_player.animation_finished.connect(_on_animation_finished)
	_play_current_state(true)


func _play_current_state(force_restart: bool = false) -> void:
	if _animation_player == null or _is_dead or _is_attacking:
		return

	var animation_name := walk_animation_name if _is_moving else idle_animation_name
	if not _animation_player.has_animation(animation_name):
		return
	if not force_restart and _animation_player.current_animation == animation_name:
		return

	_animation_player.speed_scale = walk_speed_scale if _is_moving else idle_speed_scale
	_animation_player.play(animation_name, blend_time)


func _make_animation_loop(animation_name: StringName) -> void:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return

	var animation := _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == death_animation_name:
		return
	if animation_name != attack_animation_name:
		return

	_is_attacking = false
	_play_current_state(true)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found

	return null
