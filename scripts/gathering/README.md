# Gathering Scripts

World resource metadata lives here. Player-side gathering behavior lives in
`scripts/player/gathering/`.

Files:

- `gatherable_resource_3d.gd`: metadata attached to a resource node, such as a
  tree. It defines resource family, tier, yield item id, per-tick quantity,
  gather duration, remaining gather ticks, and depleted visuals.

Related scene:

- `scenes/gathering/Tier1Tree.tscn`
- `scenes/gathering/Tier1Rock.tscn`

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

GDScript notes:

- `extends Node3D` means the resource has a 3D transform in the world.
- `get_yield_data() -> Dictionary` returns a small data packet for the player
  gathering module.
- `max_gather_ticks` is the number of completed channels available before the
  resource depletes. The current T1 tree uses 3 ticks.
- `yield_quantity` is the reward per completed tick. The current T1 tree gives
  1 `timber_t1` per tick. The current T1 rock gives 1 `stone_t1` per tick.
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
