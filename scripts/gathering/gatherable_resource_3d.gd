## Metadata for a resource node that can later be gathered by the player.
##
## The current prototype only exposes data for selection/debugging. A gathering
## controller can read this node to know which item stack to add, how much to
## yield, and which tier color or label to show in UI.
class_name GatherableResource3D
extends Node3D

## Name shown by targeting or future gathering UI.
@export var display_name := "Gatherable Resource"
## Resource family id matching inventory item definitions, such as `logs`.
@export var resource_family_id := "logs"
## Item definition id yielded by this node.
@export var yield_item_id := "timber_t1"
## Tier from I to VIII.
@export_range(1, 8, 1) var tier := 1
## Prototype amount gathered per interaction.
@export_range(1, 999, 1) var yield_quantity := 3
## Seconds a future gather action should take.
@export_range(0.1, 60.0, 0.1) var gather_duration := 2.0
## Whether this node can currently be gathered.
@export var gather_enabled := true


func _ready() -> void:
	add_to_group("gatherable_resources")


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
	}


func can_gather() -> bool:
	return gather_enabled
