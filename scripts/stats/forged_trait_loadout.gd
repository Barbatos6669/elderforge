## Purchases and active-slot state for Forged Traits.
##
## Buying a trait rank spends ability stat points. Activating a purchased trait
## chooses whether that rank contributes modifiers right now. The active-slot
## limit is level based, which gives us a clean progression throttle for players
## and a shared budget system for mobs and creatures.
class_name ForgedTraitLoadout
extends Node

signal traits_changed
signal level_changed(level: int)
signal xp_changed(current_xp: int, total_xp: int, xp_to_next_level: int)
signal trait_points_changed(unspent_points: int)

@export var entity_type: StringName = ForgedTraitCatalog.ENTITY_PLAYER
@export_range(1, 100, 1) var character_level := 1
@export_range(0, 999999999, 1) var current_xp := 0
@export_range(0, 999999999, 1) var total_xp := 0
@export_range(0, 9999, 1) var unspent_trait_points := 0
@export_range(0, 20, 1) var trait_points_per_level := 1

## Saves/restores progression for signed-in player accounts. Disable on mobs.
@export var persist_to_player_database := true
## Optional explicit account key for test scenes; blank means use PrototypeAuthSession.
@export var persistence_account_name := ""

var _purchased_traits: Dictionary = {}
var _active_traits: Array[StringName] = []
var _is_applying_persisted_progression := false


func _ready() -> void:
	add_to_group("forged_trait_loadouts")
	_load_from_player_database()
	_emit_progression_signals(false)


func get_character_level() -> int:
	return character_level


func get_current_xp() -> int:
	return current_xp


func get_total_xp() -> int:
	return total_xp


func get_xp_to_next_level() -> int:
	return ForgedTraitCatalog.xp_required_for_level(character_level)


func get_unspent_trait_points() -> int:
	return unspent_trait_points


func get_active_slot_limit() -> int:
	return ForgedTraitCatalog.active_slot_limit_for_level(character_level)


func get_open_active_slots() -> int:
	return max(0, get_active_slot_limit() - _active_traits.size())


func get_purchased_traits() -> Dictionary:
	return _purchased_traits.duplicate()


func get_active_traits() -> Array[StringName]:
	return _active_traits.duplicate()


func get_trait_rank(trait_id: StringName) -> int:
	return int(_purchased_traits.get(StringName(String(trait_id)), 0))


func is_trait_purchased(trait_id: StringName) -> bool:
	return get_trait_rank(trait_id) > 0


func is_trait_active(trait_id: StringName) -> bool:
	return _active_traits.has(StringName(String(trait_id)))


func can_purchase_trait(trait_id: StringName, ranks: int = 1) -> bool:
	var clean_id := StringName(String(trait_id))
	var clean_ranks := maxi(ranks, 1)
	if not _can_use_trait(clean_id):
		return false
	if character_level < ForgedTraitCatalog.trait_unlock_level(clean_id):
		return false

	var current_rank := get_trait_rank(clean_id)
	var max_rank := ForgedTraitCatalog.trait_max_rank(clean_id)
	if current_rank + clean_ranks > max_rank:
		return false

	var total_cost := ForgedTraitCatalog.trait_point_cost(clean_id) * clean_ranks
	return unspent_trait_points >= total_cost


func purchase_trait(trait_id: StringName, ranks: int = 1) -> bool:
	if not can_purchase_trait(trait_id, ranks):
		return false

	var clean_id := StringName(String(trait_id))
	var clean_ranks := maxi(ranks, 1)
	var total_cost := ForgedTraitCatalog.trait_point_cost(clean_id) * clean_ranks
	_purchased_traits[clean_id] = get_trait_rank(clean_id) + clean_ranks
	unspent_trait_points = max(0, unspent_trait_points - total_cost)
	trait_points_changed.emit(unspent_trait_points)
	_emit_trait_change()
	return true


func can_activate_trait(trait_id: StringName) -> bool:
	var clean_id := StringName(String(trait_id))
	if is_trait_active(clean_id):
		return true
	if not is_trait_purchased(clean_id):
		return false
	if not _can_use_trait(clean_id):
		return false
	if character_level < ForgedTraitCatalog.trait_unlock_level(clean_id):
		return false

	return _active_traits.size() < get_active_slot_limit()


func activate_trait(trait_id: StringName) -> bool:
	if not can_activate_trait(trait_id):
		return false

	var clean_id := StringName(String(trait_id))
	if _active_traits.has(clean_id):
		return true

	_active_traits.append(clean_id)
	_emit_trait_change()
	return true


func deactivate_trait(trait_id: StringName) -> bool:
	var clean_id := StringName(String(trait_id))
	if not _active_traits.has(clean_id):
		return false

	_active_traits.erase(clean_id)
	_emit_trait_change()
	return true


func clear_active_traits() -> void:
	if _active_traits.is_empty():
		return

	_active_traits.clear()
	_emit_trait_change()


func set_character_level(value: int) -> void:
	var clean_level := maxi(value, 1)
	if character_level == clean_level:
		return

	character_level = clean_level
	_trim_active_traits_to_slot_limit()
	_emit_progression_signals()


func grant_trait_points(amount: int) -> void:
	var clean_amount := maxi(amount, 0)
	if clean_amount <= 0:
		return

	unspent_trait_points += clean_amount
	trait_points_changed.emit(unspent_trait_points)
	_save_to_player_database()


func add_xp(amount: int) -> void:
	var clean_amount := maxi(amount, 0)
	if clean_amount <= 0:
		return

	total_xp += clean_amount
	current_xp += clean_amount
	var leveled := false
	while current_xp >= get_xp_to_next_level():
		current_xp -= get_xp_to_next_level()
		character_level += 1
		unspent_trait_points += trait_points_per_level
		leveled = true

	if leveled:
		_trim_active_traits_to_slot_limit()
	_emit_progression_signals()


func get_active_stat_modifiers() -> Dictionary:
	var output := {}
	for trait_id in _active_traits:
		var rank := get_trait_rank(trait_id)
		var modifiers := ForgedTraitCatalog.modifiers_for_trait_rank(trait_id, rank)
		for stat_id in modifiers.keys():
			var clean_stat_id := StringName(String(stat_id))
			output[clean_stat_id] = float(output.get(clean_stat_id, 0.0)) + float(modifiers[stat_id])

	return output


func get_progression_snapshot() -> Dictionary:
	var purchased := {}
	for trait_id in _purchased_traits.keys():
		var clean_id := StringName(String(trait_id))
		purchased[String(clean_id)] = int(_purchased_traits[trait_id])

	var active: Array[String] = []
	for trait_id in _active_traits:
		active.append(String(trait_id))

	return {
		"character_level": character_level,
		"current_xp": current_xp,
		"total_xp": total_xp,
		"unspent_trait_points": unspent_trait_points,
		"purchased_traits": purchased,
		"active_traits": active,
	}


func apply_progression_snapshot(snapshot: Dictionary) -> void:
	_is_applying_persisted_progression = true
	character_level = maxi(int(snapshot.get("character_level", character_level)), 1)
	current_xp = maxi(int(snapshot.get("current_xp", current_xp)), 0)
	total_xp = maxi(int(snapshot.get("total_xp", total_xp)), 0)
	unspent_trait_points = maxi(int(snapshot.get("unspent_trait_points", unspent_trait_points)), 0)

	_purchased_traits.clear()
	var purchased: Dictionary = snapshot.get("purchased_traits", {})
	for raw_trait_id in purchased.keys():
		var trait_id := StringName(String(raw_trait_id))
		if not _can_use_trait(trait_id):
			continue
		var rank := clampi(int(purchased[raw_trait_id]), 0, ForgedTraitCatalog.trait_max_rank(trait_id))
		if rank > 0:
			_purchased_traits[trait_id] = rank

	_active_traits.clear()
	var active: Array = snapshot.get("active_traits", [])
	for raw_trait_id in active:
		var trait_id := StringName(String(raw_trait_id))
		if _active_traits.size() >= get_active_slot_limit():
			break
		if not is_trait_purchased(trait_id):
			continue
		if not _can_use_trait(trait_id):
			continue
		if not _active_traits.has(trait_id):
			_active_traits.append(trait_id)

	_is_applying_persisted_progression = false
	_emit_progression_signals(false)


func _can_use_trait(trait_id: StringName) -> bool:
	return (
		ForgedTraitCatalog.has_trait(trait_id)
		and ForgedTraitCatalog.trait_allowed_for_entity(trait_id, entity_type)
	)


func _trim_active_traits_to_slot_limit() -> void:
	var slot_limit := get_active_slot_limit()
	while _active_traits.size() > slot_limit:
		_active_traits.pop_back()


func _emit_trait_change() -> void:
	traits_changed.emit()
	_save_to_player_database()


func _emit_progression_signals(should_save := true) -> void:
	level_changed.emit(character_level)
	xp_changed.emit(current_xp, total_xp, get_xp_to_next_level())
	trait_points_changed.emit(unspent_trait_points)
	traits_changed.emit()
	if should_save:
		_save_to_player_database()


func _load_from_player_database() -> void:
	if not persist_to_player_database:
		return

	var database := _player_database()
	if database == null or not database.has_method("has_player_progression") or not database.has_method("get_player_progression"):
		return

	var account_key := _persistence_account_key(database)
	if account_key.is_empty() or not bool(database.call("has_player_progression", account_key)):
		return

	var progression: Variant = database.call("get_player_progression", account_key)
	if progression is Dictionary:
		apply_progression_snapshot(progression as Dictionary)


func _save_to_player_database() -> void:
	if not persist_to_player_database or _is_applying_persisted_progression:
		return

	var database := _player_database()
	if database == null or not database.has_method("set_player_progression"):
		return

	var account_key := _persistence_account_key(database)
	if account_key.is_empty():
		return

	database.call("set_player_progression", account_key, get_progression_snapshot())


func _persistence_account_key(database: Node) -> String:
	var raw_account_name := persistence_account_name.strip_edges()
	if raw_account_name.is_empty():
		var auth_session := get_node_or_null("/root/PrototypeAuthSession")
		if auth_session != null and bool(auth_session.get("is_signed_in")):
			raw_account_name = String(auth_session.get("account_name")).strip_edges()

	if raw_account_name.is_empty() or raw_account_name == "guest":
		return ""

	if database != null and database.has_method("normalize_account_name"):
		return String(database.call("normalize_account_name", raw_account_name))

	return raw_account_name.to_lower()


func _player_database() -> Node:
	if not is_inside_tree():
		return null

	return get_node_or_null("/root/PlayerDatabase")
