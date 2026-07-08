## Local-only account session for the first sign-in prototype.
##
## This is deliberately not real MMO authentication. It gives us the shape of a
## sign-in flow while the networking layer is still a direct-connect prototype.
extends Node

signal signed_in(account_name: String, display_name: String)
signal signed_out

const SAVE_PATH := "user://prototype_accounts.json"

var is_signed_in := false
var account_name := ""
var display_name := ""
var auto_join_server := true
var server_address := "127.0.0.1"
var server_port := 24566
var playtest_access_code_hash := ""


## Creates a local prototype account and signs into it immediately.
func create_account(raw_account_name: String, raw_display_name: String, password: String) -> Dictionary:
	var normalized_name := _normalize_account_name(raw_account_name)
	var clean_display_name := raw_display_name.strip_edges()
	var validation_error := _validate_credentials(normalized_name, password)
	if not validation_error.is_empty():
		return _failure(validation_error)
	if clean_display_name.is_empty():
		return _failure("Enter a character name.")

	var accounts := _load_accounts()
	if accounts.has(normalized_name):
		return _failure("That account already exists.")

	accounts[normalized_name] = {
		"display_name": clean_display_name,
		"password_hash": _password_hash(password),
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

	var accounts := _load_accounts()
	if not accounts.has(normalized_name):
		return _failure("Account not found.")

	var account := accounts[normalized_name] as Dictionary
	if String(account.get("password_hash", "")) != _password_hash(password):
		return _failure("Password does not match.")

	_sign_in_as(normalized_name, String(account.get("display_name", normalized_name)))
	return _success("Signed in.")


## Developer bypass for quick local playtests.
func play_as_guest(raw_display_name: String) -> Dictionary:
	var clean_display_name := raw_display_name.strip_edges()
	if clean_display_name.is_empty():
		clean_display_name = "Guest"

	_sign_in_as("guest", clean_display_name)
	return _success("Playing as guest.")


func sign_out() -> void:
	is_signed_in = false
	account_name = ""
	display_name = ""
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


func _sign_in_as(new_account_name: String, new_display_name: String) -> void:
	is_signed_in = true
	account_name = new_account_name
	display_name = new_display_name
	signed_in.emit(account_name, display_name)


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


func _load_accounts() -> Dictionary:
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
