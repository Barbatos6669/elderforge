## Reusable one-shot sound data for a weapon combat style.
##
## A player audio component consumes this resource, which keeps weapon sounds
## swappable without hard-coding imported clips in controller logic.
class_name CombatSoundSet
extends Resource

## Sounds played when an attack begins its visible swing.
@export var swing_streams: Array[AudioStream] = []
## Sounds played only after an attack confirms damage on a target.
@export var impact_streams: Array[AudioStream] = []
## Non-voiced body impacts played when this character receives damage.
@export var hurt_streams: Array[AudioStream] = []

@export_group("Mix")
@export_range(-40.0, 12.0, 0.1) var swing_volume_db := -6.0
@export_range(-40.0, 12.0, 0.1) var impact_volume_db := -5.0
@export_range(-40.0, 12.0, 0.1) var hurt_volume_db := -8.0
## Random variation around pitch 1.0 keeps repeated attacks from sounding identical.
@export_range(0.0, 0.25, 0.01) var pitch_variation := 0.05


func has_swing_streams() -> bool:
	return not swing_streams.is_empty()


func has_impact_streams() -> bool:
	return not impact_streams.is_empty()


func has_hurt_streams() -> bool:
	return not hurt_streams.is_empty()
