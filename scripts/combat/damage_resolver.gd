## Shared damage application entry point.
##
## Callers validate whether an impact should happen. This resolver turns a
## typed request into mitigated damage, then delegates health, immunity, absorb,
## and defeat confirmation to CombatHealth.
class_name DamageResolver
extends RefCounted

const DamageRequestScript := preload("res://scripts/combat/damage_request.gd")
const DamageResultScript := preload("res://scripts/combat/damage_result.gd")
const STAT_ARMOR := &"armor"
const STAT_MAGICAL_RESISTANCE := &"magical_resistance"
const MITIGATION_SCALE := 100.0


func resolve(request: Resource) -> Resource:
	var result: Resource = DamageResultScript.from_request(request)
	if request == null:
		return result

	var damage_type := DamageRequestScript.normalize_damage_type(request.damage_type)
	var health := _resolve_target_health(request)
	result.target_health = health
	result.damage_type = damage_type
	if health == null or not health.has_method("apply_damage"):
		return result

	var requested_damage := maxf(float(request.amount), 0.0)
	var defense_value := _defense_value_for_request(request, health, damage_type)
	var mitigated_damage := _apply_mitigation(requested_damage, defense_value, damage_type)
	result.requested_damage = requested_damage
	result.defense_value = defense_value
	result.mitigated_damage = mitigated_damage
	result.mitigation_amount = maxf(requested_damage - mitigated_damage, 0.0)
	result.applied_damage = float(health.call("apply_damage", mitigated_damage))
	return result


func _defense_value_for_request(
	request: Resource,
	health: Node,
	damage_type: StringName
) -> float:
	match damage_type:
		DamageRequestScript.TYPE_PHYSICAL:
			return _target_stat_value(request, health, STAT_ARMOR)
		DamageRequestScript.TYPE_MAGICAL:
			return _target_stat_value(request, health, STAT_MAGICAL_RESISTANCE)
		_:
			return 0.0


func _target_stat_value(request: Resource, health: Node, stat_id: StringName) -> float:
	var stats := _find_stats_node(request.target)
	if stats == null:
		stats = _find_stats_node(health)
	if stats == null and health != null:
		stats = _find_stats_node(health.get_parent())
	if stats == null or not stats.has_method("get_stat"):
		return 0.0

	return maxf(float(stats.call("get_stat", stat_id)), 0.0)


func _find_stats_node(node: Node) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	if node.has_method("get_stat"):
		return node

	var child_stats := node.get_node_or_null("Stats")
	if child_stats != null and child_stats.has_method("get_stat"):
		return child_stats

	var parent_node := node.get_parent()
	if parent_node == null:
		return null

	var sibling_stats := parent_node.get_node_or_null("Stats")
	if sibling_stats != null and sibling_stats.has_method("get_stat"):
		return sibling_stats

	return null


func _apply_mitigation(
	amount: float,
	defense_value: float,
	damage_type: StringName
) -> float:
	var safe_amount := maxf(amount, 0.0)
	if safe_amount <= 0.0 or defense_value <= 0.0:
		return safe_amount
	if damage_type == DamageRequestScript.TYPE_TRUE:
		return safe_amount

	return safe_amount * MITIGATION_SCALE / (MITIGATION_SCALE + maxf(defense_value, 0.0))


func _resolve_target_health(request: Resource) -> Node:
	if request.target_health != null and is_instance_valid(request.target_health):
		return request.target_health

	var target: Node = request.target
	if target == null or not is_instance_valid(target):
		return null
	if target.has_method("apply_damage"):
		return target
	var child_health := target.get_node_or_null("Health")
	if child_health != null:
		return child_health

	var parent_node: Node = target.get_parent()
	if parent_node == null:
		return null

	return parent_node.get_node_or_null("Health")
