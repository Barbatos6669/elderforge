## Rotates the player's visual model toward the current movement direction.
##
## The root CharacterBody3D keeps gameplay orientation independent from visual
## orientation, which is useful later for targeting, mounts, and animation.
class_name PlayerFacing
extends Node

## Node containing the visible player model.
@export var visuals_path: NodePath = NodePath("../Visuals")

@onready var visuals: Node3D = get_node_or_null(visuals_path) as Node3D


## Faces the visual root toward a normalized or non-normalized world direction.
func face_direction(movement_direction: Vector3) -> void:
	if movement_direction == Vector3.ZERO or visuals == null:
		return

	visuals.look_at(visuals.global_position + movement_direction, Vector3.UP)
