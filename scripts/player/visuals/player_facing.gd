class_name PlayerFacing
extends Node

@export var visuals_path: NodePath = NodePath("../Visuals")

@onready var visuals: Node3D = get_node_or_null(visuals_path) as Node3D


func face_direction(movement_direction: Vector3) -> void:
	if movement_direction == Vector3.ZERO or visuals == null:
		return

	visuals.look_at(visuals.global_position + movement_direction, Vector3.UP)
