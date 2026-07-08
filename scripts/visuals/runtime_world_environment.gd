## Applies runtime-only environment settings for playable levels.
##
## Keep expensive or visually obstructive editor-time atmosphere disabled in the
## scene file, then restore it here when the game starts.
class_name RuntimeWorldEnvironment
extends WorldEnvironment

## Restores environment fog when the game runs.
@export var fog_enabled_in_game := true


func _ready() -> void:
	if Engine.is_editor_hint() or environment == null:
		return

	environment.fog_enabled = fog_enabled_in_game
