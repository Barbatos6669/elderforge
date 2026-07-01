## Reusable selection target for 3D gameplay objects.
##
## Attach this to an Area3D or other CollisionObject3D that should be selectable
## by local player input. The script owns only selection state; visuals listen to
## `selection_changed` or read `is_selected()`.
class_name Selectable3D
extends Area3D

signal selection_changed(is_selected: bool)

enum Relationship {
	FRIENDLY,
	HOSTILE,
	NEUTRAL,
}

## Display name used by targeting UI and debug logs.
@export var display_name: String = "Selectable"
## Allows designers to temporarily disable selection without removing hitboxes.
@export var selection_enabled: bool = true
## Gameplay allegiance used by hover/selection feedback.
@export var relationship: Relationship = Relationship.FRIENDLY

@export_group("Relationship Colors")
## Color used for friendly targets.
@export var friendly_color: Color = Color(0.25, 1.0, 0.16, 1.0)
## Color used for hostile targets.
@export var hostile_color: Color = Color(1.0, 0.12, 0.08, 1.0)
## Color used for neutral or unknown targets.
@export var neutral_color: Color = Color(1.0, 0.82, 0.18, 1.0)

var _is_selected := false


func _ready() -> void:
	add_to_group("selectable_3d")


## Returns whether this target is currently selected by the local player.
func is_selected() -> bool:
	return _is_selected


## Sets local selection state and notifies any visual feedback nodes.
func set_selected(value: bool) -> void:
	if value == _is_selected:
		return

	_is_selected = value
	selection_changed.emit(_is_selected)


## Returns true when local targeting is allowed to select this object.
func can_select() -> bool:
	return selection_enabled


## Returns the current relationship enum value.
func get_relationship() -> Relationship:
	return relationship


## Returns true when this selectable should be treated as friendly.
func is_friendly() -> bool:
	return relationship == Relationship.FRIENDLY


## Returns true when this selectable should be treated as hostile.
func is_hostile() -> bool:
	return relationship == Relationship.HOSTILE


## Returns the color shared by hover, outline, and selected-target feedback.
func get_relationship_color() -> Color:
	match relationship:
		Relationship.FRIENDLY:
			return friendly_color
		Relationship.HOSTILE:
			return hostile_color
		_:
			return neutral_color
