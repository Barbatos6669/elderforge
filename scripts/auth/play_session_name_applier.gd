## Applies the signed-in display name from the auth session to the playable scene.
class_name PlaySessionNameApplier
extends Node

@export var player_path: NodePath = NodePath("../World/Player")
@export var status_hud_path: NodePath = NodePath("../PlayerStatusHud")
@export var network_manager_path: NodePath = NodePath("../Network")


func _ready() -> void:
	call_deferred("_apply_signed_in_name")


func _apply_signed_in_name() -> void:
	var auth_session := get_node_or_null("/root/PrototypeAuthSession")
	if auth_session == null:
		return

	var display_name := String(auth_session.get("display_name")).strip_edges()
	if display_name.is_empty():
		return

	var player := get_node_or_null(player_path)
	var nameplate := player.get_node_or_null("Nameplate") if player != null else null
	if nameplate != null and nameplate.has_method("set_player_name"):
		nameplate.call("set_player_name", display_name)

	var status_hud := get_node_or_null(status_hud_path)
	if status_hud != null and status_hud.has_method("set_player_name"):
		status_hud.call("set_player_name", display_name)

	var network_manager := get_node_or_null(network_manager_path)
	if network_manager != null and network_manager.has_method("set_local_player_name"):
		network_manager.call("set_local_player_name", display_name)
