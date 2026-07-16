## Generic stat component for mobs, creatures, and NPCs.
##
## PlayerStats has the larger player-facing registry. This lighter component is
## for non-player actors that still need the same core stat ids and Forged Trait
## modifiers.
class_name EntityStats
extends Node

signal stat_changed(stat_id: StringName, value: float)

@export var forged_traits_path: NodePath = NodePath("../ForgedTraits")

@export_group("Combat")
@export var max_health := 1200.0
@export var health_regeneration := 10.0
@export var auto_attack_damage := 20.0
@export var auto_attack_speed := 1.0
@export var armor := 0.0
@export var magical_resistance := 0.0

@export_group("Movement")
@export var move_speed := 3.2

var _forged_traits: Node


func _ready() -> void:
	add_to_group("entity_stats")
	_bind_forged_traits()


func has_stat(stat_id: StringName) -> bool:
	match stat_id:
		ForgedTraitCatalog.STAT_MAX_HEALTH, \
		ForgedTraitCatalog.STAT_HEALTH_REGENERATION, \
		ForgedTraitCatalog.STAT_AUTO_ATTACK_DAMAGE, \
		ForgedTraitCatalog.STAT_AUTO_ATTACK_SPEED, \
		ForgedTraitCatalog.STAT_ARMOR, \
		ForgedTraitCatalog.STAT_MAGICAL_RESISTANCE, \
		ForgedTraitCatalog.STAT_MOVE_SPEED:
			return true
		_:
			return false


func get_stat(stat_id: StringName) -> float:
	if not has_stat(stat_id):
		return 0.0

	return get_base_stat(stat_id) + get_stat_modifier(stat_id)


func get_base_stat(stat_id: StringName) -> float:
	match stat_id:
		ForgedTraitCatalog.STAT_MAX_HEALTH:
			return max_health
		ForgedTraitCatalog.STAT_HEALTH_REGENERATION:
			return health_regeneration
		ForgedTraitCatalog.STAT_AUTO_ATTACK_DAMAGE:
			return auto_attack_damage
		ForgedTraitCatalog.STAT_AUTO_ATTACK_SPEED:
			return auto_attack_speed
		ForgedTraitCatalog.STAT_ARMOR:
			return armor
		ForgedTraitCatalog.STAT_MAGICAL_RESISTANCE:
			return magical_resistance
		ForgedTraitCatalog.STAT_MOVE_SPEED:
			return move_speed
		_:
			return 0.0


func get_stat_modifier(stat_id: StringName) -> float:
	var modifiers := get_active_stat_modifiers()
	return float(modifiers.get(StringName(String(stat_id)), 0.0))


func get_active_stat_modifiers() -> Dictionary:
	if _forged_traits == null or not _forged_traits.has_method("get_active_stat_modifiers"):
		return {}

	var modifiers: Variant = _forged_traits.call("get_active_stat_modifiers")
	if modifiers is Dictionary:
		return modifiers as Dictionary

	return {}


func emit_all_stats_changed() -> void:
	for stat_id in [
		ForgedTraitCatalog.STAT_MAX_HEALTH,
		ForgedTraitCatalog.STAT_HEALTH_REGENERATION,
		ForgedTraitCatalog.STAT_AUTO_ATTACK_DAMAGE,
		ForgedTraitCatalog.STAT_AUTO_ATTACK_SPEED,
		ForgedTraitCatalog.STAT_ARMOR,
		ForgedTraitCatalog.STAT_MAGICAL_RESISTANCE,
		ForgedTraitCatalog.STAT_MOVE_SPEED,
	]:
		stat_changed.emit(stat_id, get_stat(stat_id))


func _bind_forged_traits() -> void:
	_forged_traits = get_node_or_null(forged_traits_path)
	if _forged_traits == null:
		return

	var callable := Callable(self, "_on_forged_traits_changed")
	if _forged_traits.has_signal("traits_changed") and not _forged_traits.is_connected("traits_changed", callable):
		_forged_traits.connect("traits_changed", callable)


func _on_forged_traits_changed() -> void:
	emit_all_stats_changed()
