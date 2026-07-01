## Runtime quantity of a specific item definition.
##
## Item stacks are what inventories store in slots. A stack can be converted to
## the dictionary shape the current prototype UI already knows how to render.
class_name ItemStack
extends Resource

@export var definition: Resource
@export_range(0, 999, 1) var quantity := 1


## Applies stack data after the resource is created.
func configure(item_definition: Resource, stack_quantity: int) -> void:
	definition = item_definition
	quantity = stack_quantity
	clamp_quantity()


## True when the slot should render as empty.
func is_empty() -> bool:
	return definition == null or quantity <= 0


## Keeps quantity inside the definition's stack limits.
func clamp_quantity() -> void:
	if definition == null:
		quantity = 0
		return

	quantity = clampi(quantity, 0, definition.max_stack)


## Returns a separate stack resource with the same definition and quantity.
func duplicate_stack() -> Resource:
	var stack_script: Script = get_script() as Script
	var stack: Resource = stack_script.new() as Resource
	stack.call("configure", definition, quantity)
	return stack


## Converts this stack into UI-facing data.
func to_display_dict() -> Dictionary:
	if is_empty():
		return {}

	clamp_quantity()
	return definition.to_display_dict(quantity)
