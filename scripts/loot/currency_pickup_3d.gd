## Auto-pickup world currency.
##
## CurrencyPickup3D reuses LootContainer3D's currency transfer logic, but it
## does not open a loot window. When a player enters pickup range, the drop adds
## its silver/gold to the player inventory and removes itself.
class_name CurrencyPickup3D
extends LootContainer3D

## Group searched for player characters that can collect this pickup.
@export var collector_group := "player"
## Distance from the pickup center where currency is collected.
@export_range(0.1, 4.0, 0.05) var pickup_radius := 1.15


func _ready() -> void:
	super._ready()
	_disable_manual_selection()


func _physics_process(_delta: float) -> void:
	if is_empty() or not is_inside_tree():
		return

	var collector := _nearest_collector_in_range()
	if collector == null:
		return

	var inventory := _find_inventory_for_collector(collector)
	if inventory != null:
		take_currency(inventory)


## Currency pickups are proximity-based, not menu-based.
func open_loot_menu(_actor: Node = null) -> bool:
	return false


func _nearest_collector_in_range() -> Node3D:
	var nearest_collector: Node3D = null
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group(collector_group):
		var candidate_3d := candidate as Node3D
		if candidate_3d == null:
			continue

		var distance := _horizontal_distance_to(candidate_3d.global_position)
		if distance <= pickup_radius and distance < nearest_distance:
			nearest_collector = candidate_3d
			nearest_distance = distance

	return nearest_collector


func _find_inventory_for_collector(_collector: Node) -> Node:
	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("player_inventory")


func _horizontal_distance_to(world_position: Vector3) -> float:
	var offset := world_position - global_position
	offset.y = 0.0
	return offset.length()


func _disable_manual_selection() -> void:
	var selectable := get_node_or_null("Selectable")
	if selectable != null:
		selectable.set("selection_enabled", false)
