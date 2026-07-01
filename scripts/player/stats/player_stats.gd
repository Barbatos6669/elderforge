class_name PlayerStats
extends Node

signal stat_changed(stat_id: StringName, value: float)

const FORMAT_NUMBER := &"number"
const FORMAT_PERCENT := &"percent"
const FORMAT_PER_SECOND := &"per_second"
const FORMAT_KILOGRAM := &"kilogram"
const FORMAT_PER_DAY := &"per_day"

const CATEGORY_POWER := &"power"
const CATEGORY_PROGRESSION := &"progression"
const CATEGORY_COMBAT := &"combat"
const CATEGORY_DEFENSE := &"defense"
const CATEGORY_RESOURCES := &"resources"
const CATEGORY_UTILITY := &"utility"
const CATEGORY_PVP := &"pvp"
const CATEGORY_PVE := &"pve"
const CATEGORY_GATHERING := &"gathering"

const AVERAGE_ITEM_POWER := &"average_item_power"
const BASE_AVERAGE_ITEM_POWER := &"base_average_item_power"
const FOCUS := &"focus"
const LEARNING_POINTS := &"learning_points"
const REPUTATION := &"reputation"
const REPUTATION_CHANGE := &"reputation_change"
const AUTO_ATTACK_DAMAGE := &"auto_attack_damage"
const PHYSICAL_ABILITY_BONUS := &"physical_ability_bonus"
const MAGICAL_ABILITY_BONUS := &"magical_ability_bonus"
const MAGICAL_RESISTANCE := &"magical_resistance"
const ARMOR := &"armor"
const MAX_HEALTH := &"max_health"
const HEALTH_REGENERATION := &"health_regeneration"
const MAX_ENERGY := &"max_energy"
const ENERGY_REGENERATION := &"energy_regeneration"
const MAX_FOCUS := &"max_focus"
const FOCUS_REGENERATION := &"focus_regeneration"
const ENERGY_COST_REDUCTION := &"energy_cost_reduction"
const HEALING_RECEIVED_BONUS := &"healing_received_bonus"
const HEALING_CAST_BONUS := &"healing_cast_bonus"
const MOVE_SPEED := &"move_speed"
const CROWD_CONTROL_RESISTANCE := &"crowd_control_resistance"
const CAST_TIME := &"cast_time"
const AUTO_ATTACK_SPEED := &"auto_attack_speed"
const DAMAGE_PER_SECOND := &"damage_per_second"
const COOLDOWN_RATE := &"cooldown_rate"
const MAX_LOAD := &"max_load"
const DAMAGE_VS_PLAYERS := &"damage_vs_players"
const DEFENSE_VS_PLAYERS := &"defense_vs_players"
const CC_RESISTANCE_VS_PLAYERS := &"cc_resistance_vs_players"
const CC_DURATION_VS_PLAYERS := &"cc_duration_vs_players"
const DAMAGE_VS_MOBS := &"damage_vs_mobs"
const DEFENSE_VS_MOBS := &"defense_vs_mobs"
const CC_RESISTANCE_VS_MOBS := &"cc_resistance_vs_mobs"
const CC_DURATION_VS_MOBS := &"cc_duration_vs_mobs"
const FIBER_YIELD := &"fiber_yield"
const HIDE_YIELD := &"hide_yield"
const ORE_YIELD := &"ore_yield"
const STONE_YIELD := &"stone_yield"
const WOOD_YIELD := &"wood_yield"
const FISHING_YIELD := &"fishing_yield"

const STAT_DEFINITIONS := [
	{"id": AVERAGE_ITEM_POWER, "name": "Average Item Power", "category": CATEGORY_POWER, "format": FORMAT_NUMBER},
	{"id": BASE_AVERAGE_ITEM_POWER, "name": "Base Average Item Power", "category": CATEGORY_POWER, "format": FORMAT_NUMBER},
	{"id": FOCUS, "name": "Focus", "category": CATEGORY_RESOURCES, "format": FORMAT_NUMBER},
	{"id": LEARNING_POINTS, "name": "Learning Points", "category": CATEGORY_PROGRESSION, "format": FORMAT_NUMBER},
	{"id": REPUTATION, "name": "Reputation", "category": CATEGORY_PROGRESSION, "format": FORMAT_NUMBER},
	{"id": REPUTATION_CHANGE, "name": "Reputation Change", "category": CATEGORY_PROGRESSION, "format": FORMAT_PER_DAY},
	{"id": AUTO_ATTACK_DAMAGE, "name": "Auto-Attack Damage", "category": CATEGORY_COMBAT, "format": FORMAT_NUMBER},
	{"id": PHYSICAL_ABILITY_BONUS, "name": "Physical Ability Bonus", "category": CATEGORY_COMBAT, "format": FORMAT_PERCENT},
	{"id": MAGICAL_ABILITY_BONUS, "name": "Magical Ability Bonus", "category": CATEGORY_COMBAT, "format": FORMAT_PERCENT},
	{"id": MAGICAL_RESISTANCE, "name": "Magical Resistance", "category": CATEGORY_DEFENSE, "format": FORMAT_NUMBER},
	{"id": ARMOR, "name": "Armor", "category": CATEGORY_DEFENSE, "format": FORMAT_NUMBER},
	{"id": MAX_HEALTH, "name": "Max Health", "category": CATEGORY_RESOURCES, "format": FORMAT_NUMBER},
	{"id": HEALTH_REGENERATION, "name": "Health Regeneration", "category": CATEGORY_RESOURCES, "format": FORMAT_PER_SECOND},
	{"id": MAX_ENERGY, "name": "Max Energy", "category": CATEGORY_RESOURCES, "format": FORMAT_NUMBER},
	{"id": ENERGY_REGENERATION, "name": "Energy Regeneration", "category": CATEGORY_RESOURCES, "format": FORMAT_PER_SECOND},
	{"id": MAX_FOCUS, "name": "Max. Focus", "category": CATEGORY_RESOURCES, "format": FORMAT_NUMBER},
	{"id": FOCUS_REGENERATION, "name": "Focus Regeneration", "category": CATEGORY_RESOURCES, "format": FORMAT_PER_DAY},
	{"id": ENERGY_COST_REDUCTION, "name": "Energy Cost Reduction", "category": CATEGORY_UTILITY, "format": FORMAT_PERCENT},
	{"id": HEALING_RECEIVED_BONUS, "name": "Healing Received Bonus", "category": CATEGORY_UTILITY, "format": FORMAT_PERCENT},
	{"id": HEALING_CAST_BONUS, "name": "Healing Cast Bonus", "category": CATEGORY_UTILITY, "format": FORMAT_PERCENT},
	{"id": MOVE_SPEED, "name": "Move Speed", "category": CATEGORY_UTILITY, "format": FORMAT_PER_SECOND},
	{"id": CROWD_CONTROL_RESISTANCE, "name": "Crowd Control Resistance", "category": CATEGORY_UTILITY, "format": FORMAT_NUMBER},
	{"id": CAST_TIME, "name": "Cast Time", "category": CATEGORY_COMBAT, "format": FORMAT_PERCENT},
	{"id": AUTO_ATTACK_SPEED, "name": "Auto-Attack Speed", "category": CATEGORY_COMBAT, "format": FORMAT_PER_SECOND},
	{"id": DAMAGE_PER_SECOND, "name": "Damage per Second", "category": CATEGORY_COMBAT, "format": FORMAT_PER_SECOND},
	{"id": COOLDOWN_RATE, "name": "Cooldown Rate", "category": CATEGORY_COMBAT, "format": FORMAT_PERCENT},
	{"id": MAX_LOAD, "name": "Max Load", "category": CATEGORY_UTILITY, "format": FORMAT_KILOGRAM},
	{"id": DAMAGE_VS_PLAYERS, "name": "Damage vs. Players", "category": CATEGORY_PVP, "format": FORMAT_PERCENT},
	{"id": DEFENSE_VS_PLAYERS, "name": "Defense vs. Players", "category": CATEGORY_PVP, "format": FORMAT_PERCENT},
	{"id": CC_RESISTANCE_VS_PLAYERS, "name": "CC Resistance vs. Players", "category": CATEGORY_PVP, "format": FORMAT_PERCENT},
	{"id": CC_DURATION_VS_PLAYERS, "name": "CC Duration vs. Players", "category": CATEGORY_PVP, "format": FORMAT_PERCENT},
	{"id": DAMAGE_VS_MOBS, "name": "Damage vs. Mobs", "category": CATEGORY_PVE, "format": FORMAT_PERCENT},
	{"id": DEFENSE_VS_MOBS, "name": "Defense vs. Mobs", "category": CATEGORY_PVE, "format": FORMAT_PERCENT},
	{"id": CC_RESISTANCE_VS_MOBS, "name": "CC Resistance vs. Mobs", "category": CATEGORY_PVE, "format": FORMAT_PERCENT},
	{"id": CC_DURATION_VS_MOBS, "name": "CC Duration vs. Mobs", "category": CATEGORY_PVE, "format": FORMAT_PERCENT},
	{"id": FIBER_YIELD, "name": "Fiber Yield", "category": CATEGORY_GATHERING, "format": FORMAT_PERCENT},
	{"id": HIDE_YIELD, "name": "Hide Yield", "category": CATEGORY_GATHERING, "format": FORMAT_PERCENT},
	{"id": ORE_YIELD, "name": "Ore Yield", "category": CATEGORY_GATHERING, "format": FORMAT_PERCENT},
	{"id": STONE_YIELD, "name": "Stone Yield", "category": CATEGORY_GATHERING, "format": FORMAT_PERCENT},
	{"id": WOOD_YIELD, "name": "Wood Yield", "category": CATEGORY_GATHERING, "format": FORMAT_PERCENT},
	{"id": FISHING_YIELD, "name": "Fishing Yield", "category": CATEGORY_GATHERING, "format": FORMAT_PERCENT},
]

var _values: Dictionary = {}


func _ready() -> void:
	reset_all_to_zero()


func reset_all_to_zero() -> void:
	for definition in STAT_DEFINITIONS:
		_values[definition["id"]] = 0.0


func has_stat(stat_id: StringName) -> bool:
	return _values.has(stat_id)


func get_stat(stat_id: StringName) -> float:
	if not has_stat(stat_id):
		return 0.0

	return _values[stat_id]


func set_stat(stat_id: StringName, value: float) -> void:
	if not _is_defined_stat(stat_id):
		push_warning("Ignoring unknown player stat: %s" % stat_id)
		return

	if not has_stat(stat_id):
		_values[stat_id] = 0.0

	if is_equal_approx(_values[stat_id], value):
		return

	_values[stat_id] = value
	stat_changed.emit(stat_id, value)


func add_to_stat(stat_id: StringName, amount: float) -> void:
	set_stat(stat_id, get_stat(stat_id) + amount)


func get_all_stats() -> Dictionary:
	return _values.duplicate()


func get_display_name(stat_id: StringName) -> String:
	var definition := get_definition(stat_id)
	if definition.is_empty():
		return String(stat_id)

	return definition["name"]


func get_format(stat_id: StringName) -> StringName:
	var definition := get_definition(stat_id)
	if definition.is_empty():
		return FORMAT_NUMBER

	return definition["format"]


func get_category(stat_id: StringName) -> StringName:
	var definition := get_definition(stat_id)
	if definition.is_empty():
		return &""

	return definition["category"]


func get_definition(stat_id: StringName) -> Dictionary:
	for definition in STAT_DEFINITIONS:
		if definition["id"] == stat_id:
			return definition.duplicate()

	return {}


func get_stat_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition in STAT_DEFINITIONS:
		ids.append(definition["id"])

	return ids


func _is_defined_stat(stat_id: StringName) -> bool:
	for definition in STAT_DEFINITIONS:
		if definition["id"] == stat_id:
			return true

	return false
