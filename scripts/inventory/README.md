# Inventory Scripts

Inventory state and item data live here. UI rendering for inventory lives in
`scripts/ui/inventory/`.

Files:

- `item_definition.gd`: static data for one item type, such as name, tier,
  icon id, stack limit, and weight.
- `item_stack.gd`: runtime quantity of one item definition.
- `prototype_item_catalog.gd`: temporary in-code catalog for logs, stone, ore,
  cotton, and hide.
- `player_inventory.gd`: local prototype owner for bag slots, currency, and
  equipped-slot state.

GDScript notes:

- `Resource` scripts are data objects. `Node` scripts live in the scene tree.
- `Dictionary` is used for UI-facing display data because the current inventory
  UI already renders dictionaries.
- `preload("res://...")` loads scripts this module always needs.

Common edit points:

- Add or rename prototype resource items in `prototype_item_catalog.gd`.
- Add inventory operations, such as stack splitting, in `player_inventory.gd`.
- Do not put item storage logic in the UI panel.
