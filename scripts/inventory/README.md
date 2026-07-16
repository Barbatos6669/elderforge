# Inventory Scripts

Inventory state and item data live here. UI rendering for inventory lives in
`scripts/ui/inventory/`.

Files:

- `item_definition.gd`: static data for one item type, such as name, tier,
  icon id, stack limit, weight, equip slot, equipment scene path, additive stat
  modifiers, and optional attachment, animation profile, and slot ability paths.
- `item_family_definition.gd`: data shape for one tiered item family, such as
  logs I-VIII or axes I-VIII. The authored `.tres` files live in
  `assets/items/families/`.
- `item_stack.gd`: runtime quantity of one item definition.
- `prototype_item_catalog.gd`: temporary catalog builder for logs, planks,
  blocks, ingots, cloth, worked leather, stone, ore, cotton, hide, axe tools,
  hammer tools, pickaxe tools, sickle tools, skinning knife tools, the first
  one-handed sword weapon family, and starter leather armor pieces. It reads
  item family `.tres` data and creates one `ItemDefinition` per tier.
- `player_inventory.gd`: local prototype owner for bag slots, currency, and
  equipped-slot state. Use `get_equipped_slot("main_hand")` when gameplay needs
  one equipped item, such as checking the currently held gathering tool. Systems
  like gathering and refining use narrow commands such as `add_item()`,
  `remove_item()`, and `get_item_count()`. `get_network_snapshot()` and
  `apply_network_snapshot()` provide the compact bag/equipment/currency shape
  that `/root/PlayerDatabase` and the playtest server can store today and own
  later.

The runtime player inventory starts empty by default. Enable
`seed_prototype_resources` only in a debug/demo scene when you need sample
resource stacks for UI testing. Use `debug_seed_item_ids` for focused previews,
such as showing only `planks_t1` through `planks_t8`, `blocks_t1` through
`blocks_t8`, `ingots_t1` through `ingots_t8`, `cloth_t1` through `cloth_t8`,
`worked_leather_t1` through `worked_leather_t8`, `axe_t1` through `axe_t8`,
`hammer_t1` through `hammer_t8`, `pickaxe_t1` through `pickaxe_t8`, or
`sickle_t1` through `sickle_t8` in a demo scene. Use `skinning_knife_t1` through
`skinning_knife_t8` when previewing hide gathering tools. Use
`one_handed_sword_t1` through `one_handed_sword_t8` when previewing starter
weapons. Use `debug_main_hand_item_id` when a demo scene should start with a
visible equipped main-hand item for art tuning.

GDScript notes:

- `Resource` scripts are data objects. `Node` scripts live in the scene tree.
- `Dictionary` is used for UI-facing display data because the current inventory
  UI already renders dictionaries.
- `preload("res://...")` loads scripts this module always needs.
- Equippable definitions use `equip_slot`; the current axe, hammer, pickaxe,
  sickle, skinning knife, and one-handed sword previews equip to `main_hand`.
- Tools or gear that have a world/paper-doll prefab can set
  `equipment_scene_path` later. The current imported equipment scenes were
  removed, so equippable prototype items are data/icons only for now.
- Equipment can set `equipment_attachment_profile_path` when the item needs a
  reusable local offset for a character socket.
- Equipment can set `equipment_animation_profile_path` when the item needs
  tool-specific or weapon-specific animation choices.
- Equipment can set `ability_paths` to supply spells by action-bar slot without
  adding item-specific branches to the player controller or HUD. Tiered family
  resources author these through `ability_path_templates`. Weapons own Q/W/E,
  chest armor owns R, helmets own D, and boots own F; the starter sword supplies
  Q, leather chest supplies R, leather helmet supplies D, and leather boots
  supply F. `q_ability_path` remains a legacy compatibility field while older
  item resources are migrated. Passives do not use an active action-bar slot.
- Equipment can expose multiple selectable spells per action key through
  `ability_choices`; tiered families author these with
  `ability_choice_path_templates`. Choice entries may include `min_tier` and
  `max_tier`. `PlayerInventory.select_item_ability()` validates the selected
  resource against both the item choices and the ability's own input key, then
  persists the choice by item id. UI-facing `ability_paths` always contains the
  effective selection, so combat and HUD consumers keep their existing lookup.
- Equippable items can set `stat_modifiers` with stable `PlayerStats` ids. The
  player adds those values only while the item is equipped; for example, the
  starter sword grants `auto_attack_damage = 20` on top of the base 20.
- `persist_to_player_database` saves/restores signed-in account inventories
  through the `PlayerDatabase` autoload. Public playtests now require a signed-in
  account so each player keeps one persistent profile.

Common edit points:

- Add or rename prototype item families in `assets/items/families/`.
- Add a new family path to `prototype_item_catalog.gd` only when the family is
  brand new.
- Add inventory operations, such as stack splitting or equip rules, in
  `player_inventory.gd`.
- Do not put item storage logic in the UI panel.
