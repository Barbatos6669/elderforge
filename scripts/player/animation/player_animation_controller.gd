class_name PlayerAnimationController
extends Node

@export var model_root_path: NodePath = NodePath("../Visuals/BaseCharacter")
@export var source_animation_scene: PackedScene
@export var idle_animation_name: StringName = &"Idle"
@export var move_animation_name: StringName = &"Jog_Fwd"
@export var blend_time: float = 0.12
@export var move_speed_scale: float = 1.0

var _animation_player: AnimationPlayer
var _is_moving := false


func _ready() -> void:
	call_deferred("_setup_animation_player")


func set_moving(is_moving: bool) -> void:
	if _animation_player == null:
		_is_moving = is_moving
		return

	if _is_moving == is_moving:
		return

	_is_moving = is_moving
	_play_current_state()


func _setup_animation_player() -> void:
	var model_root := get_node_or_null(model_root_path) as Node
	if model_root == null or source_animation_scene == null:
		return

	var source_root := source_animation_scene.instantiate()
	var source_player := _find_animation_player(source_root)
	if source_player == null:
		source_root.queue_free()
		return

	_animation_player = AnimationPlayer.new()
	_animation_player.name = "RuntimeAnimationPlayer"
	_animation_player.root_node = NodePath("..")
	model_root.add_child(_animation_player)

	var library := AnimationLibrary.new()
	_add_animation_to_library(library, source_player, idle_animation_name)
	_add_animation_to_library(library, source_player, move_animation_name)
	_animation_player.add_animation_library("", library)

	source_root.queue_free()
	_play_current_state(true)


func _add_animation_to_library(
	library: AnimationLibrary,
	source_player: AnimationPlayer,
	animation_name: StringName
) -> void:
	if not source_player.has_animation(animation_name):
		return

	var animation := source_player.get_animation(animation_name).duplicate(true) as Animation
	animation.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(animation_name, animation)


func _play_current_state(force_restart: bool = false) -> void:
	if _animation_player == null:
		return

	var animation_name := move_animation_name if _is_moving else idle_animation_name
	if not force_restart and _animation_player.current_animation == animation_name:
		return

	_animation_player.speed_scale = move_speed_scale if _is_moving else 1.0
	_animation_player.play(animation_name, blend_time)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var animation_player := _find_animation_player(child)
		if animation_player != null:
			return animation_player

	return null
