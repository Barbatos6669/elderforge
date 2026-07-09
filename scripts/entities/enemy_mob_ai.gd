## First-pass hostile mob brain.
##
## This module owns aggro, chase, melee attack timing, and leash behavior for a
## single CharacterBody3D mob. Health, selection, visuals, and animation remain
## separate child components so future enemy types can swap pieces independently.
class_name EnemyMobAI
extends Node

signal aggro_started(target: Node)
signal aggro_dropped
signal attack_landed(target: Node, damage: float)
signal respawned

## Group used to find player characters that can draw aggro.
@export var target_group := "player"
## Health component on this mob.
@export var health_path: NodePath = NodePath("../Health")
## Animation controller used for idle, move, and attack playback.
@export var animation_path: NodePath = NodePath("../Animation")
## Selectable component disabled when the mob is defeated.
@export var selectable_path: NodePath = NodePath("../Selectable")
## Visual root rotated toward movement and attack direction.
@export var visuals_path: NodePath = NodePath("../Visuals")
## Optional component that spawns a loot bag when this mob dies.
@export var loot_dropper_path: NodePath = NodePath("../LootDropper")

@export_group("Aggro")
## Distance from the mob where players first pull aggro.
@export_range(0.5, 30.0, 0.1) var aggro_radius := 6.0
## Maximum distance from the home point before the mob drops aggro and returns.
@export_range(1.0, 60.0, 0.1) var leash_radius := 12.0
## Distance from home where the mob stops returning and idles.
@export_range(0.05, 2.0, 0.01) var home_arrival_distance := 0.18

@export_group("Movement")
@export_range(0.1, 12.0, 0.1) var movement_speed := 2.6
@export_range(0.1, 80.0, 0.1) var acceleration := 10.0
@export_range(0.1, 80.0, 0.1) var deceleration := 16.0
## Distance where the mob starts easing into its destination instead of snapping.
@export_range(0.05, 5.0, 0.05) var slowdown_distance := 0.8
## Radians per second used when turning the visual model toward movement/target.
@export_range(0.1, 40.0, 0.1) var turn_speed := 10.0
## Distance the mob tries to stand from its target.
@export_range(0.1, 5.0, 0.05) var approach_distance := 1.25

@export_group("Combat")
@export_range(0.1, 5.0, 0.05) var attack_range := 1.6
@export_range(0.0, 500.0, 1.0) var attack_damage := 8.0
## Attacks per second. This also drives attack animation speed.
@export_range(0.1, 5.0, 0.05) var attack_speed := 0.75

@export_group("Death")
## Minimum time the defeated body stays visible before hiding for respawn.
@export_range(0.0, 5.0, 0.05) var minimum_death_visible_time := 1.2

@export_group("Respawn")
## Seconds after defeat before this mob reappears at its home position.
@export_range(0.0, 300.0, 0.1) var respawn_delay := 30.0
## Hides the full mob tree while waiting to respawn.
@export var hide_while_defeated := true

var _body: CharacterBody3D
var _health: Node
var _animation: Node
var _selectable: Node
var _visuals: Node3D
var _loot_dropper: Node
var _target: Node3D
var _collision_shapes: Array[CollisionShape3D] = []
var _home_position := Vector3.ZERO
var _cooldown_remaining := 0.0
var _original_collision_layer := 0
var _original_collision_mask := 0
var _is_respawning := false
var _suppress_next_loot_drop := false


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_warning("EnemyMobAI must be a child of a CharacterBody3D.")
		return

	_body.add_to_group("network_mobs")
	_home_position = _body.global_position
	_original_collision_layer = _body.collision_layer
	_original_collision_mask = _body.collision_mask
	_health = get_node_or_null(health_path)
	_animation = get_node_or_null(animation_path)
	_selectable = get_node_or_null(selectable_path)
	_visuals = get_node_or_null(visuals_path) as Node3D
	_loot_dropper = get_node_or_null(loot_dropper_path)
	_collect_collision_shapes(_body)

	if _health != null and _health.has_signal("defeated"):
		_health.defeated.connect(_on_defeated)


func _physics_process(delta: float) -> void:
	if _body == null or _is_respawning or _is_self_defeated():
		return

	if _has_target():
		_update_aggro(delta)
		return

	_target = _find_aggro_target()
	if _target != null:
		_cooldown_remaining = 0.0
		aggro_started.emit(_target)
		_update_aggro(delta)
		return

	_return_home_or_idle(delta)


func _update_aggro(delta: float) -> void:
	if not _has_target() or _is_target_defeated(_target):
		_drop_aggro()
		_return_home_or_idle(delta)
		return

	if _distance_from_home() > leash_radius:
		_drop_aggro()
		_return_home_or_idle(delta)
		return

	var distance_to_target := _horizontal_distance_to(_target.global_position)
	if distance_to_target <= attack_range:
		_stop_moving(delta)
		_face_direction(_direction_to(_target.global_position), delta)
		_update_attack(delta)
		return

	var chase_destination := _target.global_position - _direction_to(_target.global_position) * approach_distance
	chase_destination.y = _body.global_position.y
	_move_toward(chase_destination, delta)


func _update_attack(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining > 0.0:
		return

	var target_health := _find_health(_target)
	if target_health == null or not target_health.has_method("apply_damage"):
		_drop_aggro()
		return

	var applied_damage := float(target_health.call("apply_damage", attack_damage))
	if applied_damage <= 0.0:
		_drop_aggro()
		return

	if _animation != null and _animation.has_method("play_attack"):
		_animation.call("play_attack", attack_speed)

	_cooldown_remaining = _attack_interval()
	attack_landed.emit(_target, applied_damage)


func _return_home_or_idle(delta: float) -> void:
	if _horizontal_distance_to(_home_position) > home_arrival_distance:
		_move_toward(_home_position, delta)
		return

	_stop_moving(delta)
	_body.global_position.y = _home_position.y


func _move_toward(destination: Vector3, delta: float) -> void:
	var direction := _direction_to(destination)
	if direction == Vector3.ZERO:
		_stop_moving(delta)
		return

	var distance := _horizontal_distance_to(destination)
	var speed_ratio := clampf(distance / maxf(slowdown_distance, 0.01), 0.0, 1.0)
	var target_velocity := direction * movement_speed * speed_ratio
	var horizontal_velocity := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, acceleration * delta)
	_body.velocity.x = horizontal_velocity.x
	_body.velocity.y = 0.0
	_body.velocity.z = horizontal_velocity.z
	_body.move_and_slide()

	_face_direction(direction, delta)
	var is_still_moving := Vector2(_body.velocity.x, _body.velocity.z).length_squared() > 0.0025
	_set_moving_animation(is_still_moving)


func _stop_moving(delta: float) -> void:
	var horizontal_velocity := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, deceleration * delta)
	_body.velocity.x = horizontal_velocity.x
	_body.velocity.y = 0.0
	_body.velocity.z = horizontal_velocity.z
	_body.move_and_slide()

	var is_still_moving := Vector2(_body.velocity.x, _body.velocity.z).length_squared() > 0.0025
	_set_moving_animation(is_still_moving)


func _find_aggro_target() -> Node3D:
	if not is_inside_tree():
		return null

	var closest_target: Node3D = null
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group(target_group):
		var candidate_3d := candidate as Node3D
		if candidate_3d == null or _is_target_defeated(candidate_3d):
			continue

		var distance := _horizontal_distance_to(candidate_3d.global_position)
		if distance <= aggro_radius and distance < closest_distance:
			closest_target = candidate_3d
			closest_distance = distance

	return closest_target


func _drop_aggro() -> void:
	if _target == null:
		return

	_target = null
	_cooldown_remaining = 0.0
	aggro_dropped.emit()


func _on_defeated() -> void:
	if _is_respawning:
		return

	_drop_aggro()
	if _body != null:
		_body.velocity = Vector3.ZERO
	if _animation != null and _animation.has_method("set_moving"):
		_animation.call("set_moving", false)
	_begin_respawn()


func _begin_respawn() -> void:
	_is_respawning = true
	_set_defeated_state(true, false)
	_drop_loot()

	var death_duration := _play_death_animation()
	var visible_duration := maxf(death_duration, minimum_death_visible_time)
	if visible_duration > 0.0:
		await get_tree().create_timer(visible_duration).timeout
		if not is_inside_tree():
			return

	if hide_while_defeated and _body != null:
		_body.visible = false

	var remaining_respawn_delay := maxf(respawn_delay - visible_duration, 0.0)
	if remaining_respawn_delay <= 0.0:
		_respawn()
		return

	await get_tree().create_timer(remaining_respawn_delay).timeout
	if not is_inside_tree():
		return

	_respawn()


func _respawn() -> void:
	if not _is_respawning:
		return

	_drop_aggro()
	if _body != null:
		_body.global_position = _home_position
		_body.velocity = Vector3.ZERO
	if _health != null and _health.has_method("reset_to_full"):
		_health.call("reset_to_full")

	_set_defeated_state(false)
	if _animation != null and _animation.has_method("reset_animation_state"):
		_animation.call("reset_animation_state")

	_cooldown_remaining = 0.0
	_is_respawning = false
	respawned.emit()


## Restores visible/collidable state when the server replicates a mob respawn.
func apply_network_alive_state() -> void:
	if _body == null:
		return
	if not _is_respawning and _body.visible:
		return

	_drop_aggro()
	_is_respawning = false
	_body.global_position = _home_position
	_body.velocity = Vector3.ZERO
	_set_defeated_state(false)
	if _animation != null and _animation.has_method("reset_animation_state"):
		_animation.call("reset_animation_state")
	_cooldown_remaining = 0.0
	respawned.emit()


## Prevents replicated death visuals from spawning local-only loot copies.
func suppress_next_network_loot_drop() -> void:
	_suppress_next_loot_drop = true


func _set_defeated_state(is_defeated: bool, should_hide_body: bool = true) -> void:
	if _body != null:
		_body.collision_layer = 0 if is_defeated else _original_collision_layer
		_body.collision_mask = 0 if is_defeated else _original_collision_mask
		if hide_while_defeated and should_hide_body:
			_body.visible = not is_defeated

	_set_collision_shapes_disabled(is_defeated)
	if _selectable != null:
		_selectable.set("selection_enabled", not is_defeated)
		if is_defeated and _selectable.has_method("set_selected"):
			_selectable.call("set_selected", false)


func _play_death_animation() -> float:
	if _animation == null or not _animation.has_method("play_death"):
		return 0.0

	return maxf(float(_animation.call("play_death")), 0.0)


func _drop_loot() -> void:
	if _suppress_next_loot_drop:
		_suppress_next_loot_drop = false
		return
	if _loot_dropper == null or not _loot_dropper.has_method("drop_loot"):
		return

	var drop_position := Vector3.ZERO
	if _body != null:
		drop_position = _body.global_position
	else:
		var parent_3d := get_parent() as Node3D
		if parent_3d != null:
			drop_position = parent_3d.global_position
	_loot_dropper.call("drop_loot", drop_position)


func _collect_collision_shapes(node: Node) -> void:
	if node is CollisionShape3D:
		_collision_shapes.append(node as CollisionShape3D)

	for child in node.get_children():
		_collect_collision_shapes(child)


func _set_collision_shapes_disabled(is_disabled: bool) -> void:
	for collision_shape in _collision_shapes:
		if is_instance_valid(collision_shape):
			collision_shape.set_deferred("disabled", is_disabled)


func _has_target() -> bool:
	return _target != null and is_instance_valid(_target)


func _is_self_defeated() -> bool:
	return _health != null and _health.has_method("is_defeated") and _health.call("is_defeated") == true


func _is_target_defeated(target: Node) -> bool:
	var target_health := _find_health(target)
	return (
		target_health != null
		and target_health.has_method("is_defeated")
		and target_health.call("is_defeated") == true
	)


func _find_health(target: Node) -> Node:
	if target == null:
		return null
	if target.has_method("apply_damage"):
		return target

	return target.get_node_or_null("Health")


func _direction_to(destination: Vector3) -> Vector3:
	var direction := destination - _body.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return Vector3.ZERO

	return direction.normalized()


func _horizontal_distance_to(destination: Vector3) -> float:
	var offset := destination - _body.global_position
	offset.y = 0.0
	return offset.length()


func _distance_from_home() -> float:
	return _horizontal_distance_to(_home_position)


func _attack_interval() -> float:
	return 1.0 / maxf(attack_speed, 0.01)


func _face_direction(direction: Vector3, delta: float = -1.0) -> void:
	if direction == Vector3.ZERO or _visuals == null:
		return

	var target_yaw := atan2(-direction.x, -direction.z)
	if delta <= 0.0:
		_visuals.rotation.y = target_yaw
		return

	var turn_weight := clampf(turn_speed * delta, 0.0, 1.0)
	_visuals.rotation.y = lerp_angle(_visuals.rotation.y, target_yaw, turn_weight)


func _set_moving_animation(is_moving: bool) -> void:
	if _animation != null and _animation.has_method("set_moving"):
		_animation.call("set_moving", is_moving)
