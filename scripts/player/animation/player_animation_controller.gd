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
## Optional scene for gathering-only clips that live in another animation pack.
@export var gathering_animation_scene: PackedScene
## Animation name used while standing still.
@export var idle_animation_name: StringName = &"Idle"
## Animation name used while moving.
@export var move_animation_name: StringName = &"Jog_Fwd"
## One-shot animation played when an auto-attack lands.
@export var attack_animation_name: StringName = &"Punch_Jab"
## One-shot animation played when an entity is defeated.
@export var death_animation_name: StringName = &"Death01"
## Fallback looped animation used while the player channels gathering.
@export var gathering_animation_name: StringName = &"Shield_OneShot"
## Looped animation used when gathering logs with an axe.
@export var axe_tree_gathering_animation_name: StringName = &"TreeChopping"
## Blend time used when switching between idle and movement.
@export var blend_time: float = 0.12
## Playback speed for the movement animation.
@export var move_speed_scale: float = 1.0
## Playback speed for the one-shot attack animation.
@export var attack_speed_scale: float = 1.0
## Playback speed for the one-shot death animation.
@export var death_speed_scale: float = 1.0
## Playback speed for the looped gathering animation.
@export var gathering_speed_scale: float = 0.85

var _animation_player: AnimationPlayer
var _animation_library: AnimationLibrary
var _is_moving := false
var _is_attacking := false
var _is_dead := false
var _is_gathering := false
var _active_gathering_animation_name: StringName = &""
var _active_gathering_animation_scene_path := ""
var _animation_profiles_by_path := {}


func _ready() -> void:
	call_deferred("_setup_animation_player")


## Switches between idle and movement animation states.
func set_moving(is_moving: bool) -> void:
	if _animation_player == null:
		_is_moving = is_moving
		return
	if _is_dead:
		_is_moving = is_moving
		return

	if _is_moving == is_moving:
		return

	_is_moving = is_moving
	if _is_attacking:
		return

	_play_current_state()


## Plays or stops the looped gathering animation state.
func set_gathering(is_gathering: bool, context: Dictionary = {}) -> void:
	if _is_dead:
		_is_gathering = false
		return

	var next_gathering_animation_name: StringName = &""
	var next_gathering_animation_scene_path := ""
	if is_gathering:
		var animation_data := _gathering_animation_data_for_context(context)
		next_gathering_animation_name = animation_data.get("animation_name", &"")
		next_gathering_animation_scene_path = String(animation_data.get("animation_scene_path", ""))

	if _animation_player == null:
		_is_gathering = is_gathering
		_active_gathering_animation_name = next_gathering_animation_name
		_active_gathering_animation_scene_path = next_gathering_animation_scene_path
		return

	if (
		_is_gathering == is_gathering
		and _active_gathering_animation_name == next_gathering_animation_name
		and _active_gathering_animation_scene_path == next_gathering_animation_scene_path
	):
		return

	_is_gathering = is_gathering
	_active_gathering_animation_name = next_gathering_animation_name
	_active_gathering_animation_scene_path = next_gathering_animation_scene_path
	if _is_attacking:
		return

	_play_current_state(true)


## Plays the configured one-shot auto-attack animation, then resumes idle/move.
func play_attack(speed_scale: float = 1.0) -> void:
	if _is_dead:
		return
	if _animation_player == null or not _animation_player.has_animation(attack_animation_name):
		return

	_is_attacking = true
	_animation_player.speed_scale = maxf(speed_scale, 0.01) * attack_speed_scale
	_animation_player.play(attack_animation_name, blend_time)


## Plays the configured one-shot death animation and returns its duration.
func play_death(speed_scale: float = 1.0) -> float:
	_is_dead = true
	_is_attacking = false
	_is_gathering = false
	_is_moving = false

	if _animation_player == null or not _animation_player.has_animation(death_animation_name):
		return 0.0

	var effective_speed := maxf(speed_scale, 0.01) * death_speed_scale
	_animation_player.speed_scale = effective_speed
	_animation_player.play(death_animation_name, blend_time)

	var animation := _animation_player.get_animation(death_animation_name)
	if animation == null:
		return 0.0

	return animation.length / effective_speed


## Restores idle/move state after a respawn or other hard reset.
func reset_animation_state() -> void:
	_is_dead = false
	_is_attacking = false
	_is_gathering = false
	_is_moving = false
	_active_gathering_animation_name = &""
	_active_gathering_animation_scene_path = ""
	_play_current_state(true)


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
	_animation_library = AnimationLibrary.new()
	_add_animation_to_library(_animation_library, source_player, idle_animation_name, true)
	_add_animation_to_library(_animation_library, source_player, move_animation_name, true)
	_add_animation_to_library(_animation_library, source_player, attack_animation_name, false)
	_add_animation_to_library(_animation_library, source_player, death_animation_name, false)
	_add_gathering_animation_to_library(_animation_library, source_player)
	_animation_player.add_animation_library("", _animation_library)
	_animation_player.animation_finished.connect(_on_animation_finished)

	source_root.queue_free()
	_play_current_state(true)


func _add_animation_to_library(
	library: AnimationLibrary,
	source_player: AnimationPlayer,
	animation_name: StringName,
	should_loop: bool
) -> void:
	if source_player == null:
		return

	if not source_player.has_animation(animation_name):
		return

	var animation := source_player.get_animation(animation_name).duplicate(true) as Animation
	animation.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE
	library.add_animation(animation_name, animation)


func _add_gathering_animation_to_library(
	library: AnimationLibrary,
	fallback_source_player: AnimationPlayer
) -> void:
	var gathering_source_player := fallback_source_player
	var source_root: Node = null

	if gathering_animation_scene != null:
		source_root = gathering_animation_scene.instantiate()
		gathering_source_player = _find_animation_player(source_root)

	_add_animation_to_library(library, gathering_source_player, gathering_animation_name, true)
	_add_animation_to_library(library, gathering_source_player, axe_tree_gathering_animation_name, true)

	if source_root != null:
		source_root.queue_free()


func _play_current_state(force_restart: bool = false) -> void:
	if _animation_player == null:
		return
	if _is_attacking or _is_dead:
		return

	var animation_name := _current_state_animation_name()
	if not force_restart and _animation_player.current_animation == animation_name:
		return

	_animation_player.speed_scale = _current_state_speed_scale()
	_animation_player.play(animation_name, blend_time)


func _current_state_animation_name() -> StringName:
	var active_gathering_animation_name := _current_gathering_animation_name()
	if _is_gathering and not String(active_gathering_animation_name).is_empty():
		return active_gathering_animation_name

	return move_animation_name if _is_moving else idle_animation_name


func _current_state_speed_scale() -> float:
	if _is_gathering and not String(_current_gathering_animation_name()).is_empty():
		return gathering_speed_scale

	return move_speed_scale if _is_moving else 1.0


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == death_animation_name:
		return
	if animation_name != attack_animation_name:
		return

	_is_attacking = false
	_play_current_state(true)


func _gathering_animation_data_for_context(context: Dictionary) -> Dictionary:
	var resource_family_id := String(context.get("resource_family_id", ""))
	var animation_profile := _load_equipment_animation_profile(String(context.get("tool_animation_profile_path", "")))
	if animation_profile != null and animation_profile.has_method("get_gathering_animation_name"):
		var profile_animation_name := StringName(String(animation_profile.call("get_gathering_animation_name", resource_family_id)))
		if not String(profile_animation_name).is_empty():
			return {
				"animation_name": profile_animation_name,
				"animation_scene_path": String(animation_profile.get("gathering_animation_scene_path")),
			}

	var tool_family_id := String(context.get("tool_family_id", ""))
	if resource_family_id == "logs" and tool_family_id == "axe":
		return {"animation_name": axe_tree_gathering_animation_name, "animation_scene_path": ""}

	return {"animation_name": gathering_animation_name, "animation_scene_path": ""}


func _current_gathering_animation_name() -> StringName:
	if _animation_player == null:
		return &""
	if _ensure_gathering_animation_loaded(_active_gathering_animation_name, _active_gathering_animation_scene_path):
		return _active_gathering_animation_name
	if _ensure_gathering_animation_loaded(gathering_animation_name, ""):
		return gathering_animation_name

	return &""


func _ensure_gathering_animation_loaded(animation_name: StringName, animation_scene_path: String = "") -> bool:
	if _animation_player == null or _animation_library == null or String(animation_name).is_empty():
		return false
	if _animation_player.has_animation(animation_name):
		var animation := _animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
		return true

	var source_root: Node = null
	var source_player: AnimationPlayer = null
	if not animation_scene_path.is_empty() and ResourceLoader.exists(animation_scene_path, "PackedScene"):
		var animation_scene := load(animation_scene_path) as PackedScene
		source_root = animation_scene.instantiate() if animation_scene != null else null
		source_player = _find_animation_player(source_root) if source_root != null else null
	elif gathering_animation_scene != null:
		source_root = gathering_animation_scene.instantiate()
		source_player = _find_animation_player(source_root)
	else:
		source_root = source_animation_scene.instantiate()
		source_player = _find_animation_player(source_root)

	_add_animation_to_library(_animation_library, source_player, animation_name, true)
	if source_root != null:
		source_root.queue_free()

	return _animation_player.has_animation(animation_name)


func _load_equipment_animation_profile(profile_path: String) -> Resource:
	if profile_path.is_empty():
		return null
	if _animation_profiles_by_path.has(profile_path):
		return _animation_profiles_by_path[profile_path] as Resource
	if not ResourceLoader.exists(profile_path):
		return null

	var profile := load(profile_path) as Resource
	_animation_profiles_by_path[profile_path] = profile
	return profile


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var animation_player := _find_animation_player(child)
		if animation_player != null:
			return animation_player

	return null
