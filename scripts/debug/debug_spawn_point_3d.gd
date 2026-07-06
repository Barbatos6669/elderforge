## Visible spawn marker for prototype scenes.
##
## Gameplay systems can treat this as a normal Marker3D. The extra script data is
## for designers/debug tools that need to identify or hide spawn markers.
class_name DebugSpawnPoint3D
extends Marker3D

## Human-readable id for future spawn selection or debug tools.
@export var spawn_id := "player_start"
## Lets designers keep the spawn transform while hiding the debug meshes.
@export var show_debug_visuals := true:
	set(value):
		show_debug_visuals = value
		_sync_visuals()

@onready var _visuals := get_node_or_null("Visuals") as Node3D


func _ready() -> void:
	add_to_group("debug_spawn_points")
	_sync_visuals()


func _sync_visuals() -> void:
	if _visuals == null:
		return

	_visuals.visible = show_debug_visuals
