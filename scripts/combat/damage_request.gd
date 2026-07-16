## Typed input for shared damage resolution.
##
## Callers still own timing, range, and hostility checks. The resolver owns
## typed mitigation and the final application through the target health
## component.
class_name DamageRequest
extends Resource

const TYPE_PHYSICAL := &"physical"
const TYPE_MAGICAL := &"magical"
const TYPE_TRUE := &"true"

var source: Node
var target: Node
var target_health: Node
var amount := 0.0
var damage_type: StringName = TYPE_PHYSICAL


static func normalize_damage_type(request_damage_type: StringName) -> StringName:
	var clean_type := StringName(String(request_damage_type).strip_edges().to_lower())
	match clean_type:
		TYPE_PHYSICAL, TYPE_MAGICAL, TYPE_TRUE:
			return clean_type
		_:
			return TYPE_PHYSICAL


static func create(
	request_source: Node,
	request_target: Node,
	request_amount: float,
	request_damage_type: StringName = TYPE_PHYSICAL,
	request_target_health: Node = null
) -> Resource:
	var request := new()
	request.source = request_source
	request.target = request_target
	request.target_health = request_target_health
	request.amount = maxf(request_amount, 0.0)
	request.damage_type = normalize_damage_type(request_damage_type)
	return request
