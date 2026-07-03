## Handles local player target selection.
##
## This module intentionally owns only target selection. Movement remains in
## PlayerInput/PlayerMovementMotor, while selectable objects own their own
## selection state through Selectable3D.
class_name PlayerTargeting
extends Node

signal target_changed(target: Node)

## Maximum distance for selection raycasts from the active camera.
@export var selection_ray_length: float = 1000.0
## Physics layers checked for selectable hitboxes.
@export_flags_3d_physics var selection_collision_mask: int = 8

var _current_target: Node
var _was_left_mouse_down := false


## Syncs click-edge state while UI windows are handling the mouse.
func consume_current_click_state() -> void:
	_was_left_mouse_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


## Attempts to select a target on left-click. Returns the clicked selectable when
## targeting consumed the click, or null when click-to-move can continue.
func try_select_on_click(character: CharacterBody3D) -> Node:
	var is_left_mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var was_left_click_started := is_left_mouse_down and not _was_left_mouse_down
	_was_left_mouse_down = is_left_mouse_down

	if not was_left_click_started:
		return null

	var selectable := _get_selectable_under_mouse(character)
	if selectable == null:
		return null

	set_current_target(selectable)
	return selectable


## Returns the current selected target, or null when nothing is selected.
func get_current_target() -> Node:
	return _current_target


## Updates the selected target and clears the previous target's state.
func set_current_target(target: Node) -> void:
	if target == _current_target:
		return

	if _current_target != null and is_instance_valid(_current_target) and _current_target.has_method("set_selected"):
		_current_target.set_selected(false)

	_current_target = target

	if _current_target != null and _current_target.has_method("set_selected"):
		_current_target.set_selected(true)

	target_changed.emit(_current_target)


## Clears the selected target.
func clear_current_target() -> void:
	set_current_target(null)


func _get_selectable_under_mouse(character: CharacterBody3D) -> Node:
	var camera := character.get_viewport().get_camera_3d()
	if camera == null:
		return null

	var mouse_position := character.get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var ray_end := ray_origin + ray_direction * selection_ray_length
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, selection_collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var hit := character.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.has("collider"):
		return null

	var selectable := hit["collider"] as Node
	if selectable == null or not selectable.has_method("can_select") or not selectable.can_select():
		return null

	return selectable
