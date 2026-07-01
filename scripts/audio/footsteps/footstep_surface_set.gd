## Data resource for one group of footstep sounds, such as grass, stone, or wood.
##
## Keeping these settings in resources lets terrain/equipment systems swap
## footstep behavior without editing the player scene or audio script.
class_name FootstepSurfaceSet
extends Resource

## Candidate one-shot sounds for this surface. Playback rotates through them.
@export var streams: Array[AudioStream] = []
## Per-surface volume trim applied to the player footstep audio node.
@export_range(-40.0, 12.0, 0.1) var volume_db: float = -2.0
## Timer used only when animation-synced footsteps are unavailable.
@export_range(0.1, 1.5, 0.01) var fallback_step_interval: float = 0.56
## Random pitch range applied around 1.0 to reduce repeated-step sameness.
@export_range(0.0, 0.25, 0.01) var pitch_variation: float = 0.08


## Returns true when this surface has at least one playable footstep stream.
func has_streams() -> bool:
	return not streams.is_empty()
