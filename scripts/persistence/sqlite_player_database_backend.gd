## SQLite storage backend slot for PlayerDatabase.
##
## Godot does not ship SQLite in core. This backend deliberately stays dormant
## until a SQLite GDExtension/addon is installed and we wire its exact API here.
## The schema/migration files already live in `data/migrations/`.
class_name SQLitePlayerDatabaseBackend
extends RefCounted

var database_path := "user://elderforge_players.sqlite3"
var migrations_path := "res://data/migrations"
var last_error := ""


func setup(path: String, migration_folder: String) -> void:
	database_path = path.strip_edges()
	if database_path.is_empty():
		database_path = "user://elderforge_players.sqlite3"

	migrations_path = migration_folder.strip_edges()
	if migrations_path.is_empty():
		migrations_path = "res://data/migrations"


func backend_id() -> String:
	return "sqlite"


func is_available() -> bool:
	return ClassDB.class_exists("SQLite")


func is_runtime_wired() -> bool:
	return false


func load_database(empty_database: Dictionary) -> Dictionary:
	last_error = _missing_runtime_message()
	return empty_database.duplicate(true)


func save_database(_database: Dictionary) -> bool:
	last_error = _missing_runtime_message()
	return false


func get_status() -> Dictionary:
	return {
		"backend": backend_id(),
		"available": is_available(),
		"path": database_path,
		"migrations_path": migrations_path,
		"last_error": last_error,
	}


func _missing_runtime_message() -> String:
	if is_available():
		return "SQLite extension found, but runtime queries are not wired yet."

	return "SQLite backend requires a Godot SQLite GDExtension/addon; JSON backend remains active."
