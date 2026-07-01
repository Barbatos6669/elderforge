## Player-facing helper that spawns click-to-move destination feedback.
##
## Keeping this separate lets the controller ask for feedback without knowing
## which effect scene is used.
class_name PlayerClickFeedback
extends Node

## Effect scene spawned when a new click-move starts.
@export var click_indicator_scene: PackedScene


## Spawns the configured indicator at a world position.
func spawn(world_position: Vector3, source_node: Node3D) -> void:
	if click_indicator_scene == null:
		return

	var indicator := click_indicator_scene.instantiate() as Node3D
	if indicator == null:
		return

	var effect_parent := source_node.get_parent()
	if effect_parent == null:
		effect_parent = get_tree().current_scene
	if effect_parent == null:
		effect_parent = source_node

	effect_parent.add_child(indicator)
	indicator.global_position = world_position
