## World-side data for a refining station.
##
## A station owns what it can refine and where its menu lives. The UI and
## inventory still own presentation and item storage.
class_name RefiningStation3D
extends Node3D

signal station_opened(station: Node)

## Name shown at the top of the refining menu.
@export var display_name := "Refining Station"
## Prototype category for routing later, such as sawmill, smelter, or loom.
@export var station_type := "refining"
## First recipe tier exposed by this station.
@export_range(1, 8, 1) var min_recipe_tier := 1
## Last recipe tier exposed by this station.
@export_range(1, 8, 1) var max_recipe_tier := 8
## Prefix used to build raw input item ids such as `timber_t4`.
@export var input_item_id_prefix := "timber"
## Prefix used to build refined output item ids such as `planks_t4`.
@export var output_item_id_prefix := "planks"
## Item id consumed by this station's first prototype recipe.
@export var input_item_id := ""
## Item id produced by this station's first prototype recipe.
@export var output_item_id := ""
## Number of input items consumed per refine action.
@export_range(1, 999, 1) var input_quantity := 1
## Number of output items produced per refine action.
@export_range(1, 999, 1) var output_quantity := 1
## Higher-tier refining can require one refined item from the previous tier.
@export var require_lower_tier_refined_input := true
## Lower-tier refined item quantity required when `output_item_id` is tier 2+.
@export_range(1, 999, 1) var lower_tier_refined_quantity := 1
## Seconds each selected refine/craft action takes in the station channel.
@export_range(0.1, 10.0, 0.1) var seconds_per_action := 1.0
## Usable distance from this station's footprint edge. Set to 1m for the first pass.
@export_range(0.0, 12.0, 0.05) var interaction_radius: float = 1.0
## Half-size of this station's horizontal footprint, in local X/Z meters.
@export var interaction_half_extents := Vector2(1.9, 1.9)
## Optional UI panel. If empty, the first node in `refining_panel` is used.
@export var refining_panel_path: NodePath


## Opens the station menu for a player or other actor.
func open_refining_menu(actor: Node = null) -> bool:
	if actor != null and not can_interact_from(actor):
		return false

	var panel := _find_refining_panel()
	if panel == null or not panel.has_method("open_for_station"):
		push_warning("No RefiningPanel found for station: %s" % name)
		return false

	panel.call("open_for_station", self)
	station_opened.emit(self)
	return true


## Returns true when an actor is close enough to use this station.
func can_interact_from(actor: Node) -> bool:
	var actor_3d := actor as Node3D
	if actor_3d == null:
		return false

	return _distance_from_footprint(actor_3d.global_position) <= interaction_radius


## Returns a world position close enough to open the station menu.
func get_interaction_destination(actor: Node) -> Vector3:
	var actor_3d := actor as Node3D
	if actor_3d == null:
		return global_position

	var local_actor_position := global_transform.affine_inverse() * actor_3d.global_position
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
	var world_destination := global_transform * local_destination
	world_destination.y = actor_3d.global_position.y
	return world_destination


## Returns the recipe data shape consumed by `RefiningPanel`.
func get_refining_recipe() -> Dictionary:
	var recipes := get_refining_recipes()
	if not recipes.is_empty():
		return recipes[0] as Dictionary

	return _build_recipe(input_item_id, output_item_id, input_quantity, output_quantity, 0)


## Returns every tier recipe currently available at this station.
func get_refining_recipes() -> Array:
	var recipes := []
	var first_tier := clampi(min_recipe_tier, 1, 8)
	var last_tier := clampi(max_recipe_tier, first_tier, 8)
	for tier in range(first_tier, last_tier + 1):
		recipes.append(_build_tier_recipe(tier))
	return recipes


func _build_tier_recipe(tier: int) -> Dictionary:
	var tier_input_item_id := _tier_item_id(input_item_id_prefix, input_item_id, tier)
	var tier_output_item_id := _tier_item_id(output_item_id_prefix, output_item_id, tier)
	return _build_recipe(tier_input_item_id, tier_output_item_id, input_quantity, output_quantity, tier)


func _build_recipe(
	recipe_input_item_id: String,
	recipe_output_item_id: String,
	recipe_input_quantity: int,
	recipe_output_quantity: int,
	recipe_tier: int
) -> Dictionary:
	return {
		"station_name": display_name,
		"station_type": station_type,
		"tier": recipe_tier,
		"tier_roman": _tier_roman(recipe_tier),
		"inputs": _build_recipe_inputs(recipe_input_item_id, recipe_output_item_id, recipe_input_quantity),
		"input_item_id": recipe_input_item_id,
		"input_quantity": recipe_input_quantity,
		"output_item_id": recipe_output_item_id,
		"output_quantity": recipe_output_quantity,
		"seconds_per_action": seconds_per_action,
	}


func _build_recipe_inputs(
	recipe_input_item_id: String,
	recipe_output_item_id: String,
	recipe_input_quantity: int
) -> Array:
	var inputs := []
	if not recipe_input_item_id.is_empty():
		inputs.append({
			"item_id": recipe_input_item_id,
			"quantity": recipe_input_quantity,
		})

	var lower_tier_refined_item_id := _lower_tier_refined_item_id(recipe_output_item_id)
	if not lower_tier_refined_item_id.is_empty():
		inputs.append({
			"item_id": lower_tier_refined_item_id,
			"quantity": lower_tier_refined_quantity,
		})

	return inputs


func _lower_tier_refined_item_id(recipe_output_item_id: String) -> String:
	if not require_lower_tier_refined_input:
		return ""

	var tier := _item_tier_from_id(recipe_output_item_id)
	if tier <= 1:
		return ""

	return _replace_item_tier(recipe_output_item_id, tier - 1)


func _tier_item_id(item_id_prefix: String, fallback_item_id: String, tier: int) -> String:
	if not item_id_prefix.is_empty():
		return "%s_t%d" % [item_id_prefix, tier]
	if not fallback_item_id.is_empty():
		return _replace_item_tier(fallback_item_id, tier)

	return ""


func _item_tier_from_id(item_id: String) -> int:
	var tier_marker := "_t"
	var marker_index := item_id.rfind(tier_marker)
	if marker_index < 0:
		return 0

	return int(item_id.substr(marker_index + tier_marker.length()))


func _replace_item_tier(item_id: String, tier: int) -> String:
	var tier_marker := "_t"
	var marker_index := item_id.rfind(tier_marker)
	if marker_index < 0:
		return ""

	return "%s%s%d" % [item_id.substr(0, marker_index), tier_marker, tier]


func _tier_roman(tier: int) -> String:
	var roman_values := {
		1: "I",
		2: "II",
		3: "III",
		4: "IV",
		5: "V",
		6: "VI",
		7: "VII",
		8: "VIII",
	}
	return String(roman_values.get(tier, ""))


func _distance_from_footprint(world_position: Vector3) -> float:
	var local_position := global_transform.affine_inverse() * world_position
	var half_extents := _safe_interaction_half_extents()
	var outside_x := maxf(absf(local_position.x) - half_extents.x, 0.0)
	var outside_z := maxf(absf(local_position.z) - half_extents.y, 0.0)
	return Vector2(outside_x, outside_z).length()


func _safe_interaction_half_extents() -> Vector2:
	return Vector2(
		maxf(interaction_half_extents.x, 0.0),
		maxf(interaction_half_extents.y, 0.0)
	)


func _find_refining_panel() -> Node:
	if refining_panel_path != NodePath(""):
		var panel := get_node_or_null(refining_panel_path)
		if panel != null:
			return panel

	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("refining_panel")
