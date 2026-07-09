## Killable animal behavior with a skinnable corpse state.
##
## The parent must be a CharacterBody3D with Health, Selectable, Visuals, and an
## Animation child. While alive the animal can wander and be attacked. Once its
## health reaches zero it becomes a gatherable hide resource until skinned.
class_name SkinnableAnimal3D
extends Node

signal gather_tick_consumed(remaining_ticks: int, max_ticks: int)
signal gather_tick_replenished(remaining_ticks: int, max_ticks: int)
signal depleted
signal fully_replenished
signal respawned

@export_group("Components")
## Health component on the parent animal.
@export var health_path: NodePath = NodePath("../Health")
## Selectable area that player targeting clicks.
@export var selectable_path: NodePath = NodePath("../Selectable")
## Animation bridge for idle, walk, and death playback.
@export var animation_path: NodePath = NodePath("../Animation")
## Visual root rotated toward movement direction.
@export var visuals_path: NodePath = NodePath("../Visuals")

@export_group("Identity")
## Display name used by selection and channel text.
@export var display_name := "Skinnable Animal"
## Relationship while alive. Hostile lets the current auto-attack flow target it.
@export var alive_relationship := Selectable3D.Relationship.HOSTILE
## Relationship while dead. Neutral makes the corpse a resource instead of an enemy.
@export var corpse_relationship := Selectable3D.Relationship.NEUTRAL

@export_group("Skinning")
## Resource family id matching inventory definitions.
@export var resource_family_id := "hide"
## Item definition id granted per skinning tick.
@export var yield_item_id := "hide_t1"
## Tier from I to VIII.
@export_range(1, 8, 1) var tier := 1
## Quantity granted per completed skinning channel.
@export_range(1, 999, 1) var yield_quantity := 1
## Number of skinning ticks available on the corpse.
@export_range(1, 20, 1) var max_skin_ticks := 1
## Seconds before tool multipliers are applied.
@export_range(0.1, 60.0, 0.1) var skin_duration := 2.0

@export_group("Wander")
## Lets the animal roam while alive so walk animation can be seen.
@export var wander_enabled := true
## Maximum distance from spawn while picking idle wander points.
@export_range(0.0, 20.0, 0.1) var wander_radius := 4.0
## Seconds between wander decisions.
@export var idle_wait_range := Vector2(1.4, 3.6)
## Movement speed used while wandering.
@export_range(0.1, 8.0, 0.1) var movement_speed := 1.15
## Radians per second used to turn visual root toward motion.
@export_range(0.1, 40.0, 0.1) var turn_speed := 8.0
## Distance considered close enough to a wander destination.
@export_range(0.05, 1.0, 0.01) var destination_arrival_distance := 0.16

@export_group("Respawn")
## Seconds after skinning before the animal returns.
@export_range(0.0, 300.0, 0.1) var respawn_delay := 30.0
## Seconds before an unskinned corpse disappears and respawns.
@export_range(0.0, 300.0, 0.1) var unskinned_corpse_lifetime := 60.0

var _body: CharacterBody3D
var _health: Node
var _selectable: Node
var _animation: Node
var _visuals: Node3D
var _collision_shapes: Array[CollisionShape3D] = []
var _home_position := Vector3.ZERO
var _wander_destination := Vector3.ZERO
var _wait_remaining := 0.0
var _remaining_skin_ticks := 1
var _is_dead := false
var _is_hidden_for_respawn := false
var _corpse_timer_version := 0
var _network_control_timeout := 0.0
var _original_collision_layer := 0
var _original_collision_mask := 0


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_warning("SkinnableAnimal3D must be a child of a CharacterBody3D.")
		return

	_body.add_to_group("network_mobs")
	add_to_group("gatherable_resources")
	_home_position = _body.global_position
	_wander_destination = _home_position
	_original_collision_layer = _body.collision_layer
	_original_collision_mask = _body.collision_mask
	_health = get_node_or_null(health_path)
	_selectable = get_node_or_null(selectable_path)
	_animation = get_node_or_null(animation_path)
	_visuals = get_node_or_null(visuals_path) as Node3D
	_collect_collision_shapes(_body)
	_remaining_skin_ticks = max_skin_ticks
	_wait_remaining = _random_wait_time()

	if _health != null and _health.has_signal("defeated"):
		_health.defeated.connect(_on_defeated)

	_apply_alive_state()


func _physics_process(delta: float) -> void:
	if _body == null or _is_dead or _is_hidden_for_respawn:
		return

	if _network_control_timeout > 0.0:
		_network_control_timeout = maxf(_network_control_timeout - delta, 0.0)
		return

	_update_wander(delta)


## Returns the roman numeral used by tier labels and item UI.
func get_tier_roman() -> String:
	var roman_values := {
		1: "I",
		2: "II",
		3: "III",
		4: "IV",
		5: "V",
		6: "VI",
		7: "VII",
		8: "VIII",
	}
	return String(roman_values.get(tier, str(tier)))


## Returns the shared prototype tier color.
func get_tier_color() -> Color:
	match tier:
		1:
			return Color(0.72, 0.72, 0.72, 1.0)
		2:
			return Color(0.72, 0.50, 0.30, 1.0)
		3:
			return Color(0.20, 0.62, 0.25, 1.0)
		4:
			return Color(0.20, 0.42, 0.82, 1.0)
		5:
			return Color(0.78, 0.18, 0.16, 1.0)
		6:
			return Color(0.92, 0.48, 0.14, 1.0)
		7:
			return Color(0.95, 0.82, 0.18, 1.0)
		8:
			return Color(0.94, 0.94, 0.9, 1.0)
		_:
			return Color(0.72, 0.72, 0.72, 1.0)


## Resource interface consumed by PlayerGathering.
func get_yield_data() -> Dictionary:
	return {
		"item_id": yield_item_id,
		"family_id": resource_family_id,
		"tier": tier,
		"tier_roman": get_tier_roman(),
		"quantity": yield_quantity,
		"gather_duration": skin_duration,
		"remaining_ticks": _remaining_skin_ticks,
		"max_ticks": max_skin_ticks,
		"replenish_interval_seconds": 0.0,
	}


## Skinning is only available after death and before the corpse is consumed.
func can_gather() -> bool:
	return _is_dead and not _is_hidden_for_respawn and _remaining_skin_ticks > 0


## Consumes one skinning tick and hides the corpse once all hide is taken.
func consume_gather_tick() -> bool:
	if not can_gather():
		return false

	_remaining_skin_ticks = maxi(_remaining_skin_ticks - 1, 0)
	gather_tick_consumed.emit(_remaining_skin_ticks, max_skin_ticks)
	if _remaining_skin_ticks <= 0:
		depleted.emit()
		_hide_until_respawn()

	return true


## Applies replicated skinning state without needing the player channel locally.
func set_remaining_ticks(remaining_ticks: int) -> void:
	var previous_ticks := _remaining_skin_ticks
	_remaining_skin_ticks = clampi(remaining_ticks, 0, max_skin_ticks)

	if _remaining_skin_ticks < previous_ticks:
		gather_tick_consumed.emit(_remaining_skin_ticks, max_skin_ticks)
	elif _remaining_skin_ticks > previous_ticks:
		gather_tick_replenished.emit(_remaining_skin_ticks, max_skin_ticks)

	if _is_dead and _remaining_skin_ticks <= 0:
		depleted.emit()
		_hide_until_respawn()
	elif _remaining_skin_ticks >= max_skin_ticks:
		fully_replenished.emit()


func get_remaining_ticks() -> int:
	return _remaining_skin_ticks


func get_max_ticks() -> int:
	return max_skin_ticks


func is_depleted() -> bool:
	return _remaining_skin_ticks <= 0


func reset_resource() -> void:
	_remaining_skin_ticks = max_skin_ticks
	fully_replenished.emit()


## Multiplayer motion/state bridge used by MultiplayerTestManager.
func get_network_state() -> Dictionary:
	var visual_yaw := _visuals.global_rotation.y if _visuals != null else 0.0
	var is_moving := (
		_body != null
		and Vector2(_body.velocity.x, _body.velocity.z).length_squared() > 0.0025
	)
	return {
		"position": _body.global_position if _body != null else Vector3.ZERO,
		"visual_yaw": visual_yaw,
		"is_moving": is_moving,
	}


func has_network_activity() -> bool:
	return (
		_body != null
		and not _is_dead
		and not _is_hidden_for_respawn
		and Vector2(_body.velocity.x, _body.velocity.z).length_squared() > 0.0025
	)


func apply_network_motion_state(position: Vector3, visual_yaw: float, is_moving: bool) -> void:
	if _body == null or _is_dead or _is_hidden_for_respawn:
		return

	_network_control_timeout = 0.35
	_body.global_position = position
	_body.velocity = Vector3.ZERO
	if _visuals != null:
		_visuals.global_rotation.y = visual_yaw
	_set_moving_animation(is_moving)


func apply_network_alive_state() -> void:
	if _body == null:
		return

	_respawn_now(false)


func suppress_next_network_loot_drop() -> void:
	pass


func play_network_attack(_speed_scale: float = 1.0) -> void:
	pass


func _update_wander(delta: float) -> void:
	if not wander_enabled or wander_radius <= 0.0:
		_stop_moving()
		return

	var distance_to_destination := _horizontal_distance_to(_wander_destination)
	if distance_to_destination <= destination_arrival_distance:
		_stop_moving()
		_wait_remaining = maxf(_wait_remaining - delta, 0.0)
		if _wait_remaining <= 0.0:
			_wander_destination = _random_wander_destination()
			_wait_remaining = _random_wait_time()
		return

	var direction := _direction_to(_wander_destination)
	_body.velocity.x = direction.x * movement_speed
	_body.velocity.y = 0.0
	_body.velocity.z = direction.z * movement_speed
	_body.move_and_slide()
	_face_direction(direction, delta)
	_set_moving_animation(true)


func _stop_moving() -> void:
	if _body != null:
		_body.velocity = Vector3.ZERO
	_set_moving_animation(false)


func _on_defeated() -> void:
	if _is_dead:
		return

	_is_dead = true
	_is_hidden_for_respawn = false
	_corpse_timer_version += 1
	_remaining_skin_ticks = max_skin_ticks
	_stop_moving()
	_set_collision_shapes_disabled(true)
	_set_selectable_state(true, corpse_relationship)
	if _animation != null and _animation.has_method("play_death"):
		_animation.call("play_death")

	if unskinned_corpse_lifetime > 0.0:
		_start_unskinned_corpse_timer(_corpse_timer_version)


func _start_unskinned_corpse_timer(timer_version: int) -> void:
	await get_tree().create_timer(unskinned_corpse_lifetime).timeout
	if not is_inside_tree():
		return
	if timer_version != _corpse_timer_version:
		return
	if _is_dead and not _is_hidden_for_respawn and _remaining_skin_ticks > 0:
		_hide_until_respawn()


func _hide_until_respawn() -> void:
	if _is_hidden_for_respawn:
		return

	_is_hidden_for_respawn = true
	_corpse_timer_version += 1
	_set_selectable_state(false, corpse_relationship)
	_set_visible(false)
	if respawn_delay <= 0.0:
		_respawn_now()
		return

	_respawn_after_delay(_corpse_timer_version)


func _respawn_after_delay(timer_version: int) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	if timer_version != _corpse_timer_version:
		return

	_respawn_now()


func _respawn_now(reset_health: bool = true) -> void:
	_is_dead = false
	_is_hidden_for_respawn = false
	_corpse_timer_version += 1
	_remaining_skin_ticks = max_skin_ticks
	if _body != null:
		_body.global_position = _home_position
		_body.velocity = Vector3.ZERO
		_body.collision_layer = _original_collision_layer
		_body.collision_mask = _original_collision_mask
	_set_visible(true)
	_set_collision_shapes_disabled(false)
	if reset_health and _health != null and _health.has_method("reset_to_full"):
		_health.call("reset_to_full")
	if _animation != null and _animation.has_method("reset_animation_state"):
		_animation.call("reset_animation_state")
	_apply_alive_state()
	fully_replenished.emit()
	respawned.emit()


func _apply_alive_state() -> void:
	_set_selectable_state(true, alive_relationship)
	if _selectable != null:
		_selectable.set("display_name", display_name)


func _set_selectable_state(selection_enabled: bool, relationship: int) -> void:
	if _selectable == null:
		return

	_selectable.set("selection_enabled", selection_enabled)
	_selectable.set("relationship", relationship)
	if not selection_enabled and _selectable.has_method("set_selected"):
		_selectable.call("set_selected", false)


func _set_visible(is_visible: bool) -> void:
	if _body != null:
		_body.visible = is_visible


func _collect_collision_shapes(node: Node) -> void:
	if node == _selectable:
		return

	if node is CollisionShape3D:
		_collision_shapes.append(node as CollisionShape3D)

	for child in node.get_children():
		_collect_collision_shapes(child)


func _set_collision_shapes_disabled(is_disabled: bool) -> void:
	for collision_shape in _collision_shapes:
		if is_instance_valid(collision_shape):
			collision_shape.set_deferred("disabled", is_disabled)


func _set_moving_animation(is_moving: bool) -> void:
	if _animation != null and _animation.has_method("set_moving"):
		_animation.call("set_moving", is_moving)


func _random_wander_destination() -> Vector3:
	var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if offset.length_squared() <= 0.001:
		offset = Vector2.RIGHT

	offset = offset.normalized() * randf_range(0.4, wander_radius)
	return _home_position + Vector3(offset.x, 0.0, offset.y)


func _random_wait_time() -> float:
	var min_wait := minf(idle_wait_range.x, idle_wait_range.y)
	var max_wait := maxf(idle_wait_range.x, idle_wait_range.y)
	return randf_range(maxf(min_wait, 0.0), maxf(max_wait, 0.0))


func _direction_to(destination: Vector3) -> Vector3:
	if _body == null:
		return Vector3.ZERO

	var direction := destination - _body.global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


func _horizontal_distance_to(destination: Vector3) -> float:
	if _body == null:
		return 0.0

	var offset := destination - _body.global_position
	offset.y = 0.0
	return offset.length()


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction == Vector3.ZERO or _visuals == null:
		return

	var target_yaw := atan2(-direction.x, -direction.z)
	var turn_weight := clampf(turn_speed * delta, 0.0, 1.0)
	_visuals.rotation.y = lerp_angle(_visuals.rotation.y, target_yaw, turn_weight)
