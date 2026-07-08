## Small direct-connect multiplayer harness for early playtests.
##
## This is intentionally not MMO architecture yet. It lets one player host, a
## friend join by IP, and both clients see each other as remote player copies.
class_name MultiplayerTestManager
extends Node

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const DEFAULT_PORT := 24565

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

var _peer: ENetMultiplayerPeer
var _remote_players := {}
var _send_elapsed := 0.0
var _is_command_line_server := false
var _panel: Control
var _status_label: Label
var _address_field: LineEdit
var _port_field: LineEdit
var _name_field: LineEdit
var _auto_join_elapsed := 0.0
var _auto_join_interval_elapsed := 0.0


func _ready() -> void:
	_connect_multiplayer_signals()
	_ensure_remote_players_root()
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
	_send_elapsed = 0.0
	_apply_local_player_name()
	_set_status("Connecting to %s:%d" % [trimmed_address, port])
	return true


func disconnect_from_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_peer = null
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
func _server_receive_player_state(position: Vector3, visual_yaw: float, is_moving: bool, player_name: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return

	_apply_remote_player_state(sender_id, position, visual_yaw, is_moving, player_name)
	rpc("_client_receive_player_state", sender_id, position, visual_yaw, is_moving, player_name)


@rpc("authority", "unreliable")
func _client_receive_player_state(peer_id: int, position: Vector3, visual_yaw: float, is_moving: bool, player_name: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		return

	_apply_remote_player_state(peer_id, position, visual_yaw, is_moving, player_name)


@rpc("authority", "reliable")
func _client_remove_remote_player(peer_id: int) -> void:
	_remove_remote_player(peer_id)


func _send_local_state() -> void:
	if _is_command_line_server:
		return

	var local_player := _get_local_player()
	if local_player == null or not local_player.has_method("get_network_state"):
		return

	var state: Dictionary = local_player.call("get_network_state")
	var position := state.get("position", local_player.global_position) as Vector3
	var visual_yaw := float(state.get("visual_yaw", 0.0))
	var is_moving := bool(state.get("is_moving", false))
	var player_name := _local_player_name()

	if multiplayer.is_server():
		rpc("_client_receive_player_state", multiplayer.get_unique_id(), position, visual_yaw, is_moving, player_name)
	else:
		rpc_id(1, "_server_receive_player_state", position, visual_yaw, is_moving, player_name)


func _apply_remote_player_state(
	peer_id: int,
	position: Vector3,
	visual_yaw: float,
	is_moving: bool,
	player_name: String
) -> void:
	var remote_player := _get_or_create_remote_player(peer_id, player_name)
	if remote_player == null:
		return

	if remote_player.has_method("apply_remote_network_state"):
		remote_player.call("apply_remote_network_state", position, visual_yaw, is_moving)


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
		if _is_command_line_server:
			_set_status("Peer %d joined." % peer_id)
		else:
			_set_status("Hosting. Peer %d joined." % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_remove_remote_player(peer_id)
	if multiplayer.is_server():
		rpc("_client_remove_remote_player", peer_id)
		if _is_command_line_server:
			_set_status("Peer %d left." % peer_id)
		else:
			_set_status("Hosting. Peer %d left." % peer_id)


func _on_connected_to_server() -> void:
	_apply_local_player_name()
	_set_status("Connected as peer %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	_clear_remote_players()
	_set_status("Connection failed")


func _on_server_disconnected() -> void:
	_clear_remote_players()
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


func _add_line_edit_row(parent: Control, label_text: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(44.0, 0.0)
	row.add_child(label)

	var field := LineEdit.new()
	field.text = value
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


func _all_command_line_arguments() -> PackedStringArray:
	var arguments := PackedStringArray()
	arguments.append_array(OS.get_cmdline_args())
	arguments.append_array(OS.get_cmdline_user_args())
	return arguments
