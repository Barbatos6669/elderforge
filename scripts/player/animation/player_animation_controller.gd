## Runtime animation bridge for the placeholder player character.
##
## The model and animation pack are imported as separate scenes. This script
## copies only the needed animations into a runtime AnimationPlayer under the
## model, keeping the player prefab small and easy to swap later.
class_name PlayerAnimationController
extends Node

const EQUIPMENT_MOVE_ANIMATION_NAME := &"Equipment_Move"

## Root node of the instantiated character model.
@export var model_root_path: NodePath = NodePath("../Visuals/BaseCharacter")
## Optional inventory node. When empty, the local player inventory group is used.
@export var inventory_path: NodePath
## Equipment slot whose animation profile controls combat locomotion.
@export var combat_equipment_slot_id := "main_hand"
## Scene that contains the source AnimationPlayer and animation clips.
@export var source_animation_scene: PackedScene
## Optional scene for gathering-only clips that live in another animation pack.
@export var gathering_animation_scene: PackedScene
## Animation name used while standing still.
@export var idle_animation_name: StringName = &"Idle"
## Animation name used while moving.
@export var move_animation_name: StringName = &"Jog_Fwd"
## One-shot animation played when an auto-attack wind-up begins.
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
var _inventory: Node
var _active_equipment_animation_profile_path := ""
var _active_idle_animation_name: StringName = &""
var _active_move_animation_name: StringName = &""
var _active_attack_animation_name: StringName = &""
var _active_attack_impact_fraction := -1.0
var _fit_active_attack_animation_to_cycle := false
var _queued_weapon_ability_recovery_name: StringName = &""
var _active_one_shot_animation_name: StringName = &""
var _is_weapon_ability_active := false
var _weapon_ability_animation_scene_path := ""
var _weapon_ability_primary_animation_name: StringName = &""
var _weapon_ability_recovery_animation_name: StringName = &""
var _pending_weapon_ability_resume: Dictionary = {}


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	_setup_animation_player()
	_bind_inventory()


## Rebuilds the runtime AnimationPlayer after the visible character model swaps.
func rebuild_animation_player() -> void:
	_capture_weapon_ability_resume()
	if not _is_weapon_ability_active:
		_queued_weapon_ability_recovery_name = &""
		_active_one_shot_animation_name = &""
		_is_attacking = false
	if _animation_player != null and is_instance_valid(_animation_player):
		var animation_parent := _animation_player.get_parent()
		if animation_parent != null:
			animation_parent.remove_child(_animation_player)
		_animation_player.queue_free()
	_animation_player = null
	_animation_library = null
	call_deferred("_initialize")


## Allows a playable scene or multiplayer owner to bind an inventory directly.
func set_inventory(inventory: Node) -> void:
	if _inventory == inventory:
		_refresh_equipped_animation_profile(true)
		return

	_disconnect_inventory()
	_inventory = inventory
	_connect_inventory()
	_refresh_equipped_animation_profile(true)


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


## Plays one complete attack clip inside the stat-driven auto-attack cycle.
func play_attack(attacks_per_second: float = 1.0) -> void:
	if _is_dead:
		return
	if _is_weapon_ability_active:
		return
	if not _ensure_animation_player_ready():
		return

	var active_attack_animation_name := _current_attack_animation_name()
	if not _animation_player.has_animation(active_attack_animation_name):
		return

	_queued_weapon_ability_recovery_name = &""
	_clear_weapon_ability_state()
	_is_attacking = true
	var playback_speed := maxf(attacks_per_second, 0.01) * attack_speed_scale
	if _fit_active_attack_animation_to_cycle:
		var attack_animation := _animation_player.get_animation(active_attack_animation_name)
		if attack_animation != null:
			# clip_length * attacks_per_second makes the clip occupy exactly one cycle.
			playback_speed = maxf(attack_animation.length, 0.01) * maxf(attacks_per_second, 0.01)
	_active_one_shot_animation_name = active_attack_animation_name
	_animation_player.speed_scale = playback_speed
	_animation_player.play(active_attack_animation_name, blend_time)
	_animation_player.seek(0.0, true)


## Plays an item-provided one-shot and fits it to the gameplay cast duration.
## Returns the effective playback duration, or zero when the clip is unavailable.
func play_weapon_ability(
	animation_scene_path: String,
	animation_name: StringName,
	desired_duration_seconds: float = 0.0,
	recovery_animation_name: StringName = &""
) -> float:
	if _is_dead or not _ensure_animation_player_ready():
		return 0.0
	if not _ensure_one_shot_animation_loaded(animation_name, animation_scene_path):
		return 0.0

	var ability_animation := _animation_player.get_animation(animation_name)
	if ability_animation == null:
		return 0.0
	if (
		not String(recovery_animation_name).is_empty()
		and not _ensure_one_shot_animation_loaded(recovery_animation_name, animation_scene_path)
	):
		return 0.0

	var recovery_animation := (
		_animation_player.get_animation(recovery_animation_name)
		if not String(recovery_animation_name).is_empty()
		else null
	)
	var natural_duration := ability_animation.length
	if recovery_animation != null:
		natural_duration += recovery_animation.length

	var playback_speed := 1.0
	if desired_duration_seconds > 0.0:
		playback_speed = maxf(natural_duration / desired_duration_seconds, 0.01)

	_queued_weapon_ability_recovery_name = recovery_animation_name
	_active_one_shot_animation_name = animation_name
	_is_weapon_ability_active = true
	_weapon_ability_animation_scene_path = animation_scene_path
	_weapon_ability_primary_animation_name = animation_name
	_weapon_ability_recovery_animation_name = recovery_animation_name
	_pending_weapon_ability_resume.clear()
	_is_attacking = true
	_animation_player.speed_scale = playback_speed
	_animation_player.play(animation_name, blend_time)
	_animation_player.seek(0.0, true)
	return natural_duration / playback_speed


## Returns the equipped weapon's normalized contact point, or the fallback.
func get_attack_impact_fraction(fallback: float = 0.32) -> float:
	if has_attack_impact_timing_override():
		return _active_attack_impact_fraction

	return clampf(fallback, 0.0, 0.95)


## Reports whether equipped animation data owns the gameplay contact timing.
func has_attack_impact_timing_override() -> bool:
	return _active_attack_impact_fraction >= 0.0


## Plays the configured one-shot death animation and returns its duration.
func play_death(speed_scale: float = 1.0) -> float:
	_is_dead = true
	_queued_weapon_ability_recovery_name = &""
	_active_one_shot_animation_name = &""
	_clear_weapon_ability_state()
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
	_queued_weapon_ability_recovery_name = &""
	_active_one_shot_animation_name = &""
	_clear_weapon_ability_state()
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
		and _animation_player.current_animation == _current_move_animation_name()
	)


## Reports whether an equipment ability still owns the one-shot animation layer.
func is_playing_weapon_ability() -> bool:
	return _is_weapon_ability_active


## Returns normalized progress through the current animation, from 0.0 to 1.0.
func get_current_animation_progress() -> float:
	if _animation_player == null or _animation_player.current_animation_length <= 0.0:
		return 0.0

	return fposmod(
		_animation_player.current_animation_position / _animation_player.current_animation_length,
		1.0
	)


func _setup_animation_player() -> void:
	if _animation_player != null and is_instance_valid(_animation_player):
		return

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
	_reset_active_equipment_animation_names()
	_refresh_equipped_animation_profile(true)
	if not _resume_weapon_ability_after_rebuild():
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
	if library.has_animation(animation_name):
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

	return _current_move_animation_name() if _is_moving else _current_idle_animation_name()


func _current_state_speed_scale() -> float:
	if _is_gathering and not String(_current_gathering_animation_name()).is_empty():
		return gathering_speed_scale

	return move_speed_scale if _is_moving else 1.0


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == death_animation_name:
		return
	if not _is_attacking or animation_name != _active_one_shot_animation_name:
		return
	# A repeated attack can restart the same clip before Godot dispatches the old
	# completion. The newly playing clip owns the state and must not be cancelled.
	if (
		_animation_player != null
		and _animation_player.is_playing()
		and _animation_player.current_animation == animation_name
	):
		return
	if not String(_queued_weapon_ability_recovery_name).is_empty():
		var recovery_animation_name := _queued_weapon_ability_recovery_name
		_queued_weapon_ability_recovery_name = &""
		if _animation_player.has_animation(recovery_animation_name):
			_active_one_shot_animation_name = recovery_animation_name
			_animation_player.play(recovery_animation_name, blend_time)
			_animation_player.seek(0.0, true)
			return

	_active_one_shot_animation_name = &""
	_clear_weapon_ability_state()
	_is_attacking = false
	_play_current_state(true)


func _ensure_animation_player_ready() -> bool:
	if _animation_player == null or not is_instance_valid(_animation_player):
		_animation_player = null
		_animation_library = null
		_setup_animation_player()
	return _animation_player != null and is_instance_valid(_animation_player)


func _capture_weapon_ability_resume() -> void:
	if not _is_weapon_ability_active:
		_pending_weapon_ability_resume.clear()
		return
	if (
		(_animation_player == null or not is_instance_valid(_animation_player))
		and not _pending_weapon_ability_resume.is_empty()
	):
		return

	var current_animation_name := _active_one_shot_animation_name
	var current_position := 0.0
	var current_speed_scale := 1.0
	if _animation_player != null and is_instance_valid(_animation_player):
		if not String(_animation_player.current_animation).is_empty():
			current_animation_name = _animation_player.current_animation
		current_position = maxf(_animation_player.current_animation_position, 0.0)
		current_speed_scale = maxf(_animation_player.speed_scale, 0.01)

	_pending_weapon_ability_resume = {
		"animation_scene_path": _weapon_ability_animation_scene_path,
		"primary_animation_name": _weapon_ability_primary_animation_name,
		"recovery_animation_name": _weapon_ability_recovery_animation_name,
		"current_animation_name": current_animation_name,
		"current_position": current_position,
		"speed_scale": current_speed_scale,
		"queued_recovery_name": _queued_weapon_ability_recovery_name,
	}


func _resume_weapon_ability_after_rebuild() -> bool:
	if _pending_weapon_ability_resume.is_empty() or _animation_player == null:
		return false

	var resume_state := _pending_weapon_ability_resume.duplicate()
	_pending_weapon_ability_resume.clear()
	var animation_scene_path := String(resume_state.get("animation_scene_path", ""))
	var primary_animation_name := StringName(String(resume_state.get("primary_animation_name", "")))
	var recovery_animation_name := StringName(String(resume_state.get("recovery_animation_name", "")))
	var current_animation_name := StringName(String(resume_state.get("current_animation_name", "")))
	var current_position := maxf(float(resume_state.get("current_position", 0.0)), 0.0)
	if (
		String(current_animation_name).is_empty()
		or not _ensure_one_shot_animation_loaded(current_animation_name, animation_scene_path)
	):
		_clear_weapon_ability_state()
		_is_attacking = false
		return false

	var current_animation := _animation_player.get_animation(current_animation_name)
	if current_animation == null:
		_clear_weapon_ability_state()
		_is_attacking = false
		return false
	if current_position >= current_animation.length - 0.001:
		if current_animation_name == primary_animation_name and not String(recovery_animation_name).is_empty():
			current_animation_name = recovery_animation_name
			current_position = 0.0
			if not _ensure_one_shot_animation_loaded(current_animation_name, animation_scene_path):
				_clear_weapon_ability_state()
				_is_attacking = false
				return false
		else:
			_clear_weapon_ability_state()
			_is_attacking = false
			return false

	_weapon_ability_animation_scene_path = animation_scene_path
	_weapon_ability_primary_animation_name = primary_animation_name
	_weapon_ability_recovery_animation_name = recovery_animation_name
	_queued_weapon_ability_recovery_name = StringName(
		String(resume_state.get("queued_recovery_name", ""))
	)
	if current_animation_name == recovery_animation_name:
		_queued_weapon_ability_recovery_name = &""
	_active_one_shot_animation_name = current_animation_name
	_is_weapon_ability_active = true
	_is_attacking = true
	_animation_player.speed_scale = maxf(float(resume_state.get("speed_scale", 1.0)), 0.01)
	_animation_player.play(current_animation_name, 0.0)
	_animation_player.seek(current_position, true)
	return true


func _clear_weapon_ability_state() -> void:
	_queued_weapon_ability_recovery_name = &""
	_active_one_shot_animation_name = &""
	_is_weapon_ability_active = false
	_weapon_ability_animation_scene_path = ""
	_weapon_ability_primary_animation_name = &""
	_weapon_ability_recovery_animation_name = &""
	_pending_weapon_ability_resume.clear()


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


func _ensure_one_shot_animation_loaded(animation_name: StringName, animation_scene_path: String) -> bool:
	if _animation_player == null or _animation_library == null or String(animation_name).is_empty():
		return false
	if _animation_player.has_animation(animation_name):
		var existing_animation := _animation_player.get_animation(animation_name)
		if existing_animation != null:
			existing_animation.loop_mode = Animation.LOOP_NONE
		return true
	if animation_scene_path.is_empty() or not ResourceLoader.exists(animation_scene_path, "PackedScene"):
		return false

	var source_data := _instantiate_animation_source(animation_scene_path)
	var source_root := source_data.get("root") as Node
	var source_player := source_data.get("player") as AnimationPlayer
	_add_animation_to_library(_animation_library, source_player, animation_name, false)
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


func _bind_inventory() -> void:
	if _inventory != null:
		_refresh_equipped_animation_profile(true)
		return

	var inventory := get_node_or_null(inventory_path) if not inventory_path.is_empty() else null
	if inventory == null and is_inside_tree():
		inventory = get_tree().get_first_node_in_group("player_inventory")
	set_inventory(inventory)


func _connect_inventory() -> void:
	if _inventory == null or not _inventory.has_signal("equipped_slots_changed"):
		return

	var refresh_callable := Callable(self, "_on_equipped_slots_changed")
	if not _inventory.is_connected("equipped_slots_changed", refresh_callable):
		_inventory.connect("equipped_slots_changed", refresh_callable)


func _disconnect_inventory() -> void:
	if _inventory == null or not _inventory.has_signal("equipped_slots_changed"):
		return

	var refresh_callable := Callable(self, "_on_equipped_slots_changed")
	if _inventory.is_connected("equipped_slots_changed", refresh_callable):
		_inventory.disconnect("equipped_slots_changed", refresh_callable)


func _on_equipped_slots_changed() -> void:
	_refresh_equipped_animation_profile()


func _refresh_equipped_animation_profile(force_refresh := false) -> void:
	var profile_path := ""
	if _inventory != null and _inventory.has_method("get_equipped_slot"):
		var equipped_item := _inventory.call("get_equipped_slot", combat_equipment_slot_id) as Dictionary
		if equipped_item != null:
			profile_path = String(equipped_item.get("equipment_animation_profile_path", ""))

	if not force_refresh and profile_path == _active_equipment_animation_profile_path:
		return

	_active_equipment_animation_profile_path = profile_path
	_configure_equipment_animations(_load_equipment_animation_profile(profile_path))


func _configure_equipment_animations(profile: Resource) -> void:
	_reset_active_equipment_animation_names()
	if _animation_library == null:
		return

	if _animation_library.has_animation(EQUIPMENT_MOVE_ANIMATION_NAME):
		_animation_library.remove_animation(EQUIPMENT_MOVE_ANIMATION_NAME)

	if profile == null:
		_restart_current_locomotion_state()
		return

	var source_data := _instantiate_equipment_animation_source(profile)
	var source_root := source_data.get("root") as Node
	var source_player := source_data.get("player") as AnimationPlayer
	if source_player == null:
		if source_root != null:
			source_root.queue_free()
		_restart_current_locomotion_state()
		return

	var idle_override := StringName(String(profile.get("idle_animation_name_override")))
	_add_animation_to_library(_animation_library, source_player, idle_override, true)
	if not String(idle_override).is_empty() and _animation_library.has_animation(idle_override):
		_active_idle_animation_name = idle_override

	var attack_source_root: Node = null
	var attack_source_player := source_player
	var attack_scene_path := String(profile.get("basic_attack_animation_scene_path"))
	if not attack_scene_path.is_empty():
		var attack_source_data := _instantiate_animation_source(attack_scene_path)
		attack_source_root = attack_source_data.get("root") as Node
		attack_source_player = attack_source_data.get("player") as AnimationPlayer

	var attack_override := StringName(String(profile.get("basic_attack_animation_name")))
	_add_animation_to_library(_animation_library, attack_source_player, attack_override, false)
	if not String(attack_override).is_empty() and _animation_library.has_animation(attack_override):
		_active_attack_animation_name = attack_override
		_active_attack_impact_fraction = clampf(
			float(profile.get("basic_attack_impact_fraction")),
			-1.0,
			0.95
		)
		_fit_active_attack_animation_to_cycle = bool(profile.get("fit_basic_attack_animation_to_cycle"))

	var move_override := StringName(String(profile.get("move_animation_name_override")))
	_add_animation_to_library(_animation_library, source_player, move_override, true)
	if not String(move_override).is_empty() and _animation_library.has_animation(move_override):
		_active_move_animation_name = move_override
	else:
		_build_equipment_move_pose_animation(profile, source_player)

	if source_root != null:
		source_root.queue_free()
	if attack_source_root != null:
		attack_source_root.queue_free()
	_restart_current_locomotion_state()


func _instantiate_equipment_animation_source(profile: Resource) -> Dictionary:
	return _instantiate_animation_source(String(profile.get("combat_animation_scene_path")))


func _instantiate_animation_source(scene_path: String) -> Dictionary:
	var animation_scene := source_animation_scene
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path, "PackedScene"):
		animation_scene = load(scene_path) as PackedScene
	if animation_scene == null:
		return {}

	var source_root := animation_scene.instantiate()
	return {
		"root": source_root,
		"player": _find_animation_player(source_root),
	}


func _build_equipment_move_pose_animation(profile: Resource, source_player: AnimationPlayer) -> void:
	var pose_animation_name := StringName(String(profile.get("move_pose_animation_name")))
	var pose_bone_names := PackedStringArray(profile.get("move_pose_bone_names"))
	var pose_blend := clampf(float(profile.get("move_pose_blend")), 0.0, 1.0)
	if String(pose_animation_name).is_empty() or pose_bone_names.is_empty() or pose_blend <= 0.0:
		return
	if not source_player.has_animation(pose_animation_name):
		return
	if not _animation_library.has_animation(move_animation_name):
		return

	var move_animation := _animation_library.get_animation(move_animation_name)
	var pose_animation := source_player.get_animation(pose_animation_name)
	if move_animation == null or pose_animation == null:
		return

	var equipment_move_animation := move_animation.duplicate(true) as Animation
	for bone_name in pose_bone_names:
		_blend_bone_toward_pose(equipment_move_animation, pose_animation, String(bone_name), pose_blend)

	equipment_move_animation.loop_mode = Animation.LOOP_LINEAR
	_animation_library.add_animation(EQUIPMENT_MOVE_ANIMATION_NAME, equipment_move_animation)
	_active_move_animation_name = EQUIPMENT_MOVE_ANIMATION_NAME


func _blend_bone_toward_pose(
	move_animation: Animation,
	pose_animation: Animation,
	bone_name: String,
	pose_blend: float
) -> void:
	var track_path := NodePath("Armature/Skeleton3D:%s" % bone_name)
	var move_track_index := move_animation.find_track(track_path, Animation.TYPE_ROTATION_3D)
	var pose_track_index := pose_animation.find_track(track_path, Animation.TYPE_ROTATION_3D)
	if move_track_index < 0 or pose_track_index < 0 or pose_animation.track_get_key_count(pose_track_index) <= 0:
		return

	var pose_rotation: Quaternion = pose_animation.track_get_key_value(pose_track_index, 0)
	for key_index in move_animation.track_get_key_count(move_track_index):
		var move_rotation: Quaternion = move_animation.track_get_key_value(move_track_index, key_index)
		move_animation.track_set_key_value(
			move_track_index,
			key_index,
			move_rotation.slerp(pose_rotation, pose_blend)
		)


func _reset_active_equipment_animation_names() -> void:
	_active_idle_animation_name = idle_animation_name
	_active_move_animation_name = move_animation_name
	_active_attack_animation_name = attack_animation_name
	_active_attack_impact_fraction = -1.0
	_fit_active_attack_animation_to_cycle = false


func _restart_current_locomotion_state() -> void:
	if _animation_player != null and not _is_attacking and not _is_dead:
		_play_current_state(true)


func _current_idle_animation_name() -> StringName:
	return _active_idle_animation_name if not String(_active_idle_animation_name).is_empty() else idle_animation_name


func _current_move_animation_name() -> StringName:
	return _active_move_animation_name if not String(_active_move_animation_name).is_empty() else move_animation_name


func _current_attack_animation_name() -> StringName:
	return _active_attack_animation_name if not String(_active_attack_animation_name).is_empty() else attack_animation_name


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var animation_player := _find_animation_player(child)
		if animation_player != null:
			return animation_player

	return null
