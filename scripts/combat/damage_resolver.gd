## Shared damage application entry point.
##
## This intentionally delegates to CombatHealth for today's behavior. Future
## mitigation, server authority, and typed damage rules can live here without
## changing each caller's impact timing code.
class_name DamageResolver
extends RefCounted

const DamageResultScript := preload("res://scripts/combat/damage_result.gd")


func resolve(request: Resource) -> Resource:
	var result: Resource = DamageResultScript.from_request(request)
	if request == null:
		return result

	var health := _resolve_target_health(request)
	result.target_health = health
	if health == null or not health.has_method("apply_damage"):
		return result

	result.applied_damage = float(health.call("apply_damage", request.amount))
	return result


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
