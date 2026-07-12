## Metadata for a resource node that can later be gathered by the player.
##
## The current prototype only exposes data for selection/debugging. A gathering
## controller can read this node to know which item stack to add, how much to
## yield, and which tier color or label to show in UI.
class_name GatherableResource3D
extends Node3D

signal gather_tick_consumed(remaining_ticks: int, max_ticks: int)
signal gather_tick_replenished(remaining_ticks: int, max_ticks: int)
signal depleted
signal fully_replenished

## Name shown by targeting or future gathering UI.
@export var display_name := "Gatherable Resource"
## Resource family id matching inventory item definitions, such as `logs`.
@export var resource_family_id := "logs"
## Item definition id yielded by this node.
@export var yield_item_id := "timber_t1"
## Tier from I to VIII.
@export_range(1, 8, 1) var tier := 1
## Prototype amount gathered per completed gather tick.
@export_range(1, 999, 1) var yield_quantity := 1
## Number of gather ticks available before this node becomes depleted.
@export_range(1, 100, 1) var max_gather_ticks := 3
## Seconds a future gather action should take.
@export_range(0.1, 60.0, 0.1) var gather_duration := 2.0
## Whether missing gather ticks should naturally come back over time.
@export var replenish_enabled := true
## Seconds needed to restore one missing gather tick.
@export_range(1.0, 3600.0, 1.0) var replenish_interval_seconds := 30.0
## Whether this node can currently be gathered.
@export var gather_enabled := true
## Visual root shown while this resource still has gather ticks.
@export var active_visuals_path: NodePath = NodePath("Visuals/Active")
## Visual root shown after this resource is depleted.
@export var depleted_visuals_path: NodePath = NodePath("Visuals/Depleted")
## Optional selectable that should be disabled when the resource depletes.
@export var selectable_path: NodePath = NodePath("Selectable")

var _remaining_gather_ticks := 0
var _replenish_elapsed := 0.0


func _ready() -> void:
	add_to_group("gatherable_resources")
	_remaining_gather_ticks = max_gather_ticks
	_sync_depleted_state()
	set_process(_can_replenish())


func _process(delta: float) -> void:
	_update_replenishment(delta)


## Returns the roman numeral used by tier labels and item UI.
func get_tier_roman() -> String:
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
	return String(roman_values.get(tier, str(tier)))


## Returns the shared prototype tier color.
func get_tier_color() -> Color:
	match tier:
		1:
			return Color(0.72, 0.72, 0.72, 1.0)
		2:
			return Color(0.72, 0.50, 0.30, 1.0)
		3:
			return Color(0.20, 0.62, 0.25, 1.0)
		4:
			return Color(0.20, 0.42, 0.82, 1.0)
		5:
			return Color(0.78, 0.18, 0.16, 1.0)
		6:
			return Color(0.92, 0.48, 0.14, 1.0)
		7:
			return Color(0.95, 0.82, 0.18, 1.0)
		8:
			return Color(0.94, 0.94, 0.9, 1.0)
		_:
			return Color(0.72, 0.72, 0.72, 1.0)


## Returns the data a future gather action needs to create an inventory stack.
func get_yield_data() -> Dictionary:
	return {
		"item_id": yield_item_id,
		"family_id": resource_family_id,
		"tier": tier,
		"tier_roman": get_tier_roman(),
		"quantity": yield_quantity,
		"gather_duration": gather_duration,
		"remaining_ticks": _remaining_gather_ticks,
		"max_ticks": max_gather_ticks,
		"replenish_interval_seconds": replenish_interval_seconds,
	}


## Consumes one available gather tick after a successful reward grant.
func consume_gather_tick() -> bool:
	if not can_gather():
		return false

	_remaining_gather_ticks = maxi(_remaining_gather_ticks - 1, 0)
	_replenish_elapsed = 0.0
	gather_tick_consumed.emit(_remaining_gather_ticks, max_gather_ticks)
	_sync_depleted_state()
	set_process(_can_replenish())
	if is_depleted():
		depleted.emit()

	return true


## Restores one missing gather tick, usually called by the timed replenishment loop.
func replenish_gather_tick() -> bool:
	if not _can_replenish():
		return false

	_remaining_gather_ticks = mini(_remaining_gather_ticks + 1, max_gather_ticks)
	gather_tick_replenished.emit(_remaining_gather_ticks, max_gather_ticks)
	_sync_depleted_state()
	if _remaining_gather_ticks >= max_gather_ticks:
		_replenish_elapsed = 0.0
		fully_replenished.emit()
	set_process(_can_replenish())

	return true


## Applies an externally replicated tick count while preserving local visuals.
func set_remaining_ticks(remaining_ticks: int) -> void:
	var previous_ticks := _remaining_gather_ticks
	_remaining_gather_ticks = clampi(remaining_ticks, 0, max_gather_ticks)
	_replenish_elapsed = 0.0

	if _remaining_gather_ticks < previous_ticks:
		gather_tick_consumed.emit(_remaining_gather_ticks, max_gather_ticks)
	elif _remaining_gather_ticks > previous_ticks:
		gather_tick_replenished.emit(_remaining_gather_ticks, max_gather_ticks)

	_sync_depleted_state()
	set_process(_can_replenish())
	if previous_ticks > 0 and is_depleted():
		depleted.emit()
	elif _remaining_gather_ticks >= max_gather_ticks:
		fully_replenished.emit()


func get_remaining_ticks() -> int:
	return _remaining_gather_ticks


func get_max_ticks() -> int:
	return max_gather_ticks


func is_depleted() -> bool:
	return _remaining_gather_ticks <= 0


func reset_resource() -> void:
	_remaining_gather_ticks = max_gather_ticks
	_replenish_elapsed = 0.0
	gather_enabled = true
	_sync_depleted_state()
	set_process(false)


func can_gather() -> bool:
	return gather_enabled and _remaining_gather_ticks > 0


func _update_replenishment(delta: float) -> void:
	if not _can_replenish():
		_replenish_elapsed = 0.0
		set_process(false)
		return

	_replenish_elapsed += maxf(delta, 0.0)
	while _replenish_elapsed >= replenish_interval_seconds and _can_replenish():
		_replenish_elapsed -= replenish_interval_seconds
		replenish_gather_tick()

	set_process(_can_replenish())


func _can_replenish() -> bool:
	return (
		replenish_enabled
		and gather_enabled
		and replenish_interval_seconds > 0.0
		and _remaining_gather_ticks < max_gather_ticks
	)


func _sync_depleted_state() -> void:
	var active_visuals := _get_first_optional_node_3d([
		active_visuals_path,
		NodePath("Visuals/Active"),
		NodePath("Visuals/FullTree"),
	])
	if active_visuals != null:
		active_visuals.visible = not is_depleted()

	var depleted_visuals := _get_first_optional_node_3d([
		depleted_visuals_path,
		NodePath("Visuals/Depleted"),
		NodePath("Visuals/DepletedTrunk"),
	])
	if depleted_visuals != null:
		depleted_visuals.visible = is_depleted()

	var selectable := _get_optional_node(selectable_path, NodePath("Selectable"))
	if selectable != null:
		selectable.set("selection_enabled", can_gather())
		if is_depleted() and selectable.has_method("set_selected"):
			selectable.call("set_selected", false)


func _get_optional_node(path: NodePath, fallback_path: NodePath) -> Node:
	if path != NodePath(""):
		var configured_node := get_node_or_null(path)
		if configured_node != null:
			return configured_node

	if fallback_path != NodePath(""):
		return get_node_or_null(fallback_path)

	return null


func _get_optional_node_3d(path: NodePath, fallback_path: NodePath) -> Node3D:
	return _get_optional_node(path, fallback_path) as Node3D


func _get_first_optional_node_3d(paths: Array[NodePath]) -> Node3D:
	for path in paths:
		if path == NodePath(""):
			continue

		var found_node := get_node_or_null(path)
		if found_node is Node3D:
			return found_node

	return null
