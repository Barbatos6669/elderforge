## Entry scene that shows the auth screen, then loads the playable world.
##
## Dedicated server launches bypass the auth UI and go straight into the world.
class_name SignInGateway
extends Node

@export_file("*.tscn") var game_scene_path := "res://scenes/world/starting_city/StartingCity.tscn"
@export_file("*.tscn") var character_scene_path := "res://scenes/ui/auth/CharacterCustomizationScreen.tscn"
@export_file("*.tscn") var character_selection_scene_path := "res://scenes/ui/auth/CharacterSelectionScreen.tscn"
@export var auth_panel_path: NodePath = NodePath("AuthPanel")


func _ready() -> void:
	if _is_command_line_server():
		call_deferred("_enter_game_scene")
		return

	var auth_panel := get_node_or_null(auth_panel_path)
	if auth_panel != null and auth_panel.has_signal("authentication_succeeded"):
		auth_panel.authentication_succeeded.connect(_on_authentication_succeeded)


func _on_authentication_succeeded(created_account: bool) -> void:
	var session := get_node_or_null("/root/PrototypeAuthSession")
	if created_account or session == null or not session.has_method("has_characters") or not bool(session.call("has_characters")):
		_enter_character_scene()
		return

	_enter_character_selection_scene()


func _enter_character_scene() -> void:
	if character_scene_path.strip_edges().is_empty():
		_enter_game_scene()
		return

	get_tree().change_scene_to_file(character_scene_path)


func _enter_character_selection_scene() -> void:
	if character_selection_scene_path.strip_edges().is_empty():
		_enter_character_scene()
		return

	get_tree().change_scene_to_file(character_selection_scene_path)


func _enter_game_scene() -> void:
	get_tree().change_scene_to_file(game_scene_path)


func _is_command_line_server() -> bool:
	for argument in _all_command_line_arguments():
		var normalized_argument := argument.strip_edges().to_lower()
		if normalized_argument == "--server" or normalized_argument == "--dedicated-server":
			return true

	return false


func _all_command_line_arguments() -> PackedStringArray:
	var arguments := PackedStringArray()
	arguments.append_array(OS.get_cmdline_args())
	arguments.append_array(OS.get_cmdline_user_args())
	return arguments
