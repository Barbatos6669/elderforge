## Output from shared damage resolution.
##
## `applied_damage` is the amount that actually changed health after current
## CombatHealth rules such as immunity, absorb shields, and defeat checks.
class_name DamageResult
extends Resource

var source: Node
var target: Node
var target_health: Node
var requested_damage := 0.0
var mitigated_damage := 0.0
var mitigation_amount := 0.0
var defense_value := 0.0
var applied_damage := 0.0
var damage_type: StringName = &"physical"


static func from_request(request: Resource) -> Resource:
	var result := new()
	if request == null:
		return result

	result.source = request.source
	result.target = request.target
	result.target_health = request.target_health
	result.requested_damage = request.amount
	result.mitigated_damage = request.amount
	result.damage_type = request.damage_type
	return result


func was_applied() -> bool:
	return applied_damage > 0.0
