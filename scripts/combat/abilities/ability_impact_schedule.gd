## Tracks one or more authored impact moments inside a single ability cast.
class_name AbilityImpactSchedule
extends RefCounted

const TIME_EPSILON := 0.0001

var _duration_seconds := 0.0
var _elapsed_seconds := 0.0
var _impact_fractions := PackedFloat32Array()
var _damage_scales := PackedFloat32Array()
var _next_impact_index := 0


func begin(definition: Resource, duration_seconds: float) -> void:
	reset()
	_duration_seconds = maxf(duration_seconds, 0.01)
	_impact_fractions = _definition_impact_fractions(definition)
	_damage_scales = _definition_damage_scales(definition, _impact_fractions.size())


## Advances the cast and returns every impact crossed by this frame.
func advance(delta: float) -> PackedInt32Array:
	var crossed := PackedInt32Array()
	if _impact_fractions.is_empty():
		return crossed

	_elapsed_seconds = minf(
		_elapsed_seconds + maxf(delta, 0.0),
		_duration_seconds
	)
	while _next_impact_index < _impact_fractions.size():
		var impact_time := _duration_seconds * _impact_fractions[_next_impact_index]
		if _elapsed_seconds + TIME_EPSILON < impact_time:
			break
		crossed.append(_next_impact_index)
		_next_impact_index += 1
	return crossed


func reset() -> void:
	_duration_seconds = 0.0
	_elapsed_seconds = 0.0
	_impact_fractions = PackedFloat32Array()
	_damage_scales = PackedFloat32Array()
	_next_impact_index = 0


func get_impact_count() -> int:
	return _impact_fractions.size()


func get_impact_fraction(index: int) -> float:
	return _impact_fractions[index] if index >= 0 and index < _impact_fractions.size() else 0.0


func get_damage_scale(index: int) -> float:
	return _damage_scales[index] if index >= 0 and index < _damage_scales.size() else 1.0


func get_seconds_between_impacts(previous_index: int, next_index: int) -> float:
	if next_index < 0 or next_index >= _impact_fractions.size():
		return 0.0
	var previous_fraction := 0.0
	if previous_index >= 0 and previous_index < _impact_fractions.size():
		previous_fraction = _impact_fractions[previous_index]
	return maxf(
		(_impact_fractions[next_index] - previous_fraction) * _duration_seconds,
		0.0
	)


static func first_impact_fraction(definition: Resource) -> float:
	return _definition_impact_fractions(definition)[0]


static func _definition_impact_fractions(definition: Resource) -> PackedFloat32Array:
	var authored := PackedFloat32Array()
	if definition != null:
		var authored_value: Variant = definition.get("impact_fractions")
		if authored_value is PackedFloat32Array:
			authored = (authored_value as PackedFloat32Array).duplicate()

	if authored.is_empty():
		authored.append(
			clampf(float(definition.get("impact_fraction")), 0.0, 1.0)
			if definition != null
			else 0.5
		)

	var normalized := PackedFloat32Array()
	var previous_fraction := 0.0
	for authored_fraction in authored:
		var fraction := maxf(clampf(float(authored_fraction), 0.0, 1.0), previous_fraction)
		normalized.append(fraction)
		previous_fraction = fraction
	return normalized


static func _definition_damage_scales(definition: Resource, impact_count: int) -> PackedFloat32Array:
	var authored := PackedFloat32Array()
	if definition != null:
		var authored_value: Variant = definition.get("impact_damage_scales")
		if authored_value is PackedFloat32Array:
			authored = authored_value as PackedFloat32Array

	var normalized := PackedFloat32Array()
	for index in range(impact_count):
		normalized.append(maxf(float(authored[index]), 0.0) if index < authored.size() else 1.0)
	return normalized
