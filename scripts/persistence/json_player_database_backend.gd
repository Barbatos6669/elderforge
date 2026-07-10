## JSON storage backend for the PlayerDatabase facade.
##
## This keeps the current playtest zero-dependency while PlayerDatabase grows
## into a real service boundary. Gameplay scripts should not call this directly.
class_name JsonPlayerDatabaseBackend
extends RefCounted

var database_path := "user://player_database.json"
var last_error := ""


func setup(path: String) -> void:
	database_path = path.strip_edges()
	if database_path.is_empty():
		database_path = "user://player_database.json"


func backend_id() -> String:
	return "json"


func is_available() -> bool:
	return true


func load_database(empty_database: Dictionary) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(database_path):
		return empty_database.duplicate(true)

	var file := FileAccess.open(database_path, FileAccess.READ)
	if file == null:
		last_error = "Could not open player database."
		return empty_database.duplicate(true)

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)

	last_error = "Player database JSON was invalid; starting with an empty database."
	return empty_database.duplicate(true)


func save_database(database: Dictionary) -> bool:
	last_error = ""
	var file := FileAccess.open(database_path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not save player database."
		return false

	file.store_string(JSON.stringify(database, "\t"))
	return true


func get_status() -> Dictionary:
	return {
		"backend": backend_id(),
		"available": is_available(),
		"path": database_path,
		"last_error": last_error,
	}
