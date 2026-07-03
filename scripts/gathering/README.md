# Gathering Scripts

World resource metadata lives here. Player-side gathering behavior lives in
`scripts/player/gathering/`.

Files:

- `gatherable_resource_3d.gd`: metadata attached to a resource node, such as a
  tree. It defines resource family, tier, yield item id, per-tick quantity,
  gather duration, remaining gather ticks, and depleted visuals.

Related scenes:

- `scenes/gathering/Tier1Tree.tscn` through `Tier8Tree.tscn`
- `scenes/gathering/Tier1Rock.tscn` through `Tier8Rock.tscn`
- `scenes/gathering/Tier1Ore.tscn` through `Tier8Ore.tscn`
- `scenes/gathering/Tier1Fiber.tscn` through `Tier8Fiber.tscn`

Related art:

- `assets/models/resources/trees/t1_tree.blend`: editable source model.
- `assets/models/resources/trees/t1_tree_trunk.glb`: trunk runtime export.
- `assets/models/resources/trees/t1_tree_leaves.glb`: leaves/canopy runtime
  export, split out for future seasonal swaps and canopy fading.
- `assets/models/resources/trees/t1_tree_stump.glb`: depleted-stump runtime
  export.
- `assets/models/resources/rocks/t1_rock.blend`: editable T1 rock source model.
- `assets/models/resources/rocks/t1_rock_full.glb`: full-rock runtime export.
- `assets/models/resources/rocks/t1_rock_depleted.glb`: depleted-rubble runtime
  export.
- `assets/models/resources/ores/source/t1_ore.blend`: editable T1 ore source
  model.
- `assets/models/resources/ores/t1_ore_full.glb`: full-ore runtime export.
- `assets/models/resources/ores/t1_ore_depleted.glb`: depleted-rubble runtime
  export.
- `assets/models/resources/fibers/source/t1_fiber.blend`: editable T1 fiber
  source model.
- `assets/models/resources/fibers/t1_fiber_full.glb`: full-fiber runtime
  export.
- `assets/models/resources/fibers/t1_fiber_depleted.glb`: depleted cut-stem
  runtime export.
- T2-T8 placeholder variants live beside the T1 GLBs with matching names such
  as `t4_ore_full.glb` or `t7_tree_leaves.glb`. Their editable copies live in
  each family `source/` folder.
- `tools/blender/create_resource_tier_variants.py` copies the T1 placeholder
  shape to T2-T8 for each current resource family while preserving the resource
  tier color.

GDScript notes:

- `extends Node3D` means the resource has a 3D transform in the world.
- `get_yield_data() -> Dictionary` returns a small data packet for the player
  gathering module.
- Resource scenes only declare their `resource_family_id` and `tier`. The
  equipped-tool rule lives in `scripts/player/gathering/player_gathering.gd`,
  where logs require axes, stone requires hammers, ore requires pickaxes, cotton
  requires sickles, and hide requires skinning knives.
- `max_gather_ticks` is the number of completed channels available before the
  resource depletes. The current T1 tree uses 3 ticks.
- `yield_quantity` is the reward per completed tick. Tiered scenes yield their
  matching tier item, such as `timber_t4`, `stone_t4`, `ore_t4`, or
  `cotton_t4`.
- `consume_gather_tick()` subtracts one remaining tick after inventory accepts
  the reward.
- `replenish_enabled` and `replenish_interval_seconds` restore missing ticks
  over time. The current T1 tree restores 1 tick every 30 seconds.
- `replenish_gather_tick()` adds one missing tick, updates visuals, and enables
  selection again if the resource was depleted.
- `active_visuals_path` and `depleted_visuals_path` point at the full resource
  model and the depleted replacement model.
- Gatherable scenes should have a separate `ResourceBody` `StaticBody3D` on the
  `ResourceObstacle` physics layer. Keep it close to the solid trunk/rock shape;
  the larger `Selectable` area is only for clicking and hover.
- `add_to_group("gatherable_resources")` makes all gatherable nodes searchable
  by group later.

Keep this folder about the world resource itself. Movement, channeling, and
inventory rewards belong to player or inventory modules.
