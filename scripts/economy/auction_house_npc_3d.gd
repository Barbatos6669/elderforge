## World interaction point for the auction house service.
##
## The player controller treats this like any other clickable service: click the
## NPC, walk into range, open the service dialogue, then open the auction panel.
class_name AuctionHouseNpc3D
extends Node3D

signal service_opened(auctioneer: Node)

@export var display_name := "Auctioneer"
@export_range(0.0, 12.0, 0.05) var interaction_radius := 1.0
@export var interaction_half_extents := Vector2(0.35, 0.35)
@export var interaction_anchor_path: NodePath
@export var use_service_dialog := true
@export var service_dialog_panel_path: NodePath
@export var auction_panel_path: NodePath
@export var service_subtitle := "Market broker"
@export_multiline var service_description := "Browse public listings, post sell orders, create buy orders, or quick-sell into the best waiting offer."
@export_multiline var service_talk_text := "Prices move with hungry crafters, lazy gatherers, and whoever forgot to bring enough silver."


func open_service_interaction(actor: Node = null) -> bool:
	if actor != null and not can_interact_from(actor):
		return false

	if use_service_dialog:
		var dialog_panel := _find_service_dialog_panel()
		if dialog_panel != null and dialog_panel.has_method("open_for_station"):
			dialog_panel.call("open_for_station", self)
			service_opened.emit(self)
			return true

	return open_service_menu()


## Backward-compatible name so older service lookup paths can still open us.
func open_refining_menu(actor: Node = null) -> bool:
	return open_service_interaction(actor)


func open_service_menu() -> bool:
	var panel := _find_auction_panel()
	if panel == null or not panel.has_method("open_for_auctioneer"):
		push_warning("No AuctionHousePanel found for auctioneer: %s" % name)
		return false

	panel.call("open_for_auctioneer", self)
	service_opened.emit(self)
	return true


func get_service_dialog_data() -> Dictionary:
	return {
		"title": display_name,
		"subtitle": service_subtitle,
		"action_label": "Open Market",
		"description": service_description,
		"talk_text": service_talk_text,
	}


func can_interact_from(actor: Node) -> bool:
	var actor_3d := actor as Node3D
	if actor_3d == null:
		return false

	return _distance_from_footprint(actor_3d.global_position) <= interaction_radius


func get_interaction_destination(actor: Node) -> Vector3:
	var actor_3d := actor as Node3D
	if actor_3d == null:
		return global_position

	var interaction_transform := _interaction_transform()
	var local_actor_position := interaction_transform.affine_inverse() * actor_3d.global_position
	var half_extents := _safe_interaction_half_extents()
	var closest_footprint_point := Vector3(
		clampf(local_actor_position.x, -half_extents.x, half_extents.x),
		0.0,
		clampf(local_actor_position.z, -half_extents.y, half_extents.y)
	)
	var outward := Vector2(
		local_actor_position.x - closest_footprint_point.x,
		local_actor_position.z - closest_footprint_point.z
	)
	if outward.length_squared() <= 0.0001:
		outward = Vector2(local_actor_position.x, local_actor_position.z)
	if outward.length_squared() <= 0.0001:
		outward = Vector2(0.0, 1.0)

	var stop_distance := maxf(interaction_radius * 0.75, 0.05)
	var local_destination := closest_footprint_point + Vector3(outward.normalized().x, 0.0, outward.normalized().y) * stop_distance
	var world_destination := interaction_transform * local_destination
	world_destination.y = actor_3d.global_position.y
	return world_destination


func _find_service_dialog_panel() -> Node:
	if service_dialog_panel_path != NodePath(""):
		var panel := get_node_or_null(service_dialog_panel_path)
		if panel != null:
			return panel

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("service_npc_dialog_panel")


func _find_auction_panel() -> Node:
	if auction_panel_path != NodePath(""):
		var panel := get_node_or_null(auction_panel_path)
		if panel != null:
			return panel

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("auction_house_panel")


func _distance_from_footprint(world_position: Vector3) -> float:
	var local_position := _interaction_transform().affine_inverse() * world_position
	var half_extents := _safe_interaction_half_extents()
	var outside_x := maxf(absf(local_position.x) - half_extents.x, 0.0)
	var outside_z := maxf(absf(local_position.z) - half_extents.y, 0.0)
	return Vector2(outside_x, outside_z).length()


func _interaction_transform() -> Transform3D:
	if interaction_anchor_path != NodePath(""):
		var anchor := get_node_or_null(interaction_anchor_path) as Node3D
		if anchor != null:
			return anchor.global_transform

	return global_transform


func _safe_interaction_half_extents() -> Vector2:
	return Vector2(
		maxf(interaction_half_extents.x, 0.0),
		maxf(interaction_half_extents.y, 0.0)
	)
