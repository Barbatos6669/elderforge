## Local-only account session for the first sign-in prototype.
##
## This is deliberately not real MMO authentication. It gives us the shape of a
## sign-in flow while the networking layer is still a direct-connect prototype.
extends Node

signal signed_in(account_name: String, display_name: String)
signal signed_out

const SAVE_PATH := "user://prototype_accounts.json"
const DEFAULT_BODY_TYPE := "male"
const DEFAULT_SKIN_COLOR := Color(0.74, 0.86, 0.92, 1.0)
const DEFAULT_HAIR_STYLE := "short"
const DEFAULT_HAIR_COLOR := Color(0.16, 0.11, 0.08, 1.0)

var is_signed_in := false
var account_name := ""
var display_name := ""
var active_character_id := ""
var join_order := 0
var auto_join_server := true
var server_address := "127.0.0.1"
var server_port := 24566
var playtest_access_code_hash := ""
var character_body_type := DEFAULT_BODY_TYPE
var character_skin_color := DEFAULT_SKIN_COLOR
var character_hair_style := DEFAULT_HAIR_STYLE
var character_hair_color := DEFAULT_HAIR_COLOR


## Creates a local prototype account and signs into it immediately.
func create_account(raw_account_name: String, password: String) -> Dictionary:
	var normalized_name := _normalize_account_name(raw_account_name)
	var validation_error := _validate_credentials(normalized_name, password)
	if not validation_error.is_empty():
		return _failure(validation_error)

	var database := _database()
	if database != null:
		_migrate_legacy_accounts_to_database(database)
		if bool(database.call("has_player", normalized_name)):
			return _failure("That account already exists.")

		var create_result: Dictionary = database.call(
			"create_player",
			normalized_name,
			"",
			_password_hash(password),
			{}
		)
		if not bool(create_result.get("ok", false)):
			return _failure(String(create_result.get("message", "Could not create account.")))

		_apply_join_order_from_record(create_result.get("record", {}))
		_apply_default_appearance()
		_sign_in_as(normalized_name, "")
		return _success("Account created.", true)

	var accounts := _load_accounts()
	if accounts.has(normalized_name):
		return _failure("That account already exists.")

	accounts[normalized_name] = {
		"display_name": "",
		"password_hash": _password_hash(password),
		"appearance": {},
		"characters": [],
		"active_character_id": "",
	}
	_save_accounts(accounts)
	_sign_in_as(normalized_name, "")
	return _success("Account created.", true)


## Signs into an existing local prototype account.
func sign_in(raw_account_name: String, password: String) -> Dictionary:
	var normalized_name := _normalize_account_name(raw_account_name)
	var validation_error := _validate_credentials(normalized_name, password)
	if not validation_error.is_empty():
		return _failure(validation_error)

	var database := _database()
	if database != null:
		_migrate_legacy_accounts_to_database(database)
		if not bool(database.call("has_player", normalized_name)):
			return _failure("Account not found.")

		var record: Dictionary = database.call("get_player", normalized_name)
		if String(record.get("password_hash", "")) != _password_hash(password):
			return _failure("Password does not match.")

		_apply_join_order_from_record(record)
		_apply_active_character_from_record(record)
		_sign_in_as(normalized_name, display_name)
		return _success("Signed in.", false)

	var accounts := _load_accounts()
	if not accounts.has(normalized_name):
		return _failure("Account not found.")

	var account := accounts[normalized_name] as Dictionary
	if String(account.get("password_hash", "")) != _password_hash(password):
		return _failure("Password does not match.")

	join_order = int(account.get("join_order", 0))
	_apply_active_character_from_record(account)
	_sign_in_as(normalized_name, display_name)
	return _success("Signed in.", false)


func sign_out() -> void:
	is_signed_in = false
	account_name = ""
	display_name = ""
	active_character_id = ""
	join_order = 0
	_apply_default_appearance()
	signed_out.emit()


## Stores the playtest server selected by the sign-in scene.
func set_playtest_server(
	address: String,
	port: int,
	should_auto_join: bool = true,
	access_code_hash: String = ""
) -> void:
	var clean_address := address.strip_edges()
	server_address = clean_address if not clean_address.is_empty() else "127.0.0.1"
	server_port = clampi(port, 1024, 65535)
	auto_join_server = should_auto_join
	playtest_access_code_hash = access_code_hash.strip_edges().to_lower()


func get_characters() -> Array:
	if not is_signed_in or account_name.is_empty():
		return []

	var database := _database()
	if database != null and database.has_method("get_player_characters"):
		var characters: Variant = database.call("get_player_characters", account_name)
		if characters is Array:
			return (characters as Array).duplicate(true)

	var account := _legacy_account_record()
	if account.is_empty():
		return []

	var raw_characters: Variant = account.get("characters", [])
	if raw_characters is Array:
		return (raw_characters as Array).duplicate(true)

	return []


func has_characters() -> bool:
	return not get_characters().is_empty()


func can_create_character() -> bool:
	return get_characters().size() < 3


func create_character(character_name: String, appearance: Dictionary) -> Dictionary:
	if not is_signed_in or account_name.is_empty():
		return _failure("Sign in before creating a character.")
	if not can_create_character():
		return _failure("This account already has three characters.")

	var database := _database()
	if database != null and database.has_method("create_character"):
		var result: Dictionary = database.call("create_character", account_name, character_name, appearance)
		if bool(result.get("ok", false)):
			_apply_active_character_from_record(result.get("record", {}))
		return result

	return _create_legacy_character(character_name, appearance)


func select_character(character_id: String) -> Dictionary:
	if not is_signed_in or account_name.is_empty():
		return _failure("Sign in before selecting a character.")

	var database := _database()
	if database != null and database.has_method("set_active_character"):
		if not bool(database.call("set_active_character", account_name, character_id)):
			return _failure("Character not found.")

		var record: Dictionary = database.call("get_player", account_name)
		_apply_active_character_from_record(record)
		return _success("Character selected.", false)

	var characters := get_characters()
	for character in characters:
		if String((character as Dictionary).get("character_id", "")) == character_id:
			_apply_character_record(character as Dictionary)
			_save_legacy_active_character(character_id, character as Dictionary)
			return _success("Character selected.", false)

	return _failure("Character not found.")


## Stores the appearance selected on the character screen.
func set_character_appearance(
	body_type: String,
	skin_color: Color,
	hair_style: String,
	hair_color: Color = DEFAULT_HAIR_COLOR
) -> void:
	character_body_type = _sanitize_body_type(body_type)
	character_skin_color = _sanitize_color(skin_color, DEFAULT_SKIN_COLOR)
	character_hair_style = _sanitize_hair_style(hair_style)
	character_hair_color = _sanitize_color(hair_color, DEFAULT_HAIR_COLOR)
	_save_current_account_appearance()


## Returns the current character appearance as network/UI friendly data.
func get_character_appearance() -> Dictionary:
	return _serialized_appearance_from_values(
		character_body_type,
		character_skin_color,
		character_hair_style,
		character_hair_color
	)


## Applies trusted profile metadata returned by the playtest server.
func apply_server_profile(profile: Dictionary) -> void:
	if not is_signed_in:
		return

	var server_account := _normalize_account_name(String(profile.get("account_name", "")))
	if not server_account.is_empty() and server_account != account_name:
		return

	join_order = maxi(int(profile.get("join_order", join_order)), 0)
	active_character_id = String(profile.get("active_character_id", active_character_id)).strip_edges()
	var server_display_name := String(profile.get("display_name", "")).strip_edges()
	if not server_display_name.is_empty():
		display_name = server_display_name
	var server_appearance: Variant = profile.get("appearance", {})
	if server_appearance is Dictionary:
		_apply_appearance_from_data(server_appearance)


func _sign_in_as(new_account_name: String, new_display_name: String) -> void:
	is_signed_in = true
	account_name = new_account_name
	display_name = new_display_name
	signed_in.emit(account_name, display_name)


func _apply_default_appearance() -> void:
	character_body_type = DEFAULT_BODY_TYPE
	character_skin_color = DEFAULT_SKIN_COLOR
	character_hair_style = DEFAULT_HAIR_STYLE
	character_hair_color = DEFAULT_HAIR_COLOR


func _apply_active_character_from_record(raw_record: Variant) -> void:
	if not (raw_record is Dictionary):
		display_name = ""
		active_character_id = ""
		_apply_default_appearance()
		return

	var record := raw_record as Dictionary
	active_character_id = String(record.get("active_character_id", record.get("character_id", ""))).strip_edges()
	var active_character := {}
	var raw_characters: Variant = record.get("characters", [])
	if raw_characters is Array:
		for raw_character in (raw_characters as Array):
			if not (raw_character is Dictionary):
				continue

			var character := raw_character as Dictionary
			if String(character.get("character_id", "")) == active_character_id:
				active_character = character
				break

	if active_character.is_empty() and raw_characters is Array and not (raw_characters as Array).is_empty():
		var first_character: Variant = (raw_characters as Array)[0]
		if first_character is Dictionary:
			active_character = first_character as Dictionary
			active_character_id = String(active_character.get("character_id", ""))

	if active_character.is_empty():
		display_name = ""
		active_character_id = ""
		_apply_default_appearance()
		return

	_apply_character_record(active_character)


func _apply_character_record(character: Dictionary) -> void:
	active_character_id = String(character.get("character_id", active_character_id)).strip_edges()
	display_name = String(character.get("display_name", "")).strip_edges()
	_apply_appearance_from_data(character.get("appearance", {}))


func _apply_appearance_from_data(raw_data: Variant) -> void:
	if not (raw_data is Dictionary):
		_apply_default_appearance()
		return

	var data := raw_data as Dictionary
	character_body_type = _sanitize_body_type(String(data.get("body_type", DEFAULT_BODY_TYPE)))
	character_skin_color = _color_from_html(String(data.get("skin_color", "")), DEFAULT_SKIN_COLOR)
	character_hair_style = _sanitize_hair_style(String(data.get("hair_style", DEFAULT_HAIR_STYLE)))
	character_hair_color = _color_from_html(String(data.get("hair_color", "")), DEFAULT_HAIR_COLOR)


func _save_current_account_appearance() -> void:
	if not is_signed_in or account_name.is_empty():
		return

	var database := _database()
	if database != null and database.has_method("set_player_appearance"):
		database.call("set_player_appearance", account_name, get_character_appearance())
		return

	var accounts := _load_accounts()
	if not accounts.has(account_name):
		return

	var account := accounts[account_name] as Dictionary
	account["appearance"] = get_character_appearance()
	accounts[account_name] = account
	_save_accounts(accounts)


func _validate_credentials(normalized_name: String, password: String) -> String:
	if normalized_name.is_empty():
		return "Enter an account name."
	if normalized_name.length() < 3:
		return "Account name must be at least 3 characters."
	if password.length() < 4:
		return "Password must be at least 4 characters."

	return ""


func _normalize_account_name(raw_account_name: String) -> String:
	return raw_account_name.strip_edges().to_lower()


func _password_hash(password: String) -> String:
	return password.sha256_text()


func _serialized_appearance_from_values(
	body_type: String,
	skin_color: Color,
	hair_style: String,
	hair_color: Color
) -> Dictionary:
	return {
		"body_type": _sanitize_body_type(body_type),
		"skin_color": _sanitize_color(skin_color, DEFAULT_SKIN_COLOR).to_html(true),
		"hair_style": _sanitize_hair_style(hair_style),
		"hair_color": _sanitize_color(hair_color, DEFAULT_HAIR_COLOR).to_html(true),
	}


func _sanitize_body_type(body_type: String) -> String:
	var normalized := body_type.strip_edges().to_lower()
	if normalized == "female":
		return "female"

	return "male"


func _sanitize_hair_style(hair_style: String) -> String:
	var normalized := hair_style.strip_edges().to_lower()
	if normalized in ["none", "buzzed", "short", "long", "buns"]:
		return normalized

	return DEFAULT_HAIR_STYLE


func _sanitize_color(color: Color, fallback: Color) -> Color:
	if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a):
		return fallback

	return Color(
		clampf(color.r, 0.0, 1.0),
		clampf(color.g, 0.0, 1.0),
		clampf(color.b, 0.0, 1.0),
		clampf(color.a, 0.0, 1.0)
	)


func _color_from_html(raw_value: String, fallback: Color) -> Color:
	var clean_value := raw_value.strip_edges()
	if clean_value.is_empty() or not Color.html_is_valid(clean_value):
		return fallback

	return _sanitize_color(Color.html(clean_value), fallback)


func _apply_join_order_from_record(raw_record: Variant) -> void:
	if raw_record is Dictionary:
		join_order = maxi(int((raw_record as Dictionary).get("join_order", 0)), 0)


func _load_accounts() -> Dictionary:
	var database := _database()
	if database != null and database.has_method("get_account_map"):
		_migrate_legacy_accounts_to_database(database)
		return database.call("get_account_map") as Dictionary

	return _load_legacy_accounts()


func _load_legacy_accounts() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _save_accounts(accounts: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save prototype account data.")
		return

	file.store_string(JSON.stringify(accounts, "\t"))


func _legacy_account_record() -> Dictionary:
	if account_name.is_empty():
		return {}

	var accounts := _load_legacy_accounts()
	var raw_account: Variant = accounts.get(account_name, {})
	return raw_account as Dictionary if raw_account is Dictionary else {}


func _create_legacy_character(character_name: String, appearance: Dictionary) -> Dictionary:
	var clean_name := character_name.strip_edges()
	if clean_name.is_empty():
		return _failure("Enter a character name.")

	var accounts := _load_legacy_accounts()
	var raw_account: Variant = accounts.get(account_name, {})
	var account := raw_account as Dictionary if raw_account is Dictionary else {}
	var characters := []
	var raw_characters: Variant = account.get("characters", [])
	if raw_characters is Array:
		characters = (raw_characters as Array).duplicate(true)
	if characters.size() >= 3:
		return _failure("This account already has three characters.")

	var slot_number := characters.size() + 1
	var character := {
		"character_id": "%s:main:%d" % [account_name, slot_number],
		"slot_number": slot_number,
		"display_name": clean_name,
		"appearance": appearance.duplicate(true),
	}
	characters.append(character)
	account["characters"] = characters
	account["active_character_id"] = String(character["character_id"])
	account["display_name"] = clean_name
	account["appearance"] = appearance.duplicate(true)
	accounts[account_name] = account
	_save_accounts(accounts)
	_apply_character_record(character)
	return _success("Character created.", false)


func _save_legacy_active_character(character_id: String, character: Dictionary) -> void:
	var accounts := _load_legacy_accounts()
	if not accounts.has(account_name):
		return

	var account := accounts[account_name] as Dictionary
	account["active_character_id"] = character_id
	account["display_name"] = String(character.get("display_name", ""))
	account["appearance"] = character.get("appearance", {})
	accounts[account_name] = account
	_save_accounts(accounts)


func _migrate_legacy_accounts_to_database(database: Node) -> void:
	if database == null or not database.has_method("create_player") or not database.has_method("has_player"):
		return

	var legacy_accounts := _load_legacy_accounts()
	if legacy_accounts.is_empty():
		return

	for legacy_name in legacy_accounts.keys():
		var account_name_key := _normalize_account_name(String(legacy_name))
		if account_name_key.is_empty() or bool(database.call("has_player", account_name_key)):
			continue

		var raw_legacy_record: Variant = legacy_accounts[legacy_name]
		if not (raw_legacy_record is Dictionary):
			continue

		var legacy_record: Dictionary = raw_legacy_record as Dictionary
		database.call(
			"create_player",
			account_name_key,
			String(legacy_record.get("display_name", account_name_key)),
			String(legacy_record.get("password_hash", "")),
			legacy_record.get("appearance", {})
		)


func _database() -> Node:
	return get_node_or_null("/root/PlayerDatabase")


func _success(message: String, created_account: bool = false) -> Dictionary:
	return {
		"ok": true,
		"message": message,
		"created_account": created_account,
	}


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
