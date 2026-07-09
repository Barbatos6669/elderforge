## Small direct-connect multiplayer harness for early playtests.
##
## This is intentionally not MMO architecture yet. It lets one player host, a
## friend join by IP, and both clients see each other as remote player copies.
class_name MultiplayerTestManager
extends Node

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const DEFAULT_PORT := 24565
const PLAYTEST_CONFIG_FILE := "playtest_server.cfg"
const PLAYTEST_VERSION_FILE := "playtest_version.json"

## Existing local player in the level shell.
@export var local_player_path: NodePath = NodePath("../World/Player")
## Parent used for visual-only remote player copies.
@export var remote_players_path: NodePath = NodePath("../World/RemotePlayers")
## Builds the simple Host/Join panel during play.
@export var build_test_panel := true
## Keeps the fallback network tools available without showing them by default.
@export var test_panel_starts_visible := false
## Lets a Windows/Linux process auto-host when launched with --server.
@export var allow_command_line_server := true
## Clients coming from the sign-in scene auto-join the selected playtest server.
@export var auto_join_from_auth_session := true
## How long the world scene keeps looking for a signed-in auth session to join.
@export var auto_join_retry_duration := 8.0
## Delay between auto-join checks while the sign-in handoff settles.
@export var auto_join_retry_interval := 0.25
## Port used by the Host and Join buttons.
@export_range(1024, 65535, 1) var default_port := DEFAULT_PORT
## Maximum clients accepted by the host.
@export_range(1, 32, 1) var max_clients := 8
## How often local player state is sent.
@export_range(1.0, 30.0, 1.0) var send_rate_hz := 15.0
## Default name used if the local nameplate is empty.
@export var fallback_player_name := "Player"
## Name shown in logs if this process is running as a dedicated test host.
@export var command_line_server_name := "Elderforge Test Server"
## If true, the server requires a matching playtest code hash before accepting client state.
@export var require_playtest_code := false
## SHA-256 hash of the playtest code. Prefer setting this from config/CLI, not in the public repo.
@export var playtest_access_code_hash := ""
## If true, the server accepts no new clients until the status/config gate is cleared.
@export var maintenance_mode := false
## Message shown to clients when maintenance mode blocks a connection.
@export var maintenance_message := "Server maintenance is active. Please update and try again soon."
## Exact exported build id required by this server. Empty means any build id is accepted.
@export var required_client_build_id := ""
## Fallback commit gate if no build id is configured. Empty means any commit is accepted.
@export var required_client_commit := ""

var _peer: ENetMultiplayerPeer
var _remote_players := {}
var _authorized_peers := {}
var _send_elapsed := 0.0
var _is_command_line_server := false
var _client_playtest_code_accepted := false
var _panel: Control
var _status_label: Label
var _address_field: LineEdit
var _port_field: LineEdit
var _name_field: LineEdit
var _code_field: LineEdit
var _auto_join_elapsed := 0.0
var _auto_join_interval_elapsed := 0.0


func _ready() -> void:
	_connect_multiplayer_signals()
	_ensure_remote_players_root()
	call_deferred("_connect_world_state_sources")
	_apply_sidecar_playtest_security()
	_apply_command_line_playtest_security()
	_is_command_line_server = allow_command_line_server and _has_command_line_server_flag()
	if _is_command_line_server:
		_configure_command_line_server_runtime()
	elif build_test_panel:
		_build_test_panel()
	_set_status("Offline")
	if _is_command_line_server:
		call_deferred("host", _command_line_port())
	else:
		call_deferred("_try_auto_join_from_auth_session")


func _process(delta: float) -> void:
	_update_auto_join_retry(delta)
	if not _is_network_active():
		return

	_send_elapsed += maxf(delta, 0.0)
	var send_interval := 1.0 / maxf(send_rate_hz, 1.0)
	if _send_elapsed < send_interval:
		return

	_send_elapsed = 0.0
	_send_local_state()
	_send_local_mob_states()


func _unhandled_input(event: InputEvent) -> void:
	if _panel == null:
		return
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F9:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func host(port: int = default_port) -> bool:
	disconnect_from_session()
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(port, max_clients)
	if error != OK:
		_peer = null
		_set_status("Host failed: %s" % error_string(error))
		return false

	multiplayer.multiplayer_peer = _peer
	_authorized_peers.clear()
	_client_playtest_code_accepted = true
	_send_elapsed = 0.0
	_apply_local_player_name()
	if _is_command_line_server:
		_set_status("%s hosting on UDP %d" % [command_line_server_name, port])
	else:
		_set_status("Hosting on UDP %d" % port)
	return true


func join(address: String, port: int = default_port) -> bool:
	disconnect_from_session()
	var trimmed_address := address.strip_edges()
	if trimmed_address.is_empty():
		trimmed_address = "127.0.0.1"

	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(trimmed_address, port)
	if error != OK:
		_peer = null
		_set_status("Join failed: %s" % error_string(error))
		return false

	multiplayer.multiplayer_peer = _peer
	_client_playtest_code_accepted = false
	_send_elapsed = 0.0
	_apply_local_player_name()
	_set_status("Connecting to %s:%d" % [trimmed_address, port])
	return true


func disconnect_from_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_peer = null
	_authorized_peers.clear()
	_client_playtest_code_accepted = false
	_send_elapsed = 0.0
	_clear_remote_players()
	_set_status("Offline")


## Updates the local display name used by host/join state broadcasts.
func set_local_player_name(player_name: String) -> void:
	var clean_name := player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Player"

	fallback_player_name = clean_name
	if _name_field != null:
		_name_field.text = clean_name
	_apply_local_player_name()


@rpc("any_peer", "unreliable")
func _server_receive_player_state(
	position: Vector3,
	visual_yaw: float,
	is_moving: bool,
	player_name: String,
	action_state: String = "",
	action_context: Dictionary = {}
) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	if not _is_peer_authorized(sender_id):
		return

	_apply_remote_player_state(sender_id, position, visual_yaw, is_moving, player_name, action_state, action_context)
	rpc("_client_receive_player_state", sender_id, position, visual_yaw, is_moving, player_name, action_state, action_context)


@rpc("authority", "unreliable")
func _client_receive_player_state(
	peer_id: int,
	position: Vector3,
	visual_yaw: float,
	is_moving: bool,
	player_name: String,
	action_state: String = "",
	action_context: Dictionary = {}
) -> void:
	if peer_id == multiplayer.get_unique_id():
		return

	_apply_remote_player_state(peer_id, position, visual_yaw, is_moving, player_name, action_state, action_context)


@rpc("authority", "reliable")
func _client_remove_remote_player(peer_id: int) -> void:
	_remove_remote_player(peer_id)


@rpc("any_peer", "reliable")
func _server_submit_playtest_code(
	playtest_code_hash: String,
	player_name: String,
	client_build_id: String = "",
	client_commit: String = ""
) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return

	var version_result := _server_client_version_result(client_build_id, client_commit)
	if not bool(version_result.get("accepted", false)):
		var version_message := String(version_result.get("message", "Update required."))
		rpc_id(sender_id, "_client_receive_playtest_code_result", false, version_message)
		_set_status("Rejected peer %d: %s" % [sender_id, version_message])
		if _peer != null:
			_peer.disconnect_peer(sender_id)
		return

	var clean_hash := playtest_code_hash.strip_edges().to_lower()
	if _is_playtest_code_accepted(clean_hash):
		_authorized_peers[sender_id] = true
		rpc_id(sender_id, "_client_receive_playtest_code_result", true, "Playtest code accepted.")
		call_deferred("_send_world_state_to_peer", sender_id)
		_set_status("Peer %d authorized as %s." % [sender_id, player_name.strip_edges()])
		return

	rpc_id(sender_id, "_client_receive_playtest_code_result", false, "Playtest code rejected.")
	_set_status("Rejected peer %d: bad playtest code." % sender_id)
	if _peer != null:
		_peer.disconnect_peer(sender_id)


@rpc("authority", "reliable")
func _client_receive_playtest_code_result(accepted: bool, message: String) -> void:
	_client_playtest_code_accepted = accepted
	if not accepted:
		disconnect_from_session()
		_set_status(message if not message.is_empty() else "Playtest code rejected")
		return

	_set_status(message if not message.is_empty() else "Connected")


@rpc("any_peer", "reliable")
func _server_receive_resource_state(resource_path: String, remaining_ticks: int, _max_ticks: int) -> void:
	if not multiplayer.is_server() or not _is_network_active():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0 or not _is_peer_authorized(sender_id):
		return

	var resource := _node_from_state_path(resource_path)
	if resource == null or not resource.has_method("set_remaining_ticks"):
		return
	if not resource.has_method("get_remaining_ticks") or not resource.has_method("get_max_ticks"):
		return

	var server_remaining := int(resource.call("get_remaining_ticks"))
	var max_ticks := int(resource.call("get_max_ticks"))
	var clean_remaining := clampi(remaining_ticks, 0, max_ticks)
	if clean_remaining > server_remaining:
		return

	resource.call("set_remaining_ticks", clean_remaining)


@rpc("authority", "reliable")
func _client_receive_resource_state(resource_path: String, remaining_ticks: int, _max_ticks: int) -> void:
	var resource := _node_from_state_path(resource_path)
	if resource == null or not resource.has_method("set_remaining_ticks"):
		return

	resource.call("set_remaining_ticks", remaining_ticks)


@rpc("any_peer", "reliable")
func _server_receive_mob_damage(mob_path: String, damage: float) -> void:
	if not multiplayer.is_server() or not _is_network_active():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0 or not _is_peer_authorized(sender_id):
		return

	var mob := _node_from_state_path(mob_path)
	var health := _mob_health(mob)
	if health == null or not health.has_method("apply_damage"):
		return

	var clean_damage := clampf(damage, 0.0, 500.0)
	var applied_damage := float(health.call("apply_damage", clean_damage))
	if applied_damage <= 0.0:
		return

	_broadcast_mob_combat_event(sender_id, mob, applied_damage)


@rpc("authority", "reliable")
func _client_receive_mob_state(mob_path: String, current_health: float, max_health: float) -> void:
	_apply_mob_health_state(mob_path, current_health, max_health, false)


@rpc("authority", "reliable")
func _client_receive_mob_combat_event(
	attacker_peer_id: int,
	mob_path: String,
	damage: float,
	current_health: float,
	max_health: float
) -> void:
	var is_local_attacker := attacker_peer_id == multiplayer.get_unique_id()
	if not is_local_attacker:
		_play_remote_attack_for_peer(attacker_peer_id)
		_emit_mob_damage_feedback(mob_path, damage)

	_apply_mob_health_state(mob_path, current_health, max_health, false)


@rpc("any_peer", "unreliable")
func _server_receive_mob_motion_state(
	mob_path: String,
	position: Vector3,
	visual_yaw: float,
	is_moving: bool
) -> void:
	if not multiplayer.is_server() or not _is_network_active():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0 or not _is_peer_authorized(sender_id):
		return

	var mob := _node_from_state_path(mob_path)
	if mob == null:
		return

	_apply_mob_motion_state(mob_path, position, visual_yaw, is_moving)
	rpc("_client_receive_mob_motion_state", sender_id, mob_path, position, visual_yaw, is_moving)


@rpc("authority", "unreliable")
func _client_receive_mob_motion_state(
	controller_peer_id: int,
	mob_path: String,
	position: Vector3,
	visual_yaw: float,
	is_moving: bool
) -> void:
	if controller_peer_id == multiplayer.get_unique_id():
		return

	_apply_mob_motion_state(mob_path, position, visual_yaw, is_moving)


@rpc("any_peer", "reliable")
func _server_receive_mob_attack_event(mob_path: String, speed_scale: float) -> void:
	if not multiplayer.is_server() or not _is_network_active():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0 or not _is_peer_authorized(sender_id):
		return

	var mob := _node_from_state_path(mob_path)
	if mob == null:
		return

	_broadcast_mob_attack_event(sender_id, mob, speed_scale)


@rpc("authority", "reliable")
func _client_receive_mob_attack_event(controller_peer_id: int, mob_path: String, speed_scale: float) -> void:
	if controller_peer_id == multiplayer.get_unique_id():
		return

	_play_mob_attack(mob_path, speed_scale)


func _send_local_state() -> void:
	if _is_command_line_server:
		return
	if not multiplayer.is_server() and not _client_playtest_code_accepted:
		return

	var local_player := _get_local_player()
	if local_player == null or not local_player.has_method("get_network_state"):
		return

	var state: Dictionary = local_player.call("get_network_state")
	var position := state.get("position", local_player.global_position) as Vector3
	var visual_yaw := float(state.get("visual_yaw", 0.0))
	var is_moving := bool(state.get("is_moving", false))
	var player_name := _local_player_name()
	var action_state := String(state.get("action_state", ""))
	var action_context := {}
	var action_context_value: Variant = state.get("action_context", {})
	if action_context_value is Dictionary:
		action_context = action_context_value.duplicate(true)

	if multiplayer.is_server():
		rpc(
			"_client_receive_player_state",
			multiplayer.get_unique_id(),
			position,
			visual_yaw,
			is_moving,
			player_name,
			action_state,
			action_context
		)
	else:
		rpc_id(1, "_server_receive_player_state", position, visual_yaw, is_moving, player_name, action_state, action_context)


func _send_local_mob_states() -> void:
	if _is_command_line_server:
		return
	if not multiplayer.is_server() and not _client_playtest_code_accepted:
		return

	for mob in get_tree().get_nodes_in_group("network_mobs"):
		var ai := _mob_ai(mob)
		if ai == null or not ai.has_method("has_network_activity") or not ai.has_method("get_network_state"):
			continue
		if not bool(ai.call("has_network_activity")):
			continue

		var mob_path := _state_path_for_node(mob)
		if mob_path.is_empty():
			continue

		var state: Dictionary = ai.call("get_network_state")
		var position := state.get("position", Vector3.ZERO) as Vector3
		var visual_yaw := float(state.get("visual_yaw", 0.0))
		var is_moving := bool(state.get("is_moving", false))
		if multiplayer.is_server():
			_broadcast_mob_motion_state(multiplayer.get_unique_id(), mob, position, visual_yaw, is_moving)
		else:
			rpc_id(1, "_server_receive_mob_motion_state", mob_path, position, visual_yaw, is_moving)


func _connect_world_state_sources() -> void:
	_connect_local_world_action_sources()
	_connect_resource_state_sources()
	_connect_mob_state_sources()


func _connect_local_world_action_sources() -> void:
	var local_player := _get_local_player()
	if local_player == null:
		return

	var gathering := local_player.get_node_or_null("Gathering")
	if gathering != null and gathering.has_signal("gathering_completed"):
		var gathering_callback := Callable(self, "_on_local_gathering_completed")
		if not gathering.is_connected("gathering_completed", gathering_callback):
			gathering.connect("gathering_completed", gathering_callback)

	var auto_attack := local_player.get_node_or_null("AutoAttack")
	if auto_attack != null and auto_attack.has_signal("attack_landed"):
		var attack_callback := Callable(self, "_on_local_attack_landed")
		if not auto_attack.is_connected("attack_landed", attack_callback):
			auto_attack.connect("attack_landed", attack_callback)


func _connect_resource_state_sources() -> void:
	if not is_inside_tree():
		return

	for resource in get_tree().get_nodes_in_group("gatherable_resources"):
		if resource == null:
			continue

		if resource.has_signal("gather_tick_consumed"):
			var consumed_callback := Callable(self, "_on_resource_state_changed").bind(resource)
			if not resource.is_connected("gather_tick_consumed", consumed_callback):
				resource.connect("gather_tick_consumed", consumed_callback)

		if resource.has_signal("gather_tick_replenished"):
			var replenished_callback := Callable(self, "_on_resource_state_changed").bind(resource)
			if not resource.is_connected("gather_tick_replenished", replenished_callback):
				resource.connect("gather_tick_replenished", replenished_callback)


func _connect_mob_state_sources() -> void:
	if not is_inside_tree():
		return

	for mob in get_tree().get_nodes_in_group("network_mobs"):
		var health := _mob_health(mob)
		if health != null and health.has_signal("health_changed"):
			var health_callback := Callable(self, "_on_mob_health_changed").bind(mob)
			if not health.is_connected("health_changed", health_callback):
				health.connect("health_changed", health_callback)

		var ai := _mob_ai(mob)
		if ai != null and ai.has_signal("attack_landed"):
			var attack_callback := Callable(self, "_on_local_mob_attack_landed").bind(mob)
			if not ai.is_connected("attack_landed", attack_callback):
				ai.connect("attack_landed", attack_callback)


func _on_local_gathering_completed(resource: Node, _item_id: String, _quantity_added: int) -> void:
	if resource == null or not resource.has_method("get_remaining_ticks"):
		return
	if multiplayer.is_server() or not _client_playtest_code_accepted:
		return

	var resource_path := _state_path_for_node(resource)
	if resource_path.is_empty():
		return

	var remaining_ticks := int(resource.call("get_remaining_ticks"))
	var max_ticks := int(resource.call("get_max_ticks")) if resource.has_method("get_max_ticks") else remaining_ticks
	rpc_id(1, "_server_receive_resource_state", resource_path, remaining_ticks, max_ticks)


func _on_local_attack_landed(target: Node, damage: float) -> void:
	var mob := _networked_mob_from_target(target)
	if mob == null:
		return

	var mob_path := _state_path_for_node(mob)
	if mob_path.is_empty():
		return

	if multiplayer.is_server():
		_broadcast_mob_combat_event(multiplayer.get_unique_id(), mob, maxf(damage, 0.0))
		return
	if not _client_playtest_code_accepted:
		return

	rpc_id(1, "_server_receive_mob_damage", mob_path, maxf(damage, 0.0))


func _on_local_mob_attack_landed(_target: Node, _damage: float, mob: Node) -> void:
	if mob == null:
		return

	var mob_path := _state_path_for_node(mob)
	if mob_path.is_empty():
		return

	var ai := _mob_ai(mob)
	var speed_scale := float(ai.get("attack_speed")) if ai != null else 1.0
	if multiplayer.is_server():
		_broadcast_mob_attack_event(multiplayer.get_unique_id(), mob, speed_scale)
		return
	if not _client_playtest_code_accepted:
		return

	rpc_id(1, "_server_receive_mob_attack_event", mob_path, speed_scale)


func _on_resource_state_changed(_remaining_ticks: int, _max_ticks: int, resource: Node) -> void:
	if not multiplayer.is_server() or not _is_network_active():
		return

	_broadcast_resource_state(resource)


func _on_mob_health_changed(current_health: float, max_health: float, _health_ratio: float, mob: Node) -> void:
	if not multiplayer.is_server() or not _is_network_active():
		return

	_broadcast_mob_state(mob, current_health, max_health)


func _broadcast_resource_state(resource: Node) -> void:
	if resource == null or not resource.has_method("get_remaining_ticks"):
		return

	var resource_path := _state_path_for_node(resource)
	if resource_path.is_empty():
		return

	var remaining_ticks := int(resource.call("get_remaining_ticks"))
	var max_ticks := int(resource.call("get_max_ticks")) if resource.has_method("get_max_ticks") else remaining_ticks
	rpc("_client_receive_resource_state", resource_path, remaining_ticks, max_ticks)


func _broadcast_mob_state(mob: Node, current_health: float, max_health: float) -> void:
	var mob_path := _state_path_for_node(mob)
	if mob_path.is_empty():
		return

	rpc("_client_receive_mob_state", mob_path, current_health, max_health)


func _broadcast_mob_combat_event(attacker_peer_id: int, mob: Node, damage: float) -> void:
	var health := _mob_health(mob)
	if health == null:
		return

	var mob_path := _state_path_for_node(mob)
	if mob_path.is_empty():
		return

	var current_health := float(health.get("current_health"))
	var max_health := float(health.get("max_health"))
	rpc("_client_receive_mob_combat_event", attacker_peer_id, mob_path, damage, current_health, max_health)


func _broadcast_mob_motion_state(
	controller_peer_id: int,
	mob: Node,
	position: Vector3,
	visual_yaw: float,
	is_moving: bool
) -> void:
	var mob_path := _state_path_for_node(mob)
	if mob_path.is_empty():
		return

	rpc("_client_receive_mob_motion_state", controller_peer_id, mob_path, position, visual_yaw, is_moving)


func _broadcast_mob_attack_event(controller_peer_id: int, mob: Node, speed_scale: float) -> void:
	var mob_path := _state_path_for_node(mob)
	if mob_path.is_empty():
		return

	rpc("_client_receive_mob_attack_event", controller_peer_id, mob_path, maxf(speed_scale, 0.01))


func _send_world_state_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or not _is_network_active() or peer_id <= 0:
		return
	if not _is_peer_authorized(peer_id):
		return

	for resource in get_tree().get_nodes_in_group("gatherable_resources"):
		if resource == null or not resource.has_method("get_remaining_ticks"):
			continue

		var resource_path := _state_path_for_node(resource)
		if resource_path.is_empty():
			continue

		var remaining_ticks := int(resource.call("get_remaining_ticks"))
		var max_ticks := int(resource.call("get_max_ticks")) if resource.has_method("get_max_ticks") else remaining_ticks
		rpc_id(peer_id, "_client_receive_resource_state", resource_path, remaining_ticks, max_ticks)

	for mob in get_tree().get_nodes_in_group("network_mobs"):
		var health := _mob_health(mob)
		if health == null:
			continue

		var mob_path := _state_path_for_node(mob)
		if mob_path.is_empty():
			continue

		rpc_id(
			peer_id,
			"_client_receive_mob_state",
			mob_path,
			float(health.get("current_health")),
			float(health.get("max_health"))
		)
		var ai := _mob_ai(mob)
		if ai != null and ai.has_method("get_network_state"):
			var state: Dictionary = ai.call("get_network_state")
			rpc_id(
				peer_id,
				"_client_receive_mob_motion_state",
				multiplayer.get_unique_id(),
				mob_path,
				state.get("position", Vector3.ZERO) as Vector3,
				float(state.get("visual_yaw", 0.0)),
				bool(state.get("is_moving", false))
			)


func _apply_mob_health_state(
	mob_path: String,
	current_health: float,
	max_health: float,
	emit_damage: bool
) -> void:
	var mob := _node_from_state_path(mob_path)
	var health := _mob_health(mob)
	if health == null or not health.has_method("set_current_health"):
		return

	var clean_max_health := maxf(max_health, 1.0)
	var clean_current_health := clampf(current_health, 0.0, clean_max_health)
	var was_defeated := (
		health.has_method("is_defeated")
		and bool(health.call("is_defeated"))
	)
	health.set("max_health", clean_max_health)

	var ai := _mob_ai(mob)
	if clean_current_health <= 0.0 and not was_defeated and ai != null and ai.has_method("suppress_next_network_loot_drop"):
		ai.call("suppress_next_network_loot_drop")

	health.call("set_current_health", clean_current_health, emit_damage)
	if clean_current_health > 0.0 and ai != null and ai.has_method("apply_network_alive_state"):
		ai.call("apply_network_alive_state")


func _apply_mob_motion_state(mob_path: String, position: Vector3, visual_yaw: float, is_moving: bool) -> void:
	var mob := _node_from_state_path(mob_path)
	var ai := _mob_ai(mob)
	if ai != null and ai.has_method("apply_network_motion_state"):
		ai.call("apply_network_motion_state", position, visual_yaw, is_moving)
		return

	var mob_3d := mob as Node3D
	if mob_3d == null:
		return

	mob_3d.global_position = position
	var visuals := mob_3d.get_node_or_null("Visuals") as Node3D
	if visuals != null:
		visuals.global_rotation.y = visual_yaw
	var animation := mob_3d.get_node_or_null("Animation")
	if animation != null and animation.has_method("set_moving"):
		animation.call("set_moving", is_moving)


func _play_mob_attack(mob_path: String, speed_scale: float) -> void:
	var mob := _node_from_state_path(mob_path)
	var ai := _mob_ai(mob)
	if ai != null and ai.has_method("play_network_attack"):
		ai.call("play_network_attack", maxf(speed_scale, 0.01))
		return

	var animation := mob.get_node_or_null("Animation") if mob != null else null
	if animation != null and animation.has_method("play_attack"):
		animation.call("play_attack", maxf(speed_scale, 0.01))


func _emit_mob_damage_feedback(mob_path: String, damage: float) -> void:
	if damage <= 0.0:
		return

	var mob := _node_from_state_path(mob_path)
	var health := _mob_health(mob)
	if health == null or not health.has_signal("damage_taken"):
		return

	health.emit_signal("damage_taken", damage)


func _play_remote_attack_for_peer(peer_id: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	if not _remote_players.has(peer_id):
		return

	var remote_player := _remote_players[peer_id] as Node
	if remote_player != null and is_instance_valid(remote_player) and remote_player.has_method("play_remote_attack"):
		remote_player.call("play_remote_attack")


func _state_path_for_node(node: Node) -> String:
	var scene := get_tree().current_scene
	if scene == null or node == null:
		return ""
	if node == scene:
		return "."
	if not _is_node_in_subtree(scene, node):
		return ""

	return String(scene.get_path_to(node))


func _node_from_state_path(path: String) -> Node:
	var scene := get_tree().current_scene
	var clean_path := path.strip_edges()
	if scene == null or clean_path.is_empty():
		return null
	if clean_path == ".":
		return scene

	return scene.get_node_or_null(NodePath(clean_path))


func _is_node_in_subtree(root: Node, node: Node) -> bool:
	var current := node
	while current != null:
		if current == root:
			return true
		current = current.get_parent()

	return false


func _networked_mob_from_target(target: Node) -> Node:
	var current := target
	while current != null:
		if current.is_in_group("network_mobs"):
			return current
		current = current.get_parent()

	return null


func _mob_health(mob: Node) -> Node:
	if mob == null:
		return null
	if mob.has_method("apply_damage"):
		return mob

	return mob.get_node_or_null("Health")


func _mob_ai(mob: Node) -> Node:
	if mob == null:
		return null

	return mob.get_node_or_null("AI")


func _apply_remote_player_state(
	peer_id: int,
	position: Vector3,
	visual_yaw: float,
	is_moving: bool,
	player_name: String,
	action_state: String = "",
	action_context: Dictionary = {}
) -> void:
	var remote_player := _get_or_create_remote_player(peer_id, player_name)
	if remote_player == null:
		return

	if remote_player.has_method("apply_remote_network_state"):
		remote_player.call("apply_remote_network_state", position, visual_yaw, is_moving, action_state, action_context)


func _get_or_create_remote_player(peer_id: int, player_name: String) -> Node3D:
	if _remote_players.has(peer_id):
		var existing_player := _remote_players[peer_id] as Node3D
		if existing_player != null and is_instance_valid(existing_player):
			_update_remote_player_name(existing_player, peer_id, player_name)
			return existing_player

	var parent := _get_remote_players_root()
	if parent == null:
		return null

	var remote_player := PLAYER_SCENE.instantiate() as Node3D
	remote_player.name = "RemotePlayer_%d" % peer_id
	remote_player.set("is_local_player", false)
	remote_player.set("input_enabled", false)
	parent.add_child(remote_player)
	if remote_player.has_method("configure_as_remote_player"):
		remote_player.call("configure_as_remote_player", peer_id, player_name)
	_remote_players[peer_id] = remote_player
	return remote_player


func _update_remote_player_name(remote_player: Node3D, peer_id: int, player_name: String) -> void:
	if remote_player.has_method("configure_as_remote_player"):
		remote_player.call("configure_as_remote_player", peer_id, player_name)


func _remove_remote_player(peer_id: int) -> void:
	if not _remote_players.has(peer_id):
		return

	var remote_player := _remote_players[peer_id] as Node
	_remote_players.erase(peer_id)
	if remote_player != null and is_instance_valid(remote_player):
		remote_player.queue_free()


func _clear_remote_players() -> void:
	for peer_id in _remote_players.keys():
		var remote_player := _remote_players[peer_id] as Node
		if remote_player != null and is_instance_valid(remote_player):
			remote_player.queue_free()
	_remote_players.clear()


func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		if not _server_requires_client_handshake():
			_authorized_peers[peer_id] = true
			call_deferred("_send_world_state_to_peer", peer_id)
		if _is_command_line_server:
			_set_status("Peer %d joined%s." % [peer_id, "" if not _server_requires_client_handshake() else " and is awaiting access check"])
		else:
			_set_status("Hosting. Peer %d joined%s." % [peer_id, "" if not _server_requires_client_handshake() else " and is awaiting access check"])


func _on_peer_disconnected(peer_id: int) -> void:
	_remove_remote_player(peer_id)
	_authorized_peers.erase(peer_id)
	if multiplayer.is_server():
		rpc("_client_remove_remote_player", peer_id)
		if _is_command_line_server:
			_set_status("Peer %d left." % peer_id)
		else:
			_set_status("Hosting. Peer %d left." % peer_id)


func _on_connected_to_server() -> void:
	_apply_local_player_name()
	_set_status("Connected as peer %d. Checking playtest code..." % multiplayer.get_unique_id())
	_submit_playtest_code_to_server()


func _on_connection_failed() -> void:
	_clear_remote_players()
	_client_playtest_code_accepted = false
	_set_status("Connection failed")


func _on_server_disconnected() -> void:
	_clear_remote_players()
	_client_playtest_code_accepted = false
	_set_status("Server disconnected")


func _is_network_active() -> bool:
	return (
		_peer != null
		and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	)


func _is_network_connecting_or_active() -> bool:
	if _peer == null:
		return false

	var status := _peer.get_connection_status()
	return (
		status == MultiplayerPeer.CONNECTION_CONNECTING
		or status == MultiplayerPeer.CONNECTION_CONNECTED
	)


func _get_local_player() -> Node3D:
	return get_node_or_null(local_player_path) as Node3D


func _ensure_remote_players_root() -> void:
	if _get_remote_players_root() != null:
		return

	var world := get_node_or_null("../World")
	if world == null:
		return

	var remote_players := Node3D.new()
	remote_players.name = "RemotePlayers"
	world.add_child(remote_players)


func _get_remote_players_root() -> Node3D:
	if remote_players_path != NodePath(""):
		var configured_root := get_node_or_null(remote_players_path) as Node3D
		if configured_root != null:
			return configured_root

	return null


func _build_test_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "MultiplayerTestCanvas"
	canvas.layer = 80
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.name = "MultiplayerTestPanel"
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	panel.visible = test_panel_starts_visible
	canvas.add_child(panel)
	_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Multiplayer Test (F9)"
	rows.add_child(title)

	_name_field = _add_line_edit_row(rows, "Name", _initial_local_player_name())
	_address_field = _add_line_edit_row(rows, "IP", _configured_playtest_address())
	_port_field = _add_line_edit_row(rows, "Port", str(_configured_playtest_port()))
	_code_field = _add_line_edit_row(rows, "Code", "", true)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	rows.add_child(buttons)

	var host_button := Button.new()
	host_button.text = "Host"
	host_button.pressed.connect(_on_host_pressed)
	buttons.add_child(host_button)

	var join_button := Button.new()
	join_button.text = "Join"
	join_button.pressed.connect(_on_join_pressed)
	buttons.add_child(join_button)

	var disconnect_button := Button.new()
	disconnect_button.text = "Disconnect"
	disconnect_button.pressed.connect(disconnect_from_session)
	buttons.add_child(disconnect_button)

	var hide_button := Button.new()
	hide_button.text = "Hide"
	hide_button.pressed.connect(_hide_panel)
	buttons.add_child(hide_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_status_label)


func _add_line_edit_row(parent: Control, label_text: String, value: String, is_secret: bool = false) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(44.0, 0.0)
	row.add_child(label)

	var field := LineEdit.new()
	field.text = value
	field.secret = is_secret
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return field


func _on_host_pressed() -> void:
	host(_configured_port())


func _on_join_pressed() -> void:
	join(_address_field.text if _address_field != null else "127.0.0.1", _configured_port())


func _hide_panel() -> void:
	if _panel != null:
		_panel.visible = false


func _configured_port() -> int:
	if _port_field == null:
		return default_port

	var parsed_port := int(_port_field.text)
	return clampi(parsed_port, 1024, 65535)


func _apply_local_player_name() -> void:
	var local_player := _get_local_player()
	if local_player == null:
		return

	var nameplate := local_player.get_node_or_null("Nameplate")
	if nameplate != null and nameplate.has_method("set_player_name"):
		nameplate.call("set_player_name", _local_player_name())


func _local_player_name() -> String:
	var from_field := _name_field.text.strip_edges() if _name_field != null else ""
	if not from_field.is_empty():
		return from_field

	return _initial_local_player_name()


func _initial_local_player_name() -> String:
	var local_player := _get_local_player()
	var nameplate := local_player.get_node_or_null("Nameplate") if local_player != null else null
	if nameplate != null:
		var configured_name := String(nameplate.get("player_name")).strip_edges()
		if not configured_name.is_empty():
			return configured_name

	return fallback_player_name


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
	if _is_command_line_server:
		print("[Network] %s" % message)


func _update_auto_join_retry(delta: float) -> void:
	if _is_command_line_server:
		return
	if not auto_join_from_auth_session:
		return
	if _is_network_connecting_or_active():
		return
	if _auto_join_elapsed >= auto_join_retry_duration:
		return

	_auto_join_elapsed += maxf(delta, 0.0)
	_auto_join_interval_elapsed += maxf(delta, 0.0)
	if _auto_join_interval_elapsed < auto_join_retry_interval:
		return

	_auto_join_interval_elapsed = 0.0
	_try_auto_join_from_auth_session()


func _try_auto_join_from_auth_session() -> void:
	if not auto_join_from_auth_session:
		return
	if _is_network_connecting_or_active():
		return

	var auth_session := get_node_or_null("/root/PrototypeAuthSession")
	if auth_session == null:
		return
	if not bool(auth_session.get("is_signed_in")):
		return
	if not bool(auth_session.get("auto_join_server")):
		return

	var address := String(auth_session.get("server_address")).strip_edges()
	var port := int(auth_session.get("server_port"))
	if address.is_empty():
		address = "127.0.0.1"

	_sync_test_panel_target(address, port)
	join(address, clampi(port, 1024, 65535))


func _submit_playtest_code_to_server() -> void:
	if multiplayer.is_server():
		_client_playtest_code_accepted = true
		return

	var code_hash := _configured_client_playtest_code_hash()
	var build_metadata := _client_build_metadata()
	rpc_id(
		1,
		"_server_submit_playtest_code",
		code_hash,
		_local_player_name(),
		String(build_metadata.get("build_id", "")),
		String(build_metadata.get("commit", ""))
	)


func _is_peer_authorized(peer_id: int) -> bool:
	if not _server_requires_client_handshake():
		return true

	return bool(_authorized_peers.get(peer_id, false))


func _server_requires_client_handshake() -> bool:
	return _server_requires_playtest_code() or _server_requires_client_version_gate()


func _server_requires_playtest_code() -> bool:
	return require_playtest_code or not playtest_access_code_hash.strip_edges().is_empty()


func _server_requires_client_version_gate() -> bool:
	return (
		maintenance_mode
		or not required_client_build_id.strip_edges().is_empty()
		or not required_client_commit.strip_edges().is_empty()
	)


func _is_playtest_code_accepted(received_hash: String) -> bool:
	var expected_hash := playtest_access_code_hash.strip_edges().to_lower()
	if expected_hash.is_empty():
		return not require_playtest_code

	return received_hash.strip_edges().to_lower() == expected_hash


func _server_client_version_result(client_build_id: String, client_commit: String) -> Dictionary:
	if maintenance_mode:
		var clean_message := maintenance_message.strip_edges()
		if clean_message.is_empty():
			clean_message = "Server maintenance is active. Please update and try again soon."
		return {
			"accepted": false,
			"message": clean_message,
		}

	var required_build := required_client_build_id.strip_edges()
	var clean_build := client_build_id.strip_edges()
	if not required_build.is_empty() and clean_build != required_build:
		return {
			"accepted": false,
			"message": "Update required. Restart the launcher to install the current playtest build.",
		}

	var required_commit := required_client_commit.strip_edges()
	var clean_commit := client_commit.strip_edges()
	if required_build.is_empty() and not required_commit.is_empty() and clean_commit != required_commit:
		return {
			"accepted": false,
			"message": "Update required. Restart the launcher to install the current playtest build.",
		}

	return {
		"accepted": true,
		"message": "",
	}


func _client_build_metadata() -> Dictionary:
	for version_path in _playtest_version_paths():
		if not FileAccess.file_exists(version_path):
			continue

		var file := FileAccess.open(version_path, FileAccess.READ)
		if file == null:
			continue

		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			return parsed as Dictionary

	return {}


func _configured_client_playtest_code_hash() -> String:
	var field_hash := _hash_playtest_code(_code_field.text if _code_field != null else "")
	if not field_hash.is_empty():
		return field_hash

	var auth_session := get_node_or_null("/root/PrototypeAuthSession")
	if auth_session != null:
		var session_hash := String(auth_session.get("playtest_access_code_hash")).strip_edges().to_lower()
		if not session_hash.is_empty():
			return session_hash

	var command_line_hash := _command_line_playtest_code_hash()
	if not command_line_hash.is_empty():
		return command_line_hash

	return ""


func _hash_playtest_code(raw_code: String) -> String:
	var clean_code := raw_code.strip_edges()
	if clean_code.is_empty():
		return ""

	return clean_code.sha256_text().to_lower()


func _configure_command_line_server_runtime() -> void:
	var local_player := _get_local_player()
	if local_player != null:
		local_player.visible = false
		local_player.process_mode = Node.PROCESS_MODE_DISABLED
		local_player.remove_from_group("player")
		local_player.add_to_group("server_only_player")

	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_disable_input = true


func _apply_sidecar_playtest_security() -> void:
	for config_path in _playtest_config_paths():
		var config := ConfigFile.new()
		var error := config.load(config_path)
		if error != OK:
			continue

		require_playtest_code = bool(config.get_value("playtest", "require_code", require_playtest_code))
		playtest_access_code_hash = String(
			config.get_value("playtest", "access_code_hash", playtest_access_code_hash)
		).strip_edges().to_lower()
		maintenance_mode = bool(config.get_value("version_gate", "maintenance", maintenance_mode))
		maintenance_message = String(
			config.get_value("version_gate", "maintenance_message", maintenance_message)
		).strip_edges()
		required_client_build_id = String(
			config.get_value("version_gate", "required_build_id", required_client_build_id)
		).strip_edges()
		required_client_commit = String(
			config.get_value("version_gate", "required_commit", required_client_commit)
		).strip_edges()
		return


func _apply_command_line_playtest_security() -> void:
	for argument in _all_command_line_arguments():
		var clean_argument := argument.strip_edges()
		var normalized_argument := clean_argument.to_lower()
		if normalized_argument.begins_with("--playtest-code-hash="):
			playtest_access_code_hash = clean_argument.get_slice("=", 1).strip_edges().to_lower()
			require_playtest_code = true
		elif normalized_argument.begins_with("--playtest-code="):
			playtest_access_code_hash = _hash_playtest_code(clean_argument.get_slice("=", 1))
			require_playtest_code = true
		elif normalized_argument.begins_with("--playtest-code-required="):
			require_playtest_code = _parse_bool(clean_argument.get_slice("=", 1), require_playtest_code)
		elif normalized_argument.begins_with("--maintenance="):
			maintenance_mode = _parse_bool(clean_argument.get_slice("=", 1), maintenance_mode)
		elif normalized_argument.begins_with("--maintenance-message="):
			maintenance_message = clean_argument.get_slice("=", 1).strip_edges()
		elif normalized_argument.begins_with("--required-build-id="):
			required_client_build_id = clean_argument.get_slice("=", 1).strip_edges()
		elif normalized_argument.begins_with("--required-client-build="):
			required_client_build_id = clean_argument.get_slice("=", 1).strip_edges()
		elif normalized_argument.begins_with("--required-commit="):
			required_client_commit = clean_argument.get_slice("=", 1).strip_edges()


func _command_line_playtest_code_hash() -> String:
	for argument in _all_command_line_arguments():
		var clean_argument := argument.strip_edges()
		var normalized_argument := clean_argument.to_lower()
		if normalized_argument.begins_with("--playtest-code-hash="):
			return clean_argument.get_slice("=", 1).strip_edges().to_lower()
		if normalized_argument.begins_with("--playtest-code="):
			return _hash_playtest_code(clean_argument.get_slice("=", 1))

	return ""


func _playtest_config_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	paths.append("res://%s" % PLAYTEST_CONFIG_FILE)

	var executable_path := OS.get_executable_path()
	var executable_dir := executable_path.get_base_dir()
	if not executable_dir.is_empty():
		paths.append(executable_dir.path_join(PLAYTEST_CONFIG_FILE))

	return paths


func _playtest_version_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	paths.append("res://%s" % PLAYTEST_VERSION_FILE)

	var executable_path := OS.get_executable_path()
	var executable_dir := executable_path.get_base_dir()
	if not executable_dir.is_empty():
		paths.append(executable_dir.path_join(PLAYTEST_VERSION_FILE))

	return paths


func _has_command_line_server_flag() -> bool:
	for argument in _all_command_line_arguments():
		var normalized_argument := argument.strip_edges().to_lower()
		if normalized_argument == "--server" or normalized_argument == "--dedicated-server":
			return true

	return false


func _command_line_port() -> int:
	for argument in _all_command_line_arguments():
		var normalized_argument := argument.strip_edges().to_lower()
		if normalized_argument.begins_with("--port="):
			return clampi(int(normalized_argument.trim_prefix("--port=")), 1024, 65535)

	return default_port


func _configured_playtest_address() -> String:
	var command_line_address := _command_line_connect_address()
	if not command_line_address.is_empty():
		return command_line_address

	var auth_session := get_node_or_null("/root/PrototypeAuthSession")
	if auth_session != null:
		var session_address := String(auth_session.get("server_address")).strip_edges()
		if not session_address.is_empty():
			return session_address

	return "127.0.0.1"


func _configured_playtest_port() -> int:
	var command_line_port := _command_line_connect_port()
	if command_line_port >= 0:
		return command_line_port

	var auth_session := get_node_or_null("/root/PrototypeAuthSession")
	if auth_session != null:
		var session_port := int(auth_session.get("server_port"))
		return clampi(session_port, 1024, 65535)

	return default_port


func _sync_test_panel_target(address: String, port: int) -> void:
	if _address_field != null:
		_address_field.text = address
	if _port_field != null:
		_port_field.text = str(clampi(port, 1024, 65535))


func _command_line_connect_address() -> String:
	var connect_target := _command_line_connect_target()
	if connect_target.is_empty():
		return ""

	return _address_from_connect_target(connect_target)


func _command_line_connect_port() -> int:
	for argument in _all_command_line_arguments():
		var clean_argument := argument.strip_edges()
		var normalized_argument := clean_argument.to_lower()
		if normalized_argument.begins_with("--connect-port="):
			return _parse_port(clean_argument.get_slice("=", 1), -1)
		if normalized_argument.begins_with("--playtest-port="):
			return _parse_port(clean_argument.get_slice("=", 1), -1)

	var connect_target := _command_line_connect_target()
	if connect_target.is_empty():
		return -1

	return _port_from_connect_target(connect_target, -1)


func _command_line_connect_target() -> String:
	for argument in _all_command_line_arguments():
		var clean_argument := argument.strip_edges()
		var normalized_argument := clean_argument.to_lower()
		if normalized_argument.begins_with("--connect="):
			return clean_argument.get_slice("=", 1).strip_edges()
		if normalized_argument.begins_with("--playtest-server="):
			return clean_argument.get_slice("=", 1).strip_edges()

	return ""


func _address_from_connect_target(raw_value: String) -> String:
	var clean_value := raw_value.strip_edges()
	var separator_index := clean_value.rfind(":")
	if separator_index > 0 and separator_index < clean_value.length() - 1:
		return clean_value.substr(0, separator_index)

	return clean_value


func _port_from_connect_target(raw_value: String, fallback: int) -> int:
	var clean_value := raw_value.strip_edges()
	var separator_index := clean_value.rfind(":")
	if separator_index <= 0 or separator_index >= clean_value.length() - 1:
		return fallback

	return _parse_port(clean_value.substr(separator_index + 1), fallback)


func _parse_port(raw_value: String, fallback: int) -> int:
	var clean_value := raw_value.strip_edges()
	if not clean_value.is_valid_int():
		return fallback

	return clampi(int(clean_value), 1024, 65535)


func _parse_bool(raw_value: String, fallback: bool) -> bool:
	var normalized_value := raw_value.strip_edges().to_lower()
	if normalized_value in ["true", "1", "yes", "y", "on"]:
		return true
	if normalized_value in ["false", "0", "no", "n", "off"]:
		return false

	return fallback


func _all_command_line_arguments() -> PackedStringArray:
	var arguments := PackedStringArray()
	arguments.append_array(OS.get_cmdline_args())
	arguments.append_array(OS.get_cmdline_user_args())
	return arguments
