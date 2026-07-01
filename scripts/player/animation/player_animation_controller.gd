## Runtime animation bridge for the placeholder player character.
##
## The model and animation pack are imported as separate scenes. This script
## copies only the needed animations into a runtime AnimationPlayer under the
## model, keeping the player prefab small and easy to swap later.
class_name PlayerAnimationController
extends Node

## Root node of the instantiated character model.
@export var model_root_path: NodePath = NodePath("../Visuals/BaseCharacter")
## Scene that contains the source AnimationPlayer and animation clips.
@export var source_animation_scene: PackedScene
## Animation name used while standing still.
@export var idle_animation_name: StringName = &"Idle"
## Animation name used while moving.
@export var move_animation_name: StringName = &"Jog_Fwd"
## One-shot animation played when an auto-attack lands.
@export var attack_animation_name: StringName = &"Punch_Jab"
## Blend time used when switching between idle and movement.
@export var blend_time: float = 0.12
## Playback speed for the movement animation.
@export var move_speed_scale: float = 1.0
## Playback speed for the one-shot attack animation.
@export var attack_speed_scale: float = 1.0

var _animation_player: AnimationPlayer
var _is_moving := false
var _is_attacking := false


func _ready() -> void:
	call_deferred("_setup_animation_player")


## Switches between idle and movement animation states.
func set_moving(is_moving: bool) -> void:
	if _animation_player == null:
		_is_moving = is_moving
		return

	if _is_moving == is_moving:
		return

	_is_moving = is_moving
	if _is_attacking:
		return

	_play_current_state()


## Plays the configured one-shot auto-attack animation, then resumes idle/move.
func play_attack() -> void:
	if _animation_player == null or not _animation_player.has_animation(attack_animation_name):
		return

	_is_attacking = true
	_animation_player.speed_scale = attack_speed_scale
	_animation_player.play(attack_animation_name, blend_time)


## Returns true when the runtime player is currently playing the move animation.
func is_playing_move_animation() -> bool:
	return (
		_animation_player != null
		and _animation_player.current_animation == move_animation_name
	)


## Returns normalized progress through the current animation, from 0.0 to 1.0.
func get_current_animation_progress() -> float:
	if _animation_player == null or _animation_player.current_animation_length <= 0.0:
		return 0.0

	return fposmod(
		_animation_player.current_animation_position / _animation_player.current_animation_length,
		1.0
	)


func _setup_animation_player() -> void:
	var model_root := get_node_or_null(model_root_path) as Node
	if model_root == null or source_animation_scene == null:
		return

	# Instantiate the source only long enough to copy animations from it.
	var source_root := source_animation_scene.instantiate()
	var source_player := _find_animation_player(source_root)
	if source_player == null:
		source_root.queue_free()
		return

	_animation_player = AnimationPlayer.new()
	_animation_player.name = "RuntimeAnimationPlayer"
	_animation_player.root_node = NodePath("..")
	model_root.add_child(_animation_player)

	# Duplicating clips keeps imports untouched and allows runtime loop settings.
	var library := AnimationLibrary.new()
	_add_animation_to_library(library, source_player, idle_animation_name, true)
	_add_animation_to_library(library, source_player, move_animation_name, true)
	_add_animation_to_library(library, source_player, attack_animation_name, false)
	_animation_player.add_animation_library("", library)
	_animation_player.animation_finished.connect(_on_animation_finished)

	source_root.queue_free()
	_play_current_state(true)


func _add_animation_to_library(
	library: AnimationLibrary,
	source_player: AnimationPlayer,
	animation_name: StringName,
	should_loop: bool
) -> void:
	if not source_player.has_animation(animation_name):
		return

	var animation := source_player.get_animation(animation_name).duplicate(true) as Animation
	animation.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE
	library.add_animation(animation_name, animation)


func _play_current_state(force_restart: bool = false) -> void:
	if _animation_player == null:
		return
	if _is_attacking:
		return

	var animation_name := move_animation_name if _is_moving else idle_animation_name
	if not force_restart and _animation_player.current_animation == animation_name:
		return

	_animation_player.speed_scale = move_speed_scale if _is_moving else 1.0
	_animation_player.play(animation_name, blend_time)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != attack_animation_name:
		return

	_is_attacking = false
	_play_current_state(true)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var animation_player := _find_animation_player(child)
		if animation_player != null:
			return animation_player

	return null
