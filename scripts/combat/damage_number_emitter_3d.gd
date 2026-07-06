## Spawns floating damage numbers when a CombatHealth node takes damage.
##
## Attach this beside any `CombatHealth` component. The default paths work for
## scenes shaped like:
##
## Entity
## - Health
## - DamageNumbers
class_name DamageNumberEmitter3D
extends Node

const FloatingDamageNumberScript := preload("res://scripts/combat/floating_damage_number_3d.gd")

## Health component that emits `damage_taken`.
@export var health_path: NodePath = NodePath("../Health")
## World node used as the starting point for the number.
@export var source_path: NodePath = NodePath("..")
## World-space offset from `source_path` where numbers appear.
@export var spawn_offset := Vector3(0.0, 1.15, 0.0)
## Random left/right and forward/back spread so repeated hits remain readable.
@export var jitter_radius := Vector2(0.18, 0.10)
## How far each number drifts horizontally while it rises.
@export var drift_distance := 0.18
## Damage text color. Enemy damage can use a different color in its scene.
@export var damage_color := Color(1.0, 0.86, 0.24, 1.0)

var _health: CombatHealth


func _ready() -> void:
	_health = get_node_or_null(health_path) as CombatHealth
	if _health == null:
		push_warning("DamageNumberEmitter3D could not find CombatHealth at %s." % health_path)
		return

	_health.damage_taken.connect(_on_damage_taken)


func _on_damage_taken(amount: float) -> void:
	var source := get_node_or_null(source_path) as Node3D
	if source == null:
		return

	var number = FloatingDamageNumberScript.new()
	number.horizontal_drift = _random_drift()
	number.setup(amount, damage_color)

	var parent := _spawn_parent(source)
	parent.add_child(number)
	number.global_position = source.global_position + spawn_offset + _random_jitter()


func _spawn_parent(source: Node3D) -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		return scene

	if source.get_parent() != null:
		return source.get_parent()

	return self


func _random_jitter() -> Vector3:
	return Vector3(
		randf_range(-jitter_radius.x, jitter_radius.x),
		0.0,
		randf_range(-jitter_radius.y, jitter_radius.y)
	)


func _random_drift() -> Vector3:
	var direction := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT

	direction = direction.normalized() * drift_distance
	return Vector3(direction.x, 0.0, direction.y)
