class_name FootstepSurfaceSet
extends Resource

@export var streams: Array[AudioStream] = []
@export_range(-40.0, 12.0, 0.1) var volume_db: float = -2.0
@export_range(0.1, 1.5, 0.01) var fallback_step_interval: float = 0.56
@export_range(0.0, 0.25, 0.01) var pitch_variation: float = 0.08


func has_streams() -> bool:
	return not streams.is_empty()
