## Shared catalog for Elderforge's Forged Traits.
##
## Forged Traits are purchased with ability stat points, then slotted/activated
## separately. Only active traits contribute stat modifiers. Keeping the catalog
## data-only lets players, mobs, and creatures all use the same progression rules.
class_name ForgedTraitCatalog
extends RefCounted

const ENTITY_PLAYER := &"player"
const ENTITY_MOB := &"mob"
const ENTITY_CREATURE := &"creature"
const ENTITY_NPC := &"npc"

const STAT_MAX_HEALTH := &"max_health"
const STAT_HEALTH_REGENERATION := &"health_regeneration"
const STAT_MAX_ENERGY := &"max_energy"
const STAT_ENERGY_REGENERATION := &"energy_regeneration"
const STAT_AUTO_ATTACK_DAMAGE := &"auto_attack_damage"
const STAT_AUTO_ATTACK_SPEED := &"auto_attack_speed"
const STAT_ARMOR := &"armor"
const STAT_MAGICAL_RESISTANCE := &"magical_resistance"
const STAT_MOVE_SPEED := &"move_speed"
const STAT_MAX_LOAD := &"max_load"
const STAT_WOOD_YIELD := &"wood_yield"
const STAT_STONE_YIELD := &"stone_yield"
const STAT_ORE_YIELD := &"ore_yield"
const STAT_FIBER_YIELD := &"fiber_yield"
const STAT_HIDE_YIELD := &"hide_yield"

const TRAIT_HARDY_BLOOD := &"hardy_blood"
const TRAIT_FAST_HANDS := &"fast_hands"
const TRAIT_STRONG_ARM := &"strong_arm"
const TRAIT_STEADY_BREATH := &"steady_breath"
const TRAIT_SURE_FOOTING := &"sure_footing"
const TRAIT_THICK_HIDE := &"thick_hide"
const TRAIT_EMBER_WARD := &"ember_ward"
const TRAIT_PACK_MULE := &"pack_mule"
const TRAIT_WOODCUTTERS_PACT := &"woodcutters_pact"
const TRAIT_STONE_SENSE := &"stone_sense"
const TRAIT_ORE_WHISPER := &"ore_whisper"
const TRAIT_FIBER_GRACE := &"fiber_grace"
const TRAIT_SKINNERS_PATIENCE := &"skinners_patience"

const TRAIT_ORDER: Array[StringName] = [
	TRAIT_HARDY_BLOOD,
	TRAIT_FAST_HANDS,
	TRAIT_STRONG_ARM,
	TRAIT_STEADY_BREATH,
	TRAIT_SURE_FOOTING,
	TRAIT_THICK_HIDE,
	TRAIT_EMBER_WARD,
	TRAIT_PACK_MULE,
	TRAIT_WOODCUTTERS_PACT,
	TRAIT_STONE_SENSE,
	TRAIT_ORE_WHISPER,
	TRAIT_FIBER_GRACE,
	TRAIT_SKINNERS_PATIENCE,
]

const ACTIVE_SLOT_TIERS := [
	{"level": 1, "slots": 1},
	{"level": 3, "slots": 2},
	{"level": 5, "slots": 3},
	{"level": 10, "slots": 4},
	{"level": 15, "slots": 5},
	{"level": 20, "slots": 6},
	{"level": 30, "slots": 7},
	{"level": 40, "slots": 8},
]

const TRAIT_DEFINITIONS := {
	TRAIT_HARDY_BLOOD: {
		"id": TRAIT_HARDY_BLOOD,
		"display_name": "Hardy Blood",
		"description": "A body tempered by harsh roads and worse weather.",
		"unlock_level": 1,
		"max_rank": 10,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_MAX_HEALTH: 24.0},
		"tags": [&"survival", &"body"],
		"entities": [ENTITY_PLAYER, ENTITY_MOB, ENTITY_CREATURE, ENTITY_NPC],
	},
	TRAIT_FAST_HANDS: {
		"id": TRAIT_FAST_HANDS,
		"display_name": "Fast Hands",
		"description": "Quicker hands for basic weapon work and frantic survival.",
		"unlock_level": 1,
		"max_rank": 5,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_AUTO_ATTACK_SPEED: 0.1},
		"tags": [&"combat", &"dexterity"],
		"entities": [ENTITY_PLAYER, ENTITY_MOB, ENTITY_CREATURE, ENTITY_NPC],
	},
	TRAIT_STRONG_ARM: {
		"id": TRAIT_STRONG_ARM,
		"display_name": "Strong Arm",
		"description": "Practical strength that makes every plain strike hurt more.",
		"unlock_level": 1,
		"max_rank": 10,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_AUTO_ATTACK_DAMAGE: 2.0},
		"tags": [&"combat", &"strength"],
		"entities": [ENTITY_PLAYER, ENTITY_MOB, ENTITY_CREATURE, ENTITY_NPC],
	},
	TRAIT_STEADY_BREATH: {
		"id": TRAIT_STEADY_BREATH,
		"display_name": "Steady Breath",
		"description": "A calmer inner rhythm that leaves more energy for action.",
		"unlock_level": 3,
		"max_rank": 10,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_MAX_ENERGY: 10.0},
		"tags": [&"spirit", &"endurance"],
		"entities": [ENTITY_PLAYER, ENTITY_MOB, ENTITY_CREATURE, ENTITY_NPC],
	},
	TRAIT_SURE_FOOTING: {
		"id": TRAIT_SURE_FOOTING,
		"display_name": "Sure Footing",
		"description": "A steady gait on mud, roots, stone, and blood-slick ground.",
		"unlock_level": 3,
		"max_rank": 5,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_MOVE_SPEED: 0.05},
		"tags": [&"movement", &"body"],
		"entities": [ENTITY_PLAYER, ENTITY_MOB, ENTITY_CREATURE, ENTITY_NPC],
	},
	TRAIT_THICK_HIDE: {
		"id": TRAIT_THICK_HIDE,
		"display_name": "Thick Hide",
		"description": "Scar tissue, discipline, and stubbornness made useful.",
		"unlock_level": 5,
		"max_rank": 10,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_ARMOR: 3.0},
		"tags": [&"defense", &"body"],
		"entities": [ENTITY_PLAYER, ENTITY_MOB, ENTITY_CREATURE, ENTITY_NPC],
	},
	TRAIT_EMBER_WARD: {
		"id": TRAIT_EMBER_WARD,
		"display_name": "Ember Ward",
		"description": "A small warding spark against hexes, heat, and raw magic.",
		"unlock_level": 5,
		"max_rank": 10,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_MAGICAL_RESISTANCE: 2.0},
		"tags": [&"defense", &"spirit"],
		"entities": [ENTITY_PLAYER, ENTITY_MOB, ENTITY_CREATURE, ENTITY_NPC],
	},
	TRAIT_PACK_MULE: {
		"id": TRAIT_PACK_MULE,
		"display_name": "Pack Mule",
		"description": "Shoulders and habits built for bringing more home.",
		"unlock_level": 5,
		"max_rank": 10,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_MAX_LOAD: 5.0},
		"tags": [&"utility", &"labor"],
		"entities": [ENTITY_PLAYER, ENTITY_NPC],
	},
	TRAIT_WOODCUTTERS_PACT: {
		"id": TRAIT_WOODCUTTERS_PACT,
		"display_name": "Woodcutter's Pact",
		"description": "A careful rhythm learned from Silverneedle groves.",
		"unlock_level": 10,
		"max_rank": 5,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_WOOD_YIELD: 0.01},
		"tags": [&"gathering", &"wood"],
		"entities": [ENTITY_PLAYER, ENTITY_NPC],
	},
	TRAIT_STONE_SENSE: {
		"id": TRAIT_STONE_SENSE,
		"display_name": "Stone Sense",
		"description": "A miner's feel for Moonchalk cracks and hidden seams.",
		"unlock_level": 10,
		"max_rank": 5,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_STONE_YIELD: 0.01},
		"tags": [&"gathering", &"stone"],
		"entities": [ENTITY_PLAYER, ENTITY_NPC],
	},
	TRAIT_ORE_WHISPER: {
		"id": TRAIT_ORE_WHISPER,
		"display_name": "Ore Whisper",
		"description": "A patient ear for Hearthsteel buried under common rock.",
		"unlock_level": 10,
		"max_rank": 5,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_ORE_YIELD: 0.01},
		"tags": [&"gathering", &"ore"],
		"entities": [ENTITY_PLAYER, ENTITY_NPC],
	},
	TRAIT_FIBER_GRACE: {
		"id": TRAIT_FIBER_GRACE,
		"display_name": "Fiber Grace",
		"description": "A light touch that keeps useful fibers from tearing.",
		"unlock_level": 10,
		"max_rank": 5,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_FIBER_YIELD: 0.01},
		"tags": [&"gathering", &"fiber"],
		"entities": [ENTITY_PLAYER, ENTITY_NPC],
	},
	TRAIT_SKINNERS_PATIENCE: {
		"id": TRAIT_SKINNERS_PATIENCE,
		"display_name": "Skinner's Patience",
		"description": "Clean knife work that preserves more hide from a kill.",
		"unlock_level": 10,
		"max_rank": 5,
		"point_cost": 1,
		"modifiers_per_rank": {STAT_HIDE_YIELD: 0.01},
		"tags": [&"gathering", &"hide"],
		"entities": [ENTITY_PLAYER, ENTITY_NPC],
	},
}


static func get_trait_ids() -> Array[StringName]:
	return TRAIT_ORDER.duplicate()


static func get_definitions_in_order() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for trait_id in TRAIT_ORDER:
		definitions.append(get_definition(trait_id))
	return definitions


static func has_trait(trait_id: StringName) -> bool:
	return TRAIT_DEFINITIONS.has(StringName(String(trait_id)))


static func get_definition(trait_id: StringName) -> Dictionary:
	var clean_id := StringName(String(trait_id))
	if not TRAIT_DEFINITIONS.has(clean_id):
		return {}

	return (TRAIT_DEFINITIONS[clean_id] as Dictionary).duplicate(true)


static func get_display_name(trait_id: StringName) -> String:
	var definition := get_definition(trait_id)
	if definition.is_empty():
		return String(trait_id)

	return String(definition.get("display_name", trait_id))


static func active_slot_limit_for_level(level: int) -> int:
	var clean_level := maxi(level, 1)
	var slots := 0
	for tier in ACTIVE_SLOT_TIERS:
		if clean_level >= int(tier.get("level", 1)):
			slots = int(tier.get("slots", slots))

	return slots


static func xp_required_for_level(level: int) -> int:
	var clean_level := maxi(level, 1)
	return 100 + clean_level * 75 + int(pow(float(clean_level), 1.45) * 50.0)


static func trait_allowed_for_entity(trait_id: StringName, entity_type: StringName) -> bool:
	var definition := get_definition(trait_id)
	if definition.is_empty():
		return false

	var allowed_entities: Array = definition.get("entities", [])
	return allowed_entities.has(StringName(String(entity_type)))


static func trait_unlock_level(trait_id: StringName) -> int:
	var definition := get_definition(trait_id)
	if definition.is_empty():
		return 999999

	return int(definition.get("unlock_level", 1))


static func trait_max_rank(trait_id: StringName) -> int:
	var definition := get_definition(trait_id)
	if definition.is_empty():
		return 0

	return maxi(int(definition.get("max_rank", 1)), 0)


static func trait_point_cost(trait_id: StringName) -> int:
	var definition := get_definition(trait_id)
	if definition.is_empty():
		return 0

	return maxi(int(definition.get("point_cost", 1)), 0)


static func modifiers_for_trait_rank(trait_id: StringName, rank: int) -> Dictionary:
	var definition := get_definition(trait_id)
	if definition.is_empty():
		return {}

	var clean_rank := clampi(rank, 0, trait_max_rank(trait_id))
	if clean_rank <= 0:
		return {}

	var output := {}
	var modifiers: Dictionary = definition.get("modifiers_per_rank", {})
	for raw_stat_id in modifiers.keys():
		var stat_id := StringName(String(raw_stat_id))
		output[stat_id] = float(modifiers[raw_stat_id]) * clean_rank

	return output


static func trait_has_any_tag(trait_id: StringName, desired_tags: Array) -> bool:
	var definition := get_definition(trait_id)
	if definition.is_empty():
		return false

	var tags: Array = definition.get("tags", [])
	for raw_tag in desired_tags:
		if tags.has(StringName(String(raw_tag))):
			return true

	return false
