## Drops a loot container into the world when another component asks for it.
##
## Enemy AI calls `drop_loot()` after death. Keeping the roll/spawn logic here
## lets future mobs swap loot behavior without rewriting combat or respawn code.
class_name LootDropper3D
extends Node

## Scene spawned into the world for item drops.
@export var loot_bag_scene: PackedScene
## Scene spawned into the world for currency drops.
@export var currency_drop_scene: PackedScene
## Minimum silver dropped by this prototype mob.
@export_range(0, 999, 1) var silver_min := 3
## Maximum silver dropped by this prototype mob.
@export_range(0, 999, 1) var silver_max := 8
## First guaranteed prototype item id.
@export var guaranteed_item_id := "timber_t1"
## Minimum quantity of the guaranteed item.
@export_range(0, 999, 1) var guaranteed_item_min := 1
## Maximum quantity of the guaranteed item.
@export_range(0, 999, 1) var guaranteed_item_max := 2
## Small world offset so the item bag sits beside the corpse.
@export var item_spawn_offset := Vector3(-0.25, 0.05, 0.0)
## Small world offset so the currency pile sits on the ground.
@export var currency_spawn_offset := Vector3(0.25, 0.03, 0.0)


func drop_loot(world_position: Vector3) -> Node:
	var loot_data := _roll_loot()
	if _is_empty_loot(loot_data):
		return null

	var parent := _spawn_parent()
	var item_bag := _spawn_item_bag(parent, world_position, loot_data)
	var currency_drop := _spawn_currency_drop(parent, world_position, loot_data)

	return item_bag if item_bag != null else currency_drop


func _roll_loot() -> Dictionary:
	var rolled_silver := 0
	var safe_silver_min := mini(silver_min, silver_max)
	var safe_silver_max := maxi(silver_min, silver_max)
	if safe_silver_max > 0:
		rolled_silver = randi_range(safe_silver_min, safe_silver_max)

	var items := []
	var safe_item_min := mini(guaranteed_item_min, guaranteed_item_max)
	var safe_item_max := maxi(guaranteed_item_min, guaranteed_item_max)
	if not guaranteed_item_id.is_empty() and safe_item_max > 0:
		items.append({
			"item_id": guaranteed_item_id,
			"quantity": randi_range(safe_item_min, safe_item_max),
		})

	return {
		"silver": rolled_silver,
		"gold": 0,
		"items": items,
	}


func _spawn_parent() -> Node:
	if owner != null and owner.get_parent() != null:
		return owner.get_parent()
	if get_parent() != null and get_parent().get_parent() != null:
		return get_parent().get_parent()
	if get_tree().current_scene != null:
		return get_tree().current_scene

	return get_parent()


func _spawn_item_bag(parent: Node, world_position: Vector3, loot_data: Dictionary) -> Node:
	var items: Array = loot_data.get("items", [])
	if items.is_empty():
		return null
	if loot_bag_scene == null:
		push_warning("LootDropper3D has item loot but no loot_bag_scene assigned.")
		return null

	return _spawn_container(
		loot_bag_scene,
		parent,
		world_position + item_spawn_offset,
		{
			"silver": 0,
			"gold": 0,
			"items": items,
		}
	)


func _spawn_currency_drop(parent: Node, world_position: Vector3, loot_data: Dictionary) -> Node:
	var silver := maxi(int(loot_data.get("silver", 0)), 0)
	var gold := maxi(int(loot_data.get("gold", 0)), 0)
	if silver <= 0 and gold <= 0:
		return null

	var scene := currency_drop_scene
	if scene == null:
		scene = loot_bag_scene
	if scene == null:
		push_warning("LootDropper3D has currency loot but no currency_drop_scene assigned.")
		return null

	return _spawn_container(
		scene,
		parent,
		world_position + currency_spawn_offset,
		{
			"silver": silver,
			"gold": gold,
			"items": [],
		}
	)


func _spawn_container(
	scene: PackedScene,
	parent: Node,
	world_position: Vector3,
	loot_data: Dictionary
) -> Node:
	var container := scene.instantiate()
	parent.add_child(container)

	var container_3d := container as Node3D
	if container_3d != null:
		container_3d.global_position = world_position

	if container.has_method("configure_loot"):
		container.call("configure_loot", loot_data)

	return container


func _is_empty_loot(loot_data: Dictionary) -> bool:
	return (
		int(loot_data.get("silver", 0)) <= 0
		and int(loot_data.get("gold", 0)) <= 0
		and (loot_data.get("items", []) as Array).is_empty()
	)
