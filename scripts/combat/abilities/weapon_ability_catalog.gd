## Registry for weapon abilities that can cross the prototype network boundary.
##
## Network messages send stable ids instead of client-provided resource paths.
class_name WeaponAbilityCatalog
extends RefCounted

const ABILITY_PATHS := {
	"one_handed_sword_q": "res://assets/combat/abilities/one_handed_sword_q.tres",
	"one_handed_sword_w": "res://assets/combat/abilities/one_handed_sword_w.tres",
	"moonleaf_binding": "res://assets/combat/abilities/moonleaf_binding.tres",
	"energizing_shield": "res://assets/combat/abilities/energizing_shield.tres",
	"leather_boots_roll": "res://assets/combat/abilities/leather_boots_roll.tres",
}


static func get_definition(ability_id: String) -> Resource:
	var path := String(ABILITY_PATHS.get(ability_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null

	return load(path) as Resource


static func has_ability(ability_id: String) -> bool:
	return ABILITY_PATHS.has(ability_id)
