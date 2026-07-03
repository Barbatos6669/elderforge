## Local-player gathering prototype.
##
## This module owns gather target validation, approach distance, starting the
## channel, and handing completed yields to PlayerInventory. It does not read
## input directly and does not draw UI.
class_name PlayerGathering
extends Node

const MAIN_HAND_SLOT_ID := "main_hand"
const DEFAULT_GATHER_DURATION_MULTIPLIER := 1.0
const RESOURCE_TOOL_FAMILIES := {
	"logs": "axe",
	"stone": "hammer",
	"ore": "pickaxe",
	"cotton": "sickle",
	"hide": "skinning_knife",
}

signal gathering_started(resource: Node)
signal gathering_completed(resource: Node, item_id: String, quantity_added: int)
signal gathering_cancelled

## Maximum horizontal distance from player to resource before channeling starts.
@export var gather_range: float = 0.95
## Desired stopping distance while moving toward a gatherable resource.
@export var approach_distance: float = 0.8
## Optional inventory node. If empty, the first `player_inventory` group member is used.
@export var inventory_path: NodePath
## Equipment slot checked for gathering tools.
@export var required_tool_slot_id := MAIN_HAND_SLOT_ID
## How many tiers above the equipped tool can still be gathered with a penalty.
@export_range(0, 8, 1) var allowed_tiers_above_tool := 1
## Duration multiplier applied when gathering exactly one tier above the equipped tool.
@export_range(1.0, 25.0, 0.25) var one_tier_above_duration_multiplier := 5.0

var _target_resource: Node3D
var _is_waiting_for_channel := false


## Begins a gather attempt against a selected target or its parent resource.
func start_gather(target: Node, gatherer: Node3D) -> bool:
	var resource := _find_gatherable_resource(target)
	if resource == null or not _can_gather(resource):
		return false

	_target_resource = resource
	_is_waiting_for_channel = true
	gathering_started.emit(_target_resource)
	return true


## Cancels pending gathering state. The channel itself is cancelled by PlayerChanneling.
func cancel_gathering() -> void:
	if not has_active_target():
		return

	_clear_gathering_state()
	gathering_cancelled.emit()


func has_active_target() -> bool:
	return _target_resource != null and is_instance_valid(_target_resource)


func is_waiting_for_channel() -> bool:
	return _is_waiting_for_channel and has_active_target()


## Starts the gathering channel if the player is close enough.
func start_channel_if_ready(gatherer: Node3D, channeling: Node) -> bool:
	if not is_waiting_for_channel() or channeling == null:
		return false
	if not is_target_in_range(gatherer):
		return false
	if channeling.has_method("is_channeling") and channeling.call("is_channeling"):
		return false

	var tool_result := _get_gather_tool_result(_target_resource)
	if not bool(tool_result.get("can_gather", false)):
		cancel_gathering()
		return false

	var yield_data: Dictionary = _target_resource.call("get_yield_data")
	var action_name := _gather_action_name(_target_resource, yield_data)
	var duration_multiplier := float(tool_result.get("duration_multiplier", DEFAULT_GATHER_DURATION_MULTIPLIER))
	var duration := float(yield_data.get("gather_duration", 2.0)) * duration_multiplier
	var context := {
		"type": "gathering",
		"target": _target_resource,
		"item_id": String(yield_data.get("item_id", "")),
		"quantity": int(yield_data.get("quantity", 1)),
		"duration_multiplier": duration_multiplier,
		"resource_family_id": String(tool_result.get("resource_family_id", "")),
		"required_tool_family_id": String(tool_result.get("required_tool_family_id", "")),
		"tool_family_id": String(tool_result.get("tool_family_id", "")),
		"tool_animation_profile_path": String(tool_result.get("tool_animation_profile_path", "")),
		"tool_tier": int(tool_result.get("tool_tier", 0)),
		"resource_tier": int(tool_result.get("resource_tier", 0)),
	}
	channeling.call("start_channel", action_name, duration, context)
	_is_waiting_for_channel = false
	return true


## Applies a completed gathering channel to inventory.
func complete_gather(context: Dictionary) -> bool:
	if String(context.get("type", "")) != "gathering":
		return false

	var resource := context.get("target") as Node
	var item_id := String(context.get("item_id", ""))
	var quantity := maxi(int(context.get("quantity", 0)), 0)
	if item_id.is_empty() or quantity <= 0:
		cancel_gathering()
		return false

	var inventory := _find_inventory()
	if inventory == null or not inventory.has_method("add_item"):
		cancel_gathering()
		return false

	var remainder := int(inventory.call("add_item", item_id, quantity))
	var quantity_added := quantity - remainder
	if quantity_added > 0:
		if resource != null and resource.has_method("consume_gather_tick"):
			resource.call("consume_gather_tick")
		gathering_completed.emit(resource, item_id, quantity_added)
	else:
		_clear_gathering_state()
		return false

	if resource != null and _can_gather(resource):
		_target_resource = resource as Node3D
		_is_waiting_for_channel = true
	else:
		_clear_gathering_state()
	return quantity_added > 0


func is_target_in_range(gatherer: Node3D) -> bool:
	if gatherer == null or not has_active_target():
		return false

	var offset := _target_resource.global_position - gatherer.global_position
	offset.y = 0.0
	return offset.length() <= gather_range


## Returns a world destination just outside the resource.
func get_approach_destination(gatherer: Node3D) -> Vector3:
	if gatherer == null or not has_active_target():
		return Vector3.ZERO

	var direction_to_target := get_direction_to_target(gatherer)
	if direction_to_target == Vector3.ZERO:
		return gatherer.global_position

	var destination := _target_resource.global_position - direction_to_target * approach_distance
	destination.y = gatherer.global_position.y
	return destination


func get_direction_to_target(gatherer: Node3D) -> Vector3:
	if gatherer == null or not has_active_target():
		return Vector3.ZERO

	var direction := _target_resource.global_position - gatherer.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return Vector3.ZERO

	return direction.normalized()


func _find_gatherable_resource(target: Node) -> Node3D:
	var current := target
	while current != null:
		if current.has_method("get_yield_data") and current.has_method("can_gather"):
			return current as Node3D
		current = current.get_parent()

	return null


func _can_gather(resource: Node) -> bool:
	if resource == null or not resource.has_method("can_gather") or resource.call("can_gather") != true:
		return false

	return bool(_get_gather_tool_result(resource).get("can_gather", false))


func _clear_gathering_state() -> void:
	_target_resource = null
	_is_waiting_for_channel = false


func _resource_display_name(resource: Node) -> String:
	if resource == null:
		return "Resource"
	var display_name_value: Variant = resource.get("display_name")
	if display_name_value != null and not String(display_name_value).is_empty():
		return String(display_name_value)
	return resource.name


func _gather_action_name(resource: Node, yield_data: Dictionary) -> String:
	var remaining_ticks := int(yield_data.get("remaining_ticks", 1))
	var max_ticks := maxi(int(yield_data.get("max_ticks", remaining_ticks)), 1)
	var visible_remaining_ticks := clampi(remaining_ticks, 1, max_ticks)
	return "Gathering %s %d/%d" % [_resource_display_name(resource), visible_remaining_ticks, max_ticks]


func _get_gather_tool_result(resource: Node) -> Dictionary:
	var yield_data := _get_resource_yield_data(resource)
	var resource_family_id := _get_resource_family_id(resource, yield_data)
	var required_tool_family_id := _required_tool_family_id(resource_family_id)
	var resource_tier := _get_resource_tier(resource, yield_data)
	var result := {
		"can_gather": false,
		"duration_multiplier": DEFAULT_GATHER_DURATION_MULTIPLIER,
		"resource_family_id": resource_family_id,
		"required_tool_family_id": required_tool_family_id,
		"tool_family_id": "",
		"tool_animation_profile_path": "",
		"tool_tier": 0,
		"resource_tier": resource_tier,
		"reason": "",
	}

	if required_tool_family_id.is_empty():
		result["can_gather"] = true
		result["reason"] = "no_required_tool"
		return result

	var equipped_tool := _get_equipped_tool_data()
	if equipped_tool.is_empty():
		result["reason"] = "missing_tool"
		return result

	var tool_family_id := String(equipped_tool.get("family_id", ""))
	var tool_tier := int(equipped_tool.get("tier", 0))
	result["tool_family_id"] = tool_family_id
	result["tool_animation_profile_path"] = String(equipped_tool.get("equipment_animation_profile_path", ""))
	result["tool_tier"] = tool_tier

	if tool_family_id != required_tool_family_id:
		result["reason"] = "wrong_tool_family"
		return result
	if tool_tier <= 0 or resource_tier <= 0:
		result["reason"] = "missing_tier"
		return result

	var tier_delta := resource_tier - tool_tier
	if tier_delta <= 0:
		result["can_gather"] = true
		result["reason"] = "tool_tier_met"
		return result
	if tier_delta <= allowed_tiers_above_tool:
		result["can_gather"] = true
		result["duration_multiplier"] = _duration_multiplier_for_tier_delta(tier_delta)
		result["reason"] = "tool_tier_penalty"
		return result

	result["reason"] = "tool_tier_too_low"
	return result


func _get_resource_yield_data(resource: Node) -> Dictionary:
	if resource != null and resource.has_method("get_yield_data"):
		var yield_data: Variant = resource.call("get_yield_data")
		if yield_data is Dictionary:
			return yield_data

	return {}


func _get_resource_family_id(resource: Node, yield_data: Dictionary) -> String:
	var family_id := String(yield_data.get("family_id", ""))
	if not family_id.is_empty():
		return family_id

	if resource != null:
		var property_value: Variant = resource.get("resource_family_id")
		if property_value != null:
			return String(property_value)

	return ""


func _get_resource_tier(resource: Node, yield_data: Dictionary) -> int:
	var yield_tier := int(yield_data.get("tier", 0))
	if yield_tier > 0:
		return yield_tier

	if resource != null:
		var property_value: Variant = resource.get("tier")
		if property_value != null:
			return int(property_value)

	return 0


func _required_tool_family_id(resource_family_id: String) -> String:
	return String(RESOURCE_TOOL_FAMILIES.get(resource_family_id, ""))


func _get_equipped_tool_data() -> Dictionary:
	var inventory := _find_inventory()
	if inventory == null:
		return {}
	if inventory.has_method("get_equipped_slot"):
		var equipped_slot: Variant = inventory.call("get_equipped_slot", required_tool_slot_id)
		return equipped_slot if equipped_slot is Dictionary else {}
	if inventory.has_method("get_equipped_slots"):
		var equipped_slots: Variant = inventory.call("get_equipped_slots")
		if equipped_slots is Dictionary:
			var equipped_tool: Variant = equipped_slots.get(required_tool_slot_id, {})
			return equipped_tool if equipped_tool is Dictionary else {}

	return {}


func _duration_multiplier_for_tier_delta(tier_delta: int) -> float:
	if tier_delta == 1:
		return one_tier_above_duration_multiplier
	return DEFAULT_GATHER_DURATION_MULTIPLIER


func _find_inventory() -> Node:
	if inventory_path != NodePath(""):
		var inventory := get_node_or_null(inventory_path)
		if inventory != null:
			return inventory

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("player_inventory")
