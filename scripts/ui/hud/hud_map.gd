## Compact gameplay minimap.
##
## The map samples existing world groups instead of requiring every object to
## know about UI. Resources, mobs, and service NPCs remain owned by their
## gameplay systems while this HUD paints small markers for player orientation.
class_name HudMap
extends CanvasLayer

const UiStyle := preload("res://scripts/ui/elderforge_ui_style.gd")
const HudMapViewScript := preload("res://scripts/ui/hud/hud_map_view.gd")

## Player node used for the marker and facing arrow.
@export var player_path: NodePath = NodePath("../World/Player")
## Container scanned for refining, crafting, and auction NPC markers.
@export var stations_path: NodePath = NodePath("../World/LevelContent/Stations")
## World-space center of the playable minimap.
@export var map_center := Vector2.ZERO
## World-space size shown by the HUD map. The prototype playtest area is 100x100.
@export var map_size_meters := Vector2(100.0, 100.0)
## Clockwise screen-space rotation so the HUD map matches the isometric camera.
@export_range(-180.0, 180.0, 1.0) var map_rotation_degrees := 45.0
## Bottom-right offset from the viewport edge.
@export var screen_offset := Vector2(14.0, 14.0)
## Square pixel size of the map body.
@export_range(96.0, 320.0, 1.0) var map_pixel_size := 176.0
## Seconds between world marker refreshes.
@export_range(0.05, 2.0, 0.05) var refresh_interval := 0.2
@export var show_resources := true
@export var show_mobs := true
@export var show_services := true

var _root: Control
var _map_view
var _refresh_elapsed := 0.0


func _ready() -> void:
	layer = UiStyle.LAYER_HUD_ACTIONS
	_build_ui()
	_refresh_map_state()


func _process(delta: float) -> void:
	_refresh_elapsed += maxf(delta, 0.0)
	if _refresh_elapsed < refresh_interval:
		return

	_refresh_elapsed = 0.0
	_refresh_map_state()


func _build_ui() -> void:
	var panel_size := Vector2(map_pixel_size + 16.0, map_pixel_size + 36.0)
	_root = Control.new()
	_root.name = "HudMapRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.anchor_left = 1.0
	_root.anchor_top = 1.0
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_left = -panel_size.x - screen_offset.x
	_root.offset_top = -panel_size.y - screen_offset.y
	_root.offset_right = -screen_offset.x
	_root.offset_bottom = -screen_offset.y
	add_child(_root)

	var panel := PanelContainer.new()
	panel.name = "Frame"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UiStyle.compact_panel_style())
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "MAP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.label_primary(title, 14, 1)
	title.add_theme_color_override("font_color", UiStyle.COLOR_GOLD)
	stack.add_child(title)

	_map_view = HudMapViewScript.new()
	_map_view.name = "MapView"
	_map_view.custom_minimum_size = Vector2(map_pixel_size, map_pixel_size)
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_map_view)


func _refresh_map_state() -> void:
	if _map_view == null:
		return

	var player := _find_player()
	var has_player := player != null
	var player_position := player.global_position if has_player else Vector3.ZERO
	var player_yaw := player.global_rotation.y if has_player else 0.0

	_map_view.set_map_state(
		map_center,
		map_size_meters,
		map_rotation_degrees,
		has_player,
		player_position,
		player_yaw,
		_collect_resource_positions(),
		_collect_mob_positions(player),
		_collect_service_positions()
	)


func _find_player() -> Node3D:
	if player_path != NodePath(""):
		var configured_player := get_node_or_null(player_path) as Node3D
		if configured_player != null:
			return configured_player

	return get_tree().get_first_node_in_group("player") as Node3D


func _collect_resource_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if not show_resources:
		return positions

	for resource in get_tree().get_nodes_in_group("gatherable_resources"):
		if resource != null and resource.has_method("can_gather") and not bool(resource.call("can_gather")):
			continue

		var marker_root := _as_world_marker_root(resource)
		if marker_root == null:
			continue
		if marker_root.has_method("is_visible_in_tree") and not marker_root.is_visible_in_tree():
			continue

		positions.append(marker_root.global_position)

	return positions


func _collect_mob_positions(player: Node3D) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if not show_mobs:
		return positions

	for mob in get_tree().get_nodes_in_group("network_mobs"):
		var marker_root := _as_world_marker_root(mob)
		if marker_root == null or marker_root == player:
			continue
		if marker_root.has_method("is_visible_in_tree") and not marker_root.is_visible_in_tree():
			continue

		positions.append(marker_root.global_position)

	return positions


func _collect_service_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if not show_services:
		return positions

	var stations := get_node_or_null(stations_path)
	if stations == null:
		return positions

	_collect_service_positions_recursive(stations, positions)
	return positions


func _collect_service_positions_recursive(node: Node, positions: Array[Vector3]) -> void:
	if node.has_method("open_refining_menu") or node.has_method("open_service_interaction"):
		var marker_root := _as_world_marker_root(node)
		if marker_root != null and marker_root.is_visible_in_tree():
			positions.append(marker_root.global_position)
			return

	for child in node.get_children():
		_collect_service_positions_recursive(child, positions)


func _as_world_marker_root(node: Variant) -> Node3D:
	if node is Node3D:
		return node as Node3D
	if node is Node:
		return _nearest_node_3d((node as Node).get_parent())
	return null


func _nearest_node_3d(node: Node) -> Node3D:
	var current := node
	while current != null:
		if current is Node3D:
			return current as Node3D
		current = current.get_parent()

	return null
