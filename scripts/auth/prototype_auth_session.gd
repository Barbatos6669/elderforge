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
var auto_join_server := true
var server_address := "127.0.0.1"
var server_port := 24566
var playtest_access_code_hash := ""
var character_body_type := DEFAULT_BODY_TYPE
var character_skin_color := DEFAULT_SKIN_COLOR
var character_hair_style := DEFAULT_HAIR_STYLE
var character_hair_color := DEFAULT_HAIR_COLOR


## Creates a local prototype account and signs into it immediately.
func create_account(raw_account_name: String, raw_display_name: String, password: String) -> Dictionary:
	var normalized_name := _normalize_account_name(raw_account_name)
	var clean_display_name := raw_display_name.strip_edges()
	var validation_error := _validate_credentials(normalized_name, password)
	if not validation_error.is_empty():
		return _failure(validation_error)
	if clean_display_name.is_empty():
		return _failure("Enter a character name.")

	var database := _database()
	if database != null:
		_migrate_legacy_accounts_to_database(database)
		if bool(database.call("has_player", normalized_name)):
			return _failure("That account already exists.")

		var appearance := _serialized_appearance_from_values(
			DEFAULT_BODY_TYPE,
			DEFAULT_SKIN_COLOR,
			DEFAULT_HAIR_STYLE,
			DEFAULT_HAIR_COLOR
		)
		var create_result: Dictionary = database.call(
			"create_player",
			normalized_name,
			clean_display_name,
			_password_hash(password),
			appearance
		)
		if not bool(create_result.get("ok", false)):
			return _failure(String(create_result.get("message", "Could not create account.")))

		_apply_appearance_from_data(appearance)
		_sign_in_as(normalized_name, clean_display_name)
		return _success("Account created.")

	var accounts := _load_accounts()
	if accounts.has(normalized_name):
		return _failure("That account already exists.")

	accounts[normalized_name] = {
		"display_name": clean_display_name,
		"password_hash": _password_hash(password),
		"appearance": _serialized_appearance_from_values(
			DEFAULT_BODY_TYPE,
			DEFAULT_SKIN_COLOR,
			DEFAULT_HAIR_STYLE,
			DEFAULT_HAIR_COLOR
		),
	}
	_save_accounts(accounts)
	_sign_in_as(normalized_name, clean_display_name)
	return _success("Account created.")


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

		_apply_appearance_from_data(record.get("appearance", {}))
		_sign_in_as(normalized_name, String(record.get("display_name", normalized_name)))
		return _success("Signed in.")

	var accounts := _load_accounts()
	if not accounts.has(normalized_name):
		return _failure("Account not found.")

	var account := accounts[normalized_name] as Dictionary
	if String(account.get("password_hash", "")) != _password_hash(password):
		return _failure("Password does not match.")

	_apply_appearance_from_data(account.get("appearance", {}))
	_sign_in_as(normalized_name, String(account.get("display_name", normalized_name)))
	return _success("Signed in.")


## Developer bypass for quick local playtests.
func play_as_guest(raw_display_name: String) -> Dictionary:
	var clean_display_name := raw_display_name.strip_edges()
	if clean_display_name.is_empty():
		clean_display_name = "Guest"

	_apply_default_appearance()
	_sign_in_as("guest", clean_display_name)
	return _success("Playing as guest.")


func sign_out() -> void:
	is_signed_in = false
	account_name = ""
	display_name = ""
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
	if not is_signed_in or account_name.is_empty() or account_name == "guest":
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


func _success(message: String) -> Dictionary:
	return {
		"ok": true,
		"message": message,
	}


func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message,
	}
