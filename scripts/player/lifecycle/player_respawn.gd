## Player death and respawn coordinator.
##
## The health component decides when HP reaches zero. This module reacts to that
## defeat signal, locks the player briefly, plays the death animation, restores
## health/resources, and moves the player back to a spawn transform.
class_name PlayerRespawn
extends Node

signal death_started(respawn_delay: float)
signal respawn_started
signal respawned

## Health component that emits `defeated`.
@export var health_path: NodePath = NodePath("../Health")
## Optional mana/energy pool restored on respawn.
@export var resource_path: NodePath = NodePath("../Mana")
## Player animation bridge used for death and idle reset.
@export var animation_path: NodePath = NodePath("../Animation")
## Optional combat state forced out of combat on death/respawn.
@export var combat_state_path: NodePath = NodePath("../CombatState")
## Optional Marker3D. Empty means "use the player's starting transform."
@export var spawn_marker_path: NodePath
## Remote network copies disable this so replicated zero-health state does not
## start a local respawn timer on every client.
@export var enabled := true

@export_group("Timing")
## Total seconds between death and respawn. The death animation is included.
@export_range(0.0, 120.0, 0.1) var respawn_delay := 5.0
## Minimum time the defeated body remains visible, even if the animation is short.
@export_range(0.0, 10.0, 0.05) var minimum_death_visible_time := 1.0

@export_group("Restore")
## Respawn at full health for now. Later this can become partial HP or durability loss.
@export var restore_health_to_full := true
## Respawn at full mana/energy for now.
@export var restore_resource_to_full := true
## Prevents extra damage from landing while the player is already defeated.
@export var lock_damage_while_defeated := true

var _body: CharacterBody3D
var _health: CombatHealth
var _resource_pool: ResourcePool
var _animation: PlayerAnimationController
var _combat_state: CombatState
var _spawn_transform := Transform3D.IDENTITY
var _has_spawn_transform := false
var _is_respawning := false
var _previous_can_take_damage := true


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_warning("PlayerRespawn must be a child of a CharacterBody3D.")
		return

	_health = get_node_or_null(health_path) as CombatHealth
	_resource_pool = get_node_or_null(resource_path) as ResourcePool
	_animation = get_node_or_null(animation_path) as PlayerAnimationController
	_combat_state = get_node_or_null(combat_state_path) as CombatState
	_cache_spawn_transform()

	if _health == null:
		push_warning("PlayerRespawn could not find CombatHealth at %s." % health_path)
		return

	_health.defeated.connect(_on_health_defeated)


## Overrides the respawn transform at runtime.
##
## Use this later for bind points, checkpoints, dungeon entrances, or city
## respawn statues. It stores a full transform so facing direction can come along.
func set_spawn_transform(spawn_transform: Transform3D) -> void:
	_spawn_transform = spawn_transform
	_has_spawn_transform = true


func is_respawning() -> bool:
	return _is_respawning


func _on_health_defeated() -> void:
	if not enabled:
		return
	if _is_respawning:
		return

	_begin_respawn()


func _begin_respawn() -> void:
	_is_respawning = true
	_previous_can_take_damage = _health.can_take_damage
	if lock_damage_while_defeated:
		_health.can_take_damage = false

	_stop_body()
	_force_out_of_combat()
	death_started.emit(respawn_delay)

	var death_duration := _play_death_animation()
	var visible_duration := maxf(death_duration, minimum_death_visible_time)
	if visible_duration > 0.0:
		await get_tree().create_timer(visible_duration).timeout
		if not is_inside_tree():
			return

	var remaining_delay := maxf(respawn_delay - visible_duration, 0.0)
	if remaining_delay > 0.0:
		await get_tree().create_timer(remaining_delay).timeout
		if not is_inside_tree():
			return

	_respawn()


func _respawn() -> void:
	respawn_started.emit()
	_stop_body()
	_move_to_spawn()
	_restore_pools()
	_force_out_of_combat()
	if _animation != null:
		_animation.reset_animation_state()

	if _health != null:
		_health.can_take_damage = _previous_can_take_damage

	_is_respawning = false
	respawned.emit()


func _cache_spawn_transform() -> void:
	var marker := _get_spawn_marker()
	if marker != null:
		set_spawn_transform(marker.global_transform)
		return

	if _body != null:
		set_spawn_transform(_body.global_transform)


func _get_spawn_marker() -> Node3D:
	if String(spawn_marker_path).is_empty():
		return null

	return get_node_or_null(spawn_marker_path) as Node3D


func _move_to_spawn() -> void:
	if _body == null:
		return

	var marker := _get_spawn_marker()
	var spawn_transform := marker.global_transform if marker != null else _spawn_transform
	if not _has_spawn_transform:
		spawn_transform = _body.global_transform

	_body.global_transform = spawn_transform


func _restore_pools() -> void:
	if _health != null and restore_health_to_full:
		_health.reset_to_full()

	if _resource_pool != null and restore_resource_to_full:
		_resource_pool.set_current_resource(_resource_pool.max_resource)


func _play_death_animation() -> float:
	if _animation == null:
		return 0.0

	return maxf(_animation.play_death(), 0.0)


func _force_out_of_combat() -> void:
	if _combat_state != null:
		_combat_state.force_out_of_combat()


func _stop_body() -> void:
	if _body != null:
		_body.velocity = Vector3.ZERO
