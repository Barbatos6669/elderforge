## One structured effect row shown in an ability tooltip.
##
## Keeping tooltip effects as resources lets designers add, remove, and reorder
## rows in the Inspector without teaching the HUD about individual abilities.
class_name AbilityTooltipEffect
extends Resource

@export var label := "Effect"
@export var value := ""
@export_enum("neutral", "damage", "buff", "debuff", "control", "mobility", "healing", "recovery", "survival", "utility")
var tone := "neutral"
