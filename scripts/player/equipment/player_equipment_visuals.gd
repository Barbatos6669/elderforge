## Mirrors equipped inventory items into visible character socket prefabs.
##
## The professional pattern is intentionally simple:
## - character owns named EquipmentSocket3D nodes,
## - item data points at an equipment scene,
## - optional attachment profiles provide item-specific local offsets,
## - this script spawns/clears the right scene under the right socket.
class_name PlayerEquipmentVisuals
extends Node

const EQUIPMENT_SOCKET_SCRIPT_PATH := "res://scripts/player/equipment/equipment_socket_3d.gd"
const EquipmentSocketScript := preload(EQUIPMENT_SOCKET_SCRIPT_PATH)

## Optional inventory node. Main.tscn points this at the local PlayerInventory.
@export var inventory_path: NodePath
## Root searched for EquipmentSocket3D nodes.
@export var socket_root_path: NodePath = NodePath("../Visuals/BaseCharacter/Armature/Skeleton3D")
## Keeps editor tuning previews from appearing as free gear during play.
@export var hide_socket_previews_at_runtime := true
## Copies preview transforms to live equipment while a preview-driven socket is equipped.
@export var live_sync_preview_sockets := true

var _inventory: Node
var _sockets_by_slot := {}
var _instances_by_slot := {}
var _scene_paths_by_slot := {}
var _profile_paths_by_slot := {}
var _last_socket_transforms := {}


func _ready() -> void:
	call_deferred("_initialize")


func _process(_delta: float) -> void:
	if live_sync_preview_sockets:
		_sync_preview_driven_slots()


## Allows scenes/tests to bind an inventory directly without relying on groups.
func set_inventory(inventory: Node) -> void:
	if _inventory == inventory:
		return

	_disconnect_inventory()
	_inventory = inventory
	_connect_inventory()
	_refresh_equipment()


func _initialize() -> void:
	_collect_sockets()
	_hide_socket_previews()
	_bind_inventory()


func _bind_inventory() -> void:
	if _inventory != null:
		return

	var inventory := _inventory_from_path()
	if inventory == null:
		inventory = get_tree().get_first_node_in_group("player_inventory")
	set_inventory(inventory)


func _inventory_from_path() -> Node:
	if inventory_path.is_empty():
		return null

	return get_node_or_null(inventory_path)


func _connect_inventory() -> void:
	if _inventory == null or not _inventory.has_signal("equipped_slots_changed"):
		return

	var refresh_callable := Callable(self, "_refresh_equipment")
	if not _inventory.is_connected("equipped_slots_changed", refresh_callable):
		_inventory.connect("equipped_slots_changed", refresh_callable)


func _disconnect_inventory() -> void:
	if _inventory == null or not _inventory.has_signal("equipped_slots_changed"):
		return

	var refresh_callable := Callable(self, "_refresh_equipment")
	if _inventory.is_connected("equipped_slots_changed", refresh_callable):
		_inventory.disconnect("equipped_slots_changed", refresh_callable)


func _collect_sockets() -> void:
	_sockets_by_slot.clear()
	var socket_root := get_node_or_null(socket_root_path)
	if socket_root == null:
		push_warning("Could not find equipment socket root at %s." % socket_root_path)
		return

	_collect_sockets_recursive(socket_root)


func _collect_sockets_recursive(node: Node) -> void:
	if _is_equipment_socket(node):
		var slot_id := String(node.get("slot_id"))
		if not slot_id.is_empty():
			_sockets_by_slot[slot_id] = node

	for child in node.get_children():
		_collect_sockets_recursive(child)


func _is_equipment_socket(node: Node) -> bool:
	if node == null:
		return false
	if node.has_method("get_item_transform") and node.has_method("hide_runtime_preview") and node.has_method("get_preview"):
		return true

	var script := node.get_script() as Script
	return script != null and script.resource_path == EQUIPMENT_SOCKET_SCRIPT_PATH


func _hide_socket_previews() -> void:
	if not hide_socket_previews_at_runtime:
		return

	for slot_id in _sockets_by_slot:
		var socket := _sockets_by_slot[slot_id] as Node
		if socket != null and socket.has_method("hide_runtime_preview"):
			socket.call("hide_runtime_preview")


func _refresh_equipment() -> void:
	if _inventory == null or not _inventory.has_method("get_equipped_slots"):
		_clear_all_slots()
		return

	var equipped_slots := _inventory.call("get_equipped_slots") as Dictionary
	if equipped_slots == null:
		_clear_all_slots()
		return

	for slot_id in _sockets_by_slot.keys():
		var slot_data := equipped_slots.get(slot_id, {}) as Dictionary
		if slot_data == null or slot_data.is_empty():
			_clear_slot(String(slot_id))
		else:
			_set_slot_scene(String(slot_id), slot_data)


func _set_slot_scene(slot_id: String, slot_data: Dictionary) -> void:
	var scene_path := String(slot_data.get("equipment_scene_path", ""))
	var profile_path := String(slot_data.get("equipment_attachment_profile_path", ""))
	if scene_path.is_empty():
		_clear_slot(slot_id)
		return

	if (
		_instances_by_slot.has(slot_id)
		and String(_scene_paths_by_slot.get(slot_id, "")) == scene_path
		and String(_profile_paths_by_slot.get(slot_id, "")) == profile_path
	):
		_apply_item_display_data(slot_id, slot_data)
		_apply_slot_transform(slot_id)
		return

	_clear_slot(slot_id)
	var socket := _sockets_by_slot.get(slot_id) as Node3D
	if socket == null:
		push_warning("No equipment socket found for slot '%s'." % slot_id)
		return
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("Equipped item scene does not exist: %s" % scene_path)
		return

	var packed_scene := load(scene_path) as PackedScene
	var instance := packed_scene.instantiate() as Node3D if packed_scene != null else null
	if instance == null:
		push_warning("Equipped item scene root must be a Node3D: %s" % scene_path)
		return

	instance.name = _equipment_instance_name(slot_id)
	socket.add_child(instance)
	_instances_by_slot[slot_id] = instance
	_scene_paths_by_slot[slot_id] = scene_path
	_profile_paths_by_slot[slot_id] = profile_path
	_apply_item_display_data(slot_id, slot_data)
	_apply_slot_transform(slot_id)


func _apply_item_display_data(slot_id: String, slot_data: Dictionary) -> void:
	var instance := _instances_by_slot.get(slot_id) as Node
	if instance != null and instance.has_method("apply_equipment_display_data"):
		instance.call("apply_equipment_display_data", slot_data)


func _apply_slot_transform(slot_id: String) -> void:
	var instance := _instances_by_slot.get(slot_id) as Node3D
	var socket := _sockets_by_slot.get(slot_id) as Node
	if instance == null or socket == null:
		return

	var profile := _load_attachment_profile(String(_profile_paths_by_slot.get(slot_id, "")))
	if socket.has_method("get_item_transform"):
		instance.transform = socket.call("get_item_transform", profile)
	else:
		instance.transform = profile.call("to_transform") if profile != null and profile.has_method("to_transform") else Transform3D.IDENTITY
	_last_socket_transforms[slot_id] = instance.transform


func _sync_preview_driven_slots() -> void:
	for slot_id in _instances_by_slot.keys():
		var socket := _sockets_by_slot.get(slot_id) as Node
		if socket == null or not socket.has_method("should_live_sync_preview"):
			continue
		if not bool(socket.call("should_live_sync_preview")):
			continue

		var instance := _instances_by_slot.get(slot_id) as Node3D
		if instance == null:
			continue

		var next_transform: Transform3D = socket.call("get_item_transform", _load_attachment_profile(String(_profile_paths_by_slot.get(slot_id, ""))))
		if next_transform == _last_socket_transforms.get(slot_id, Transform3D()):
			continue

		instance.transform = next_transform
		_last_socket_transforms[slot_id] = next_transform


func _clear_all_slots() -> void:
	for slot_id in _instances_by_slot.keys():
		_clear_slot(String(slot_id))


func _clear_slot(slot_id: String) -> void:
	var instance := _instances_by_slot.get(slot_id) as Node3D
	if instance == null:
		return

	_remember_socket_transform(slot_id, instance)
	var parent := instance.get_parent()
	if parent != null:
		parent.remove_child(instance)
	instance.queue_free()
	_instances_by_slot.erase(slot_id)
	_scene_paths_by_slot.erase(slot_id)
	_profile_paths_by_slot.erase(slot_id)
	_last_socket_transforms.erase(slot_id)


func _remember_socket_transform(slot_id: String, instance: Node3D) -> void:
	var socket := _sockets_by_slot.get(slot_id) as Node
	if socket == null or not socket.has_method("get_preview"):
		return
	if socket.has_method("should_live_sync_preview") and not bool(socket.call("should_live_sync_preview")):
		return

	var preview := socket.call("get_preview") as Node3D
	if preview != null:
		preview.transform = instance.transform


func _load_attachment_profile(profile_path: String) -> Resource:
	if profile_path.is_empty() or not ResourceLoader.exists(profile_path):
		return null

	return load(profile_path) as Resource


func _equipment_instance_name(slot_id: String) -> String:
	var parts := slot_id.split("_", false)
	var label := ""
	for part in parts:
		label += String(part).capitalize()
	return "%sEquipment" % label
