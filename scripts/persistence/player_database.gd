## File-backed player database for the current playtest server.
##
## This is the first persistence boundary for Elderforge. Gameplay code should
## talk to this node instead of opening random save files. The backend is JSON
## today so the Godot server can run anywhere without credentials; the public
## method shape is intentionally close to what a SQLite/Postgres service can
## expose later.
extends Node

const JsonPlayerDatabaseBackendScript := preload("res://scripts/persistence/json_player_database_backend.gd")
const SQLitePlayerDatabaseBackendScript := preload("res://scripts/persistence/sqlite_player_database_backend.gd")

const DATABASE_PATH := "user://player_database.json"
const SQLITE_DATABASE_PATH := "user://elderforge_players.sqlite3"
const MIGRATIONS_PATH := "res://data/migrations"
const SCHEMA_VERSION := 4
const DEFAULT_WORLD_ID := "main"
const DEFAULT_ZONE_ID := "starting_city"
const MAX_ACCOUNT_NAME_LENGTH := 48
const MAX_DISPLAY_NAME_LENGTH := 32
const MAX_CHARACTERS_PER_ACCOUNT := 3
const MAX_INVENTORY_SLOTS := 42
const MAX_STACK_QUANTITY := 999
const MAX_CURRENCY := 999999999
const MAX_TRANSACTION_HISTORY := 500
const MAX_ITEM_ID_LENGTH := 96
const MAX_ABILITY_SLOT_ID_LENGTH := 8
const MAX_RESOURCE_PATH_LENGTH := 384

## Active storage backend. JSON is the safe default until a SQLite addon exists.
@export_enum("json", "sqlite") var storage_backend_id := "json"
## JSON database path used by the current playtest backend.
@export var json_database_path := DATABASE_PATH
## Future SQLite database path. This is dormant until the SQLite backend is wired.
@export var sqlite_database_path := SQLITE_DATABASE_PATH
## SQL migration folder used by the future SQLite backend.
@export var sqlite_migrations_path := MIGRATIONS_PATH

var _database := {}
var _loaded := false
var _backend: RefCounted


func _ready() -> void:
	_load_database()


## Returns which persistence backend is active and whether it is healthy.
func get_backend_status() -> Dictionary:
	_ensure_backend()
	if _backend != null and _backend.has_method("get_status"):
		var status: Variant = _backend.call("get_status")
		if status is Dictionary:
			return status as Dictionary

	return {
		"backend": "none",
		"available": false,
		"path": "",
		"last_error": "No persistence backend is configured.",
	}


## Returns true when a player record exists for the normalized account name.
func has_player(account_name: String) -> bool:
	var key := normalize_account_name(account_name)
	return not key.is_empty() and _players().has(key)


## Creates a player record if one does not already exist.
func create_player(
	account_name: String,
	display_name: String = "",
	password_hash: String = "",
	appearance: Dictionary = {}
) -> Dictionary:
	var key := normalize_account_name(account_name)
	if key.is_empty():
		return _failure("Missing account name.")
	if has_player(key):
		return _failure("Player already exists.")

	var now := _now_unix()
	var players := _players()
	var clean_display_name := display_name.strip_edges()
	var characters := []
	var active_character_id := ""
	var mirrored_display_name := ""
	var mirrored_appearance := {}
	if not clean_display_name.is_empty():
		var first_character := _make_character_record(key, clean_display_name, appearance, 1, now)
		characters.append(first_character)
		active_character_id = String(first_character.get("character_id", ""))
		mirrored_display_name = String(first_character.get("display_name", clean_display_name))
		mirrored_appearance = _dictionary_copy(first_character.get("appearance", appearance))

	players[key] = {
		"account_name": key,
		"account_id": key,
		"character_id": active_character_id,
		"active_character_id": active_character_id,
		"next_character_slot": characters.size() + 1,
		"join_order": _claim_next_join_order(),
		"world_id": DEFAULT_WORLD_ID,
		"zone_id": DEFAULT_ZONE_ID,
		"display_name": mirrored_display_name,
		"password_hash": password_hash.strip_edges(),
		"appearance": mirrored_appearance,
		"characters": characters,
		"inventory": {},
		"stats": {},
		"progression": {},
		"item_transactions": [],
		"last_position": {},
		"created_at_unix": now,
		"updated_at_unix": now,
	}
	_save_database()
	return _success("Player created.", get_player(key))


## Creates or touches the server-side record for a signed-in playtest account.
func get_or_create_player(
	account_name: String,
	display_name: String,
	appearance: Dictionary = {}
) -> Dictionary:
	var key := normalize_account_name(account_name)
	if key.is_empty():
		return {}

	if not has_player(key):
		create_player(key, "", "", {})

	var clean_display_name := display_name.strip_edges()
	if not clean_display_name.is_empty():
		var matching_character := _find_character_by_display_name(key, clean_display_name)
		if not matching_character.is_empty():
			set_active_character(key, String(matching_character.get("character_id", "")))
			if not appearance.is_empty():
				set_player_appearance(key, appearance)
		elif get_player_characters(key).size() < MAX_CHARACTERS_PER_ACCOUNT:
			create_character(key, clean_display_name, appearance)
		elif get_active_character(key).is_empty():
			var characters := get_player_characters(key)
			if not characters.is_empty():
				set_active_character(key, String((characters[0] as Dictionary).get("character_id", "")))

	if has_player(key):
		return get_player(key)

	return {}


## Returns a deep copy of one player record, excluding nothing.
##
## This is still prototype-local data. Production auth should never expose
## password hashes outside an authentication service.
func get_player(account_name: String) -> Dictionary:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return {}

	var record: Dictionary = _players()[key]
	return record.duplicate(true)


func create_character(account_name: String, display_name: String, appearance: Dictionary = {}) -> Dictionary:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return _failure("Account not found.")

	var clean_display_name := sanitize_display_name(display_name, "")
	if clean_display_name.is_empty():
		return _failure("Enter a character name.")

	var players := _players()
	var record: Dictionary = players[key]
	var characters := _character_array_copy(record.get("characters", []))
	if characters.size() >= MAX_CHARACTERS_PER_ACCOUNT:
		return _failure("This account already has three characters.")

	var now := _now_unix()
	var slot_number := maxi(int(record.get("next_character_slot", characters.size() + 1)), characters.size() + 1)
	var character_record := _make_character_record(key, clean_display_name, appearance, slot_number, now)
	characters.append(character_record)
	record["characters"] = characters
	record["next_character_slot"] = slot_number + 1
	_apply_active_character_to_record(record, character_record)
	record["updated_at_unix"] = now
	players[key] = record
	_save_database()
	return _success("Character created.", get_player(key))


func get_player_characters(account_name: String) -> Array:
	var record := get_player(account_name)
	if record.is_empty():
		return []

	return _character_array_copy(record.get("characters", []))


func get_active_character(account_name: String) -> Dictionary:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return {}

	var record: Dictionary = _players()[key]
	return _active_character_from_record(record)


func set_active_character(account_name: String, character_id: String) -> bool:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return false

	var clean_character_id := character_id.strip_edges()
	if clean_character_id.is_empty():
		return false

	var players := _players()
	var record: Dictionary = players[key]
	var characters := _character_array_copy(record.get("characters", []))
	for character in characters:
		if String(character.get("character_id", "")) != clean_character_id:
			continue

		record["characters"] = characters
		_apply_active_character_to_record(record, character)
		record["updated_at_unix"] = _now_unix()
		players[key] = record
		_save_database()
		return true

	return false


## Returns a legacy-compatible map for auth migration and simple tools.
func get_account_map() -> Dictionary:
	var accounts := {}
	for key in _players().keys():
		var record: Dictionary = _players()[key]
		accounts[key] = {
			"display_name": String(record.get("display_name", key)),
			"password_hash": String(record.get("password_hash", "")),
			"appearance": _dictionary_copy(record.get("appearance", {})),
			"join_order": int(record.get("join_order", 0)),
			"characters": _character_array_copy(record.get("characters", [])),
			"active_character_id": String(record.get("active_character_id", "")),
		}
	return accounts


## Updates display name or appearance without touching inventory/stat data.
func touch_player(account_name: String, display_name: String = "", appearance: Dictionary = {}) -> bool:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return false

	var record: Dictionary = _players()[key]
	if not display_name.strip_edges().is_empty():
		record["display_name"] = sanitize_display_name(display_name, key)
	if not appearance.is_empty():
		record["appearance"] = appearance.duplicate(true)
	var active_character := _active_character_from_record(record)
	if not active_character.is_empty():
		if not display_name.strip_edges().is_empty():
			active_character["display_name"] = sanitize_display_name(display_name, key)
		if not appearance.is_empty():
			active_character["appearance"] = appearance.duplicate(true)
		_replace_character_in_record(record, active_character)
		_apply_active_character_to_record(record, active_character)
	record["updated_at_unix"] = _now_unix()
	_players()[key] = record
	_save_database()
	return true


func set_player_appearance(account_name: String, appearance: Dictionary) -> bool:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return false

	var record: Dictionary = _players()[key]
	record["appearance"] = appearance.duplicate(true)
	var active_character := _active_character_from_record(record)
	if not active_character.is_empty():
		active_character["appearance"] = appearance.duplicate(true)
		_replace_character_in_record(record, active_character)
		_apply_active_character_to_record(record, active_character)
	record["updated_at_unix"] = _now_unix()
	_players()[key] = record
	_save_database()
	return true


func get_player_appearance(account_name: String) -> Dictionary:
	var active_character := get_active_character(account_name)
	if not active_character.is_empty():
		return _dictionary_copy(active_character.get("appearance", {}))

	var record := get_player(account_name)
	return _dictionary_copy(record.get("appearance", {}))


func set_player_inventory(account_name: String, inventory_snapshot: Dictionary) -> bool:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return false

	var record: Dictionary = _players()[key]
	record["inventory"] = sanitize_inventory_snapshot(inventory_snapshot)
	record["updated_at_unix"] = _now_unix()
	_players()[key] = record
	_save_database()
	return true


func get_player_inventory(account_name: String) -> Dictionary:
	var record := get_player(account_name)
	return sanitize_inventory_snapshot(record.get("inventory", {}))


func has_player_inventory(account_name: String) -> bool:
	var record := get_player(account_name)
	if record.is_empty():
		return false

	var inventory: Variant = record.get("inventory", {})
	return inventory is Dictionary and not (inventory as Dictionary).is_empty()


func set_player_stats(account_name: String, stats: Dictionary) -> bool:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return false

	var clean_stats := {}
	for stat_id in stats.keys():
		var clean_id := String(stat_id).strip_edges()
		if clean_id.is_empty():
			continue
		clean_stats[clean_id] = float(stats[stat_id])

	var record: Dictionary = _players()[key]
	record["stats"] = clean_stats
	record["updated_at_unix"] = _now_unix()
	_players()[key] = record
	_save_database()
	return true


func get_player_stats(account_name: String) -> Dictionary:
	var record := get_player(account_name)
	return _dictionary_copy(record.get("stats", {}))


func has_player_stats(account_name: String) -> bool:
	var record := get_player(account_name)
	if record.is_empty():
		return false

	var stats: Variant = record.get("stats", {})
	return stats is Dictionary and not (stats as Dictionary).is_empty()


func set_player_progression(account_name: String, progression_snapshot: Dictionary) -> bool:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return false

	var record: Dictionary = _players()[key]
	record["progression"] = sanitize_progression_snapshot(progression_snapshot)
	record["updated_at_unix"] = _now_unix()
	_players()[key] = record
	_save_database()
	return true


func get_player_progression(account_name: String) -> Dictionary:
	var record := get_player(account_name)
	return sanitize_progression_snapshot(record.get("progression", {}))


func has_player_progression(account_name: String) -> bool:
	var record := get_player(account_name)
	if record.is_empty():
		return false

	var progression: Variant = record.get("progression", {})
	return progression is Dictionary and not (progression as Dictionary).is_empty()


func record_item_transaction(
	account_name: String,
	transaction_type: String,
	item_id: String,
	quantity_delta: int,
	context: Dictionary = {}
) -> bool:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return false

	var clean_type := transaction_type.strip_edges().to_lower()
	var clean_item_id := item_id.strip_edges()
	if clean_type.is_empty() or clean_item_id.is_empty() or quantity_delta == 0:
		return false

	var record: Dictionary = _players()[key]
	var transactions := _array_copy(record.get("item_transactions", []))
	transactions.append({
		"transaction_id": "%s_%d_%d" % [key, _now_unix(), transactions.size()],
		"transaction_type": clean_type,
		"item_id": clean_item_id,
		"quantity_delta": quantity_delta,
		"context": context.duplicate(true),
		"created_at_unix": _now_unix(),
	})
	if transactions.size() > MAX_TRANSACTION_HISTORY:
		transactions = transactions.slice(transactions.size() - MAX_TRANSACTION_HISTORY)

	record["item_transactions"] = transactions
	record["updated_at_unix"] = _now_unix()
	_players()[key] = record
	_save_database()
	return true


func get_recent_item_transactions(account_name: String, limit: int = 50) -> Array:
	var record := get_player(account_name)
	if record.is_empty():
		return []

	var transactions := _array_copy(record.get("item_transactions", []))
	var clean_limit := clampi(limit, 1, MAX_TRANSACTION_HISTORY)
	if transactions.size() <= clean_limit:
		return transactions

	return transactions.slice(transactions.size() - clean_limit)


func set_player_position(
	account_name: String,
	position: Vector3,
	world_id: String = DEFAULT_WORLD_ID,
	zone_id: String = DEFAULT_ZONE_ID
) -> bool:
	var key := normalize_account_name(account_name)
	if key.is_empty() or not _players().has(key):
		return false

	var clean_world_id := _sanitize_storage_id(world_id, DEFAULT_WORLD_ID)
	var clean_zone_id := _sanitize_storage_id(zone_id, DEFAULT_ZONE_ID)
	var record: Dictionary = _players()[key]
	record["world_id"] = clean_world_id
	record["zone_id"] = clean_zone_id
	record["last_position"] = {
		"world_id": clean_world_id,
		"zone_id": clean_zone_id,
		"x": position.x,
		"y": position.y,
		"z": position.z,
	}
	record["updated_at_unix"] = _now_unix()
	_players()[key] = record
	_save_database()
	return true


func get_player_position(account_name: String) -> Dictionary:
	var record := get_player(account_name)
	return _dictionary_copy(record.get("last_position", {}))


func normalize_account_name(account_name: String) -> String:
	var normalized := account_name.strip_edges().to_lower()
	var output := ""
	for index in range(normalized.length()):
		var character := normalized.substr(index, 1)
		if character.is_valid_identifier() or character.is_valid_int() or character in ["-", "_", "."]:
			output += character
		if output.length() >= MAX_ACCOUNT_NAME_LENGTH:
			break
	return output


func sanitize_display_name(display_name: String, fallback: String = "Player") -> String:
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty():
		clean_name = fallback.strip_edges()
	if clean_name.is_empty():
		clean_name = "Player"
	return clean_name.substr(0, MAX_DISPLAY_NAME_LENGTH)


func sanitize_inventory_snapshot(snapshot: Variant) -> Dictionary:
	if not (snapshot is Dictionary):
		return _empty_inventory_snapshot()

	var data := snapshot as Dictionary
	var slot_count := clampi(int(data.get("slot_count", MAX_INVENTORY_SLOTS)), 1, MAX_INVENTORY_SLOTS)
	var slots := []
	var raw_slots: Variant = data.get("slots", [])
	if raw_slots is Array:
		var raw_slot_array := raw_slots as Array
		for raw_slot in raw_slot_array:
			if slots.size() >= slot_count:
				break
			slots.append(_sanitize_stack(raw_slot))

	while slots.size() < slot_count:
		slots.append({})

	var equipped_slots := {}
	var raw_equipped: Variant = data.get("equipped_slots", {})
	if raw_equipped is Dictionary:
		var equipped_data := raw_equipped as Dictionary
		for slot_id in equipped_data.keys():
			var clean_slot_id := String(slot_id).strip_edges()
			var stack := _sanitize_stack(equipped_data[slot_id])
			if clean_slot_id.is_empty() or stack.is_empty():
				continue
			equipped_slots[clean_slot_id] = stack

	var ability_selections := {}
	var raw_selections: Variant = data.get("ability_selections", {})
	if raw_selections is Dictionary:
		for raw_item_id in (raw_selections as Dictionary).keys():
			var item_id := String(raw_item_id).strip_edges().substr(0, MAX_ITEM_ID_LENGTH)
			var raw_item_selections: Variant = (raw_selections as Dictionary)[raw_item_id]
			if item_id.is_empty() or not (raw_item_selections is Dictionary):
				continue

			var item_selections := {}
			for raw_slot_id in (raw_item_selections as Dictionary).keys():
				var slot_id := String(raw_slot_id).strip_edges().to_lower().substr(
					0,
					MAX_ABILITY_SLOT_ID_LENGTH
				)
				var ability_path := String(
					(raw_item_selections as Dictionary)[raw_slot_id]
				).strip_edges().substr(0, MAX_RESOURCE_PATH_LENGTH)
				if (
					slot_id.is_empty()
					or not ability_path.begins_with("res://")
					or not ability_path.ends_with(".tres")
				):
					continue
				item_selections[slot_id] = ability_path
			if not item_selections.is_empty():
				ability_selections[item_id] = item_selections

	return {
		"slot_count": slot_count,
		"silver": clampi(int(data.get("silver", 0)), 0, MAX_CURRENCY),
		"gold": clampi(int(data.get("gold", 0)), 0, MAX_CURRENCY),
		"slots": slots,
		"equipped_slots": equipped_slots,
		"ability_selections": ability_selections,
	}


func sanitize_progression_snapshot(snapshot: Variant) -> Dictionary:
	if not (snapshot is Dictionary):
		return _empty_progression_snapshot()

	var data := snapshot as Dictionary
	var purchased_traits := {}
	var raw_purchased: Variant = data.get("purchased_traits", {})
	if raw_purchased is Dictionary:
		for raw_trait_id in (raw_purchased as Dictionary).keys():
			var trait_id := String(raw_trait_id).strip_edges()
			if trait_id.is_empty():
				continue
			var rank := clampi(int((raw_purchased as Dictionary)[raw_trait_id]), 0, 100)
			if rank > 0:
				purchased_traits[trait_id] = rank

	var active_traits: Array[String] = []
	var raw_active: Variant = data.get("active_traits", [])
	if raw_active is Array:
		for raw_trait_id in raw_active:
			var trait_id := String(raw_trait_id).strip_edges()
			if trait_id.is_empty() or active_traits.has(trait_id):
				continue
			active_traits.append(trait_id)

	return {
		"character_level": clampi(int(data.get("character_level", 1)), 1, 100),
		"current_xp": clampi(int(data.get("current_xp", 0)), 0, 999999999),
		"total_xp": clampi(int(data.get("total_xp", 0)), 0, 999999999),
		"unspent_trait_points": clampi(int(data.get("unspent_trait_points", 0)), 0, 9999),
		"purchased_traits": purchased_traits,
		"active_traits": active_traits,
	}


func _sanitize_stack(raw_stack: Variant) -> Dictionary:
	if not (raw_stack is Dictionary):
		return {}

	var stack_data := raw_stack as Dictionary
	var item_id := String(stack_data.get("item_id", "")).strip_edges()
	var quantity := clampi(int(stack_data.get("quantity", 0)), 0, MAX_STACK_QUANTITY)
	if item_id.is_empty() or quantity <= 0:
		return {}

	return {
		"item_id": item_id,
		"quantity": quantity,
	}


func _empty_inventory_snapshot() -> Dictionary:
	var slots := []
	for _index in range(MAX_INVENTORY_SLOTS):
		slots.append({})
	return {
		"slot_count": MAX_INVENTORY_SLOTS,
		"silver": 0,
		"gold": 0,
		"slots": slots,
		"equipped_slots": {},
		"ability_selections": {},
	}


func _empty_progression_snapshot() -> Dictionary:
	return {
		"character_level": 1,
		"current_xp": 0,
		"total_xp": 0,
		"unspent_trait_points": 0,
		"purchased_traits": {},
		"active_traits": [],
	}


func _make_character_record(
	account_key: String,
	display_name: String,
	appearance: Dictionary,
	slot_number: int,
	now_unix: int
) -> Dictionary:
	var clean_slot_number := maxi(slot_number, 1)
	return {
		"character_id": "%s:%s:%d" % [account_key, DEFAULT_WORLD_ID, clean_slot_number],
		"slot_number": clean_slot_number,
		"world_id": DEFAULT_WORLD_ID,
		"zone_id": DEFAULT_ZONE_ID,
		"display_name": sanitize_display_name(display_name, "Player"),
		"appearance": appearance.duplicate(true),
		"created_at_unix": now_unix,
		"updated_at_unix": now_unix,
	}


func _active_character_from_record(record: Dictionary) -> Dictionary:
	var active_character_id := String(record.get("active_character_id", ""))
	var characters := _character_array_copy(record.get("characters", []))
	for character in characters:
		if String(character.get("character_id", "")) == active_character_id:
			return character.duplicate(true)

	return {}


func _find_character_by_display_name(account_name: String, display_name: String) -> Dictionary:
	var clean_name := sanitize_display_name(display_name, "").to_lower()
	if clean_name.is_empty():
		return {}

	for character in get_player_characters(account_name):
		if String(character.get("display_name", "")).strip_edges().to_lower() == clean_name:
			return character.duplicate(true)

	return {}


func _replace_character_in_record(record: Dictionary, character: Dictionary) -> void:
	var character_id := String(character.get("character_id", ""))
	if character_id.is_empty():
		return

	var characters := _character_array_copy(record.get("characters", []))
	for index in range(characters.size()):
		if String((characters[index] as Dictionary).get("character_id", "")) != character_id:
			continue

		characters[index] = character.duplicate(true)
		record["characters"] = characters
		return


func _apply_active_character_to_record(record: Dictionary, character: Dictionary) -> void:
	var character_id := String(character.get("character_id", ""))
	if character_id.is_empty():
		return

	record["active_character_id"] = character_id
	record["character_id"] = character_id
	record["world_id"] = _sanitize_storage_id(String(character.get("world_id", DEFAULT_WORLD_ID)), DEFAULT_WORLD_ID)
	record["zone_id"] = _sanitize_storage_id(String(character.get("zone_id", DEFAULT_ZONE_ID)), DEFAULT_ZONE_ID)
	record["display_name"] = sanitize_display_name(String(character.get("display_name", "")), "Player")
	record["appearance"] = _dictionary_copy(character.get("appearance", {}))


func _character_array_copy(raw_value: Variant) -> Array:
	var output := []
	if not (raw_value is Array):
		return output

	for raw_character in (raw_value as Array):
		if raw_character is Dictionary:
			output.append((raw_character as Dictionary).duplicate(true))
	return output


func _load_database() -> void:
	if _loaded:
		return
	_loaded = true
	_ensure_backend()

	var loaded_database: Variant = _backend.call("load_database", _empty_database()) if _backend != null else _empty_database()
	if loaded_database is Dictionary:
		_database = loaded_database as Dictionary
	else:
		_database = _empty_database()

	_normalize_database_shape()


func _save_database() -> void:
	_load_database()
	_database["schema_version"] = SCHEMA_VERSION
	_ensure_backend()
	if _backend == null or not _backend.has_method("save_database"):
		push_warning("No player database backend is available.")
		return

	var saved := bool(_backend.call("save_database", _database))
	if not saved and _backend.has_method("get_status"):
		var status: Variant = _backend.call("get_status")
		if status is Dictionary:
			var message := String((status as Dictionary).get("last_error", "Could not save player database."))
			if not message.is_empty():
				push_warning(message)


func _players() -> Dictionary:
	_load_database()
	return _database["players"] as Dictionary


func _empty_database() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"backend_format": "player_database_snapshot",
		"next_join_order": 1,
		"players": {},
	}


func _ensure_backend() -> void:
	if _backend != null:
		return

	if storage_backend_id == "sqlite":
		var sqlite_backend: RefCounted = SQLitePlayerDatabaseBackendScript.new()
		sqlite_backend.call("setup", sqlite_database_path, sqlite_migrations_path)
		if bool(sqlite_backend.call("is_available")) and bool(sqlite_backend.call("is_runtime_wired")):
			_backend = sqlite_backend
			return

		push_warning("SQLite backend is not active yet. Falling back to JSON until the runtime driver is wired.")

	var json_backend: RefCounted = JsonPlayerDatabaseBackendScript.new()
	json_backend.call("setup", json_database_path)
	_backend = json_backend


func _normalize_database_shape() -> void:
	if not _database.has("players") or not (_database["players"] is Dictionary):
		_database["players"] = {}
	if int(_database.get("schema_version", 0)) <= 0:
		_database["schema_version"] = SCHEMA_VERSION
	if not _database.has("backend_format"):
		_database["backend_format"] = "player_database_snapshot"
	if int(_database.get("next_join_order", 0)) <= 0:
		_database["next_join_order"] = 1

	var players := _database["players"] as Dictionary
	var normalized_players := {}
	var missing_join_order_records := []
	var highest_join_order := 0
	for key in players.keys():
		var raw_record: Variant = players[key]
		if not (raw_record is Dictionary):
			continue

		var record: Dictionary = raw_record as Dictionary
		var account_key := normalize_account_name(String(record.get("account_name", key)))
		if account_key.is_empty():
			account_key = normalize_account_name(String(key))
		if account_key.is_empty():
			continue

		record["account_name"] = account_key
		record["account_id"] = String(record.get("account_id", account_key))
		if not record.has("created_at_unix"):
			record["created_at_unix"] = _now_unix()
		if not record.has("updated_at_unix"):
			record["updated_at_unix"] = int(record.get("created_at_unix", _now_unix()))
		var join_order := int(record.get("join_order", 0))
		if join_order > 0:
			record["join_order"] = join_order
			highest_join_order = maxi(highest_join_order, join_order)
		else:
			record["join_order"] = 0
			missing_join_order_records.append({
				"account_name": account_key,
				"created_at_unix": int(record.get("created_at_unix", 0)),
			})
		record["world_id"] = _sanitize_storage_id(String(record.get("world_id", DEFAULT_WORLD_ID)), DEFAULT_WORLD_ID)
		record["zone_id"] = _sanitize_storage_id(String(record.get("zone_id", DEFAULT_ZONE_ID)), DEFAULT_ZONE_ID)
		var characters := _character_array_copy(record.get("characters", []))
		var normalized_characters := []
		var next_slot_number := 1
		for raw_character in characters:
			if normalized_characters.size() >= MAX_CHARACTERS_PER_ACCOUNT:
				break

			var character_record: Dictionary = raw_character.duplicate(true)
			var slot_number := maxi(int(character_record.get("slot_number", next_slot_number)), next_slot_number)
			character_record["slot_number"] = slot_number
			character_record["character_id"] = String(
				character_record.get("character_id", "%s:%s:%d" % [account_key, DEFAULT_WORLD_ID, slot_number])
			)
			character_record["world_id"] = _sanitize_storage_id(
				String(character_record.get("world_id", DEFAULT_WORLD_ID)),
				DEFAULT_WORLD_ID
			)
			character_record["zone_id"] = _sanitize_storage_id(
				String(character_record.get("zone_id", DEFAULT_ZONE_ID)),
				DEFAULT_ZONE_ID
			)
			character_record["display_name"] = sanitize_display_name(
				String(character_record.get("display_name", record.get("display_name", "Player"))),
				"Player"
			)
			character_record["appearance"] = _dictionary_copy(character_record.get("appearance", record.get("appearance", {})))
			character_record["created_at_unix"] = int(character_record.get("created_at_unix", record.get("created_at_unix", _now_unix())))
			character_record["updated_at_unix"] = int(character_record.get("updated_at_unix", record.get("updated_at_unix", character_record["created_at_unix"])))
			normalized_characters.append(character_record)
			next_slot_number = maxi(next_slot_number, slot_number + 1)

		if normalized_characters.is_empty() and not String(record.get("display_name", "")).strip_edges().is_empty():
			var legacy_character := _make_character_record(
				account_key,
				String(record.get("display_name", account_key)),
				_dictionary_copy(record.get("appearance", {})),
				1,
				int(record.get("created_at_unix", _now_unix()))
			)
			normalized_characters.append(legacy_character)
			next_slot_number = 2

		record["characters"] = normalized_characters
		record["next_character_slot"] = maxi(int(record.get("next_character_slot", next_slot_number)), next_slot_number)
		var active_character_id := String(record.get("active_character_id", record.get("character_id", "")))
		if active_character_id.is_empty() and not normalized_characters.is_empty():
			active_character_id = String((normalized_characters[0] as Dictionary).get("character_id", ""))
		record["active_character_id"] = active_character_id
		record["character_id"] = active_character_id
		var active_character := _active_character_from_record(record)
		if active_character.is_empty() and not normalized_characters.is_empty():
			active_character = (normalized_characters[0] as Dictionary).duplicate(true)
			record["active_character_id"] = String(active_character.get("character_id", ""))
			record["character_id"] = String(active_character.get("character_id", ""))
		if not active_character.is_empty():
			_apply_active_character_to_record(record, active_character)
		elif String(record.get("display_name", "")).strip_edges().is_empty():
			record["display_name"] = ""
			record["appearance"] = {}
		if not record.has("inventory"):
			record["inventory"] = {}
		if not record.has("stats"):
			record["stats"] = {}
		if not record.has("progression"):
			record["progression"] = {}
		if not record.has("last_position"):
			record["last_position"] = {}
		if not record.has("item_transactions") or not (record["item_transactions"] is Array):
			record["item_transactions"] = []
		normalized_players[account_key] = record

	_database["players"] = normalized_players
	players = _database["players"] as Dictionary
	missing_join_order_records.sort_custom(Callable(self, "_join_order_backfill_less"))
	for raw_missing_record in missing_join_order_records:
		var missing_record := raw_missing_record as Dictionary
		var missing_key := String(missing_record.get("account_name", ""))
		if missing_key.is_empty() or not players.has(missing_key):
			continue

		highest_join_order += 1
		var backfilled_record: Dictionary = players[missing_key]
		backfilled_record["join_order"] = highest_join_order
		players[missing_key] = backfilled_record

	_database["next_join_order"] = maxi(int(_database.get("next_join_order", 1)), highest_join_order + 1)


func _claim_next_join_order() -> int:
	var next_order := maxi(int(_database.get("next_join_order", 1)), _highest_join_order() + 1)
	_database["next_join_order"] = next_order + 1
	return next_order


func _highest_join_order() -> int:
	var highest_order := 0
	var raw_players: Variant = _database.get("players", {})
	if raw_players is Dictionary:
		for record in (raw_players as Dictionary).values():
			if record is Dictionary:
				highest_order = maxi(highest_order, int((record as Dictionary).get("join_order", 0)))
	return highest_order


func _join_order_backfill_less(left: Dictionary, right: Dictionary) -> bool:
	var left_created_at := int(left.get("created_at_unix", 0))
	var right_created_at := int(right.get("created_at_unix", 0))
	if left_created_at == right_created_at:
		return String(left.get("account_name", "")) < String(right.get("account_name", ""))

	return left_created_at < right_created_at


func _dictionary_copy(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return (raw_value as Dictionary).duplicate(true)
	return {}


func _array_copy(raw_value: Variant) -> Array:
	if raw_value is Array:
		return (raw_value as Array).duplicate(true)
	return []


func _sanitize_storage_id(raw_value: String, fallback: String) -> String:
	var clean_value := raw_value.strip_edges().to_lower()
	var output := ""
	for index in range(clean_value.length()):
		var character := clean_value.substr(index, 1)
		if character.is_valid_identifier() or character.is_valid_int() or character in ["-", "_", "."]:
			output += character

	return output if not output.is_empty() else fallback


func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func _success(message: String, record: Dictionary = {}) -> Dictionary:
	return {
		"ok": true,
		"message": message,
		"record": record,
	}


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
		"record": {},
	}
