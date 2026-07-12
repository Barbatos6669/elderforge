## Tiny local wander behavior for service NPC stations.
##
## This is intentionally simpler than enemy or animal movement. Refiners and
## crafters do not need navigation yet; they only need to drift around their
## work spot so the town feels alive while keeping the station interaction API.
class_name ServiceNpcAmbientWander3D
extends Node

@export_group("Moved Parts")
## Parent visual root rotated toward the short wander path.
@export var visuals_path: NodePath = NodePath("../Visuals")
## StaticBody3D used as the service NPC's physical blocker.
@export var body_path: NodePath = NodePath("../Body")
## Selectable Area3D used by player clicks and hover.
@export var selectable_path: NodePath = NodePath("../Selectable")
## Selected ring that should stay under the NPC's feet.
@export var selected_ring_path: NodePath = NodePath("../SelectedRing")
## ServiceNpcVisual3D node that owns idle/walk animation switching.
@export var visual_controller_path: NodePath = NodePath("../Visuals/ServiceNpcVisual")

@export_group("Wander")
## Enables or disables the ambient stroll without removing the component.
@export var wander_enabled := true
## Maximum local X/Z offset from the station's placed position.
@export_range(0.0, 4.0, 0.05) var wander_radius := 0.75
## Seconds to wait between short steps.
@export var idle_wait_range := Vector2(1.8, 4.2)
## Local movement speed in meters per second.
@export_range(0.05, 3.0, 0.05) var move_speed := 0.55
## Distance at which the NPC snaps to its chosen point and idles.
@export_range(0.02, 0.5, 0.01) var arrival_distance := 0.08
## Radians per second used to turn the visual toward movement direction.
@export_range(0.1, 24.0, 0.1) var turn_speed := 7.0
## Chance that the next wander point is the original placed position.
@export_range(0.0, 1.0, 0.05) var return_home_chance := 0.35
## Keeps selected NPCs still so interaction rings and menus feel stable.
@export var pause_when_selected := true

var _visuals: Node3D
var _visual_controller: Node
var _selectable: Node
var _moved_nodes: Array[Node3D] = []
var _home_positions: Array[Vector3] = []
var _current_offset := Vector3.ZERO
var _target_offset := Vector3.ZERO
var _wait_remaining := 0.0
var _rng := RandomNumberGenerator.new()
var _is_moving := false


func _ready() -> void:
	_rng.randomize()
	set_physics_process(false)
	call_deferred("_initialize")


func _initialize() -> void:
	_visuals = get_node_or_null(visuals_path) as Node3D
	_visual_controller = get_node_or_null(visual_controller_path)
	_selectable = get_node_or_null(selectable_path)
	_cache_moved_node(visuals_path)
	_cache_moved_node(body_path)
	_cache_moved_node(selectable_path)
	_cache_moved_node(selected_ring_path)
	_wait_remaining = _random_wait_time()
	set_physics_process(not _moved_nodes.is_empty())


func _physics_process(delta: float) -> void:
	if not wander_enabled or wander_radius <= 0.0:
		_set_moving(false)
		return

	if _should_pause_for_selection():
		_set_moving(false)
		return

	if _current_offset.distance_to(_target_offset) <= arrival_distance:
		_current_offset = _target_offset
		_apply_offset(_current_offset)
		_set_moving(false)
		_wait_remaining = maxf(_wait_remaining - delta, 0.0)
		if _wait_remaining <= 0.0:
			_target_offset = _random_target_offset()
			_wait_remaining = _random_wait_time()
		return

	var previous_offset := _current_offset
	_current_offset = _current_offset.move_toward(_target_offset, move_speed * delta)
	_apply_offset(_current_offset)
	_face_direction(_current_offset - previous_offset, delta)
	_set_moving(true)


func _cache_moved_node(path: NodePath) -> void:
	var node := get_node_or_null(path) as Node3D
	if node == null or _moved_nodes.has(node):
		return

	_moved_nodes.append(node)
	_home_positions.append(node.position)


func _apply_offset(offset: Vector3) -> void:
	var horizontal_offset := Vector3(offset.x, 0.0, offset.z)
	for index in range(_moved_nodes.size()):
		var node := _moved_nodes[index]
		if is_instance_valid(node):
			node.position = _home_positions[index] + horizontal_offset


func _face_direction(local_delta: Vector3, delta: float) -> void:
	if _visuals == null:
		return

	local_delta.y = 0.0
	if local_delta.length_squared() <= 0.000001:
		return

	var target_yaw := atan2(-local_delta.x, -local_delta.z)
	var turn_weight := clampf(turn_speed * delta, 0.0, 1.0)
	_visuals.rotation.y = lerp_angle(_visuals.rotation.y, target_yaw, turn_weight)


func _set_moving(is_moving: bool) -> void:
	if is_moving == _is_moving:
		return

	_is_moving = is_moving
	if _visual_controller != null and _visual_controller.has_method("set_moving"):
		_visual_controller.call("set_moving", _is_moving)


func _should_pause_for_selection() -> bool:
	return (
		pause_when_selected
		and _selectable != null
		and _selectable.has_method("is_selected")
		and bool(_selectable.call("is_selected"))
	)


func _random_target_offset() -> Vector3:
	if _rng.randf() <= return_home_chance:
		return Vector3.ZERO

	var direction := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT

	var distance := _rng.randf_range(wander_radius * 0.25, wander_radius)
	var offset := direction.normalized() * distance
	return Vector3(offset.x, 0.0, offset.y)


func _random_wait_time() -> float:
	var min_wait := minf(idle_wait_range.x, idle_wait_range.y)
	var max_wait := maxf(idle_wait_range.x, idle_wait_range.y)
	return _rng.randf_range(maxf(min_wait, 0.0), maxf(max_wait, 0.0))
