## Adds a lightweight looping wind sway to static foliage or tree visuals.
##
## Attach this to the visible model root, not the resource/collision root. The
## collider stays fixed while only the art moves, which keeps pathing stable.
class_name WindSway3D
extends Node3D

## Enables or disables the wind animation without removing the component.
@export var wind_enabled := true
## Maximum rotation applied by the sway, in degrees.
@export_range(0.0, 15.0, 0.1) var sway_degrees := 1.5
## How quickly the tree moves back and forth.
@export_range(0.05, 10.0, 0.05) var sway_speed := 0.9
## Secondary side-to-side amount, as a multiplier of sway_degrees.
@export_range(0.0, 1.0, 0.05) var cross_sway_multiplier := 0.35
## Randomizes the starting phase so nearby trees do not move in lockstep.
@export var randomize_phase := true

var _base_basis := Basis.IDENTITY
var _phase := 0.0
var _elapsed := 0.0


func _ready() -> void:
	_base_basis = basis
	if randomize_phase:
		_phase = randf_range(0.0, TAU)


func _process(delta: float) -> void:
	if not wind_enabled:
		basis = _base_basis
		return

	_elapsed += maxf(delta, 0.0)
	var sway_radians := deg_to_rad(sway_degrees)
	var forward_sway := sin(_elapsed * sway_speed + _phase) * sway_radians
	var cross_sway := cos(_elapsed * sway_speed * 0.73 + _phase) * sway_radians * cross_sway_multiplier
	basis = _base_basis * Basis(Vector3.RIGHT, forward_sway) * Basis(Vector3.FORWARD, cross_sway)
