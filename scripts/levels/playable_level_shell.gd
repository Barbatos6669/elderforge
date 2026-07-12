## Runtime setup for playable level shells.
##
## Normal clients keep the full shell: player, HUD, inventory, refining, loot,
## and network manager. Dedicated servers remove client-only UI before child
## panels run `_ready()`, which keeps headless logs clean and avoids UI state
## pretending to be server gameplay.
class_name PlayableLevelShell
extends Node3D

## Root-child nodes that should not exist in a command-line dedicated server.
@export var dedicated_server_client_only_paths: Array[NodePath] = [
	NodePath("SceneToonMaterialPass"),
	NodePath("InventoryPanel"),
	NodePath("PlayerStatusHud"),
	NodePath("WorldTimeHud"),
	NodePath("HudMap"),
	NodePath("DeathMessageHud"),
	NodePath("RefiningPanel"),
	NodePath("ServiceNpcDialogPanel"),
	NodePath("AuctionHousePanel"),
	NodePath("LootPanel"),
	NodePath("ChatPanel"),
	NodePath("MasterMenu"),
]


func _enter_tree() -> void:
	if not _is_command_line_server():
		return

	_remove_client_only_nodes()


func _remove_client_only_nodes() -> void:
	for node_path in dedicated_server_client_only_paths:
		var node := get_node_or_null(node_path)
		if node == null:
			continue

		remove_child(node)
		node.queue_free()


func _is_command_line_server() -> bool:
	for argument in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var normalized_argument := argument.strip_edges().to_lower()
		if normalized_argument == "--server" or normalized_argument == "--dedicated-server":
			return true

	return false
