# Inventory Scripts

Inventory state and item data live here. UI rendering for inventory lives in
`scripts/ui/inventory/`.

Files:

- `item_definition.gd`: static data for one item type, such as name, tier,
  icon id, stack limit, weight, equip slot, equipment scene path, and optional
  attachment profile path.
- `item_stack.gd`: runtime quantity of one item definition.
- `prototype_item_catalog.gd`: temporary in-code catalog for logs, stone, ore,
  cotton, hide, and axe previews.
- `player_inventory.gd`: local prototype owner for bag slots, currency, and
  equipped-slot state.

The runtime player inventory starts empty by default. Enable
`seed_prototype_resources` only in a debug/demo scene when you need sample
resource stacks for UI testing. Use `debug_seed_item_ids` for focused previews,
such as showing only `axe_t1` through `axe_t8` in `Main.tscn`. Use
`debug_main_hand_item_id` when a demo scene should start with a visible equipped
main-hand item for art tuning.

GDScript notes:

- `Resource` scripts are data objects. `Node` scripts live in the scene tree.
- `Dictionary` is used for UI-facing display data because the current inventory
  UI already renders dictionaries.
- `preload("res://...")` loads scripts this module always needs.
- Equippable definitions use `equip_slot`; the current axe tool previews equip
  to `main_hand`.
- Tools or gear that have a world/paper-doll prefab can set
  `equipment_scene_path`. Axe tiers currently point at separate scenes under
  `scenes/equipment/tools/axes/`, so each tier can own its model, textures,
  and VFX later.
- Equipment can set `equipment_attachment_profile_path` when the item needs a
  reusable local offset for a character socket.

Common edit points:

- Add or rename prototype resource items in `prototype_item_catalog.gd`.
- Add inventory operations, such as stack splitting or equip rules, in
  `player_inventory.gd`.
- Do not put item storage logic in the UI panel.
