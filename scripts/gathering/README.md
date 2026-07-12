# Gathering Scripts

World resource metadata lives here. Player-side gathering behavior lives in
`scripts/player/gathering/`.

Files:

- `gatherable_resource_3d.gd`: metadata attached to a resource node, such as a
  tree. It defines resource family, tier, yield item id, per-tick quantity,
  gather duration, remaining gather ticks, and depleted visuals.
- `gatherable_resource_model_state.gd`: visual helper for imported/project-owned
  resources that keep active, depleted, and disabled helper meshes inside one
  scene. Player occlusion is handled by `scripts/visuals/occludable_visual_3d.gd`.

Related scenes:

- `scenes/gathering/trees/OakTreeT1.tscn`: T1 Oak Tree node. It yields
  `timber_t1`, which displays as `Oak Wood I`, and currently uses the nature
  pack `CommonTree_1` art with alpha-cut leaf cards.
- `scenes/gathering/rocks/MoonchalkRockT1.tscn`: T1 Clay Deposit node. It yields
  `stone_t1`, which displays as `Clay I`, and swaps to placeholder rubble when
  depleted.
- `scenes/gathering/ore/HearthsteelOreT1.tscn`: T1 Iron Ore node. It yields
  `ore_t1`, which displays as `Iron Ore I`.

Related art:

- `assets/Nature Pack/CommonTree_1.gltf`: current T1 Oak/Common Tree visual.
  The prefab wraps it with alpha-cut leaves, a gameplay collider, selection,
  hover feedback, wind sway, and a simple depleted stump.
- `assets/Rocks/Moonchalk_Var1.glb`: temporary rock model used by the T1 Clay
  Deposit resource.

GDScript notes:

- `extends Node3D` means the resource has a 3D transform in the world.
- `get_yield_data() -> Dictionary` returns a small data packet for the player
  gathering module.
- Resource scenes only declare their `resource_family_id` and `tier`. The
  equipped-tool rule lives in `scripts/player/gathering/player_gathering.gd`,
  where logs require axes, stone requires hammers, ore requires pickaxes, cotton
  requires sickles, and hide requires skinning knives.
- `max_gather_ticks` is the number of completed channels available before the
  resource depletes. The current T1 tree and T1 rock use 3 ticks.
- `yield_quantity` is the reward per completed tick. Tiered scenes yield their
  matching tier item, such as `timber_t4`, `stone_t4`, `ore_t4`, or
  `cotton_t4`.
- `consume_gather_tick()` subtracts one remaining tick after inventory accepts
  the reward.
- `replenish_enabled` and `replenish_interval_seconds` restore missing ticks
  over time. The current T1 tree and T1 rock restore 1 tick every 30 seconds.
- `replenish_gather_tick()` adds one missing tick, updates visuals, and enables
  selection again if the resource was depleted.
- `active_visuals_path` and `depleted_visuals_path` toggle the current T1 Oak
  Tree between the full CommonTree visual and a simple stump.
- `active_mesh_names`, `depleted_mesh_names`, and `disabled_mesh_names` are
  still available when an imported model contains separate active/depleted mesh
  pieces.
- Player visibility is intentionally separate from gathering state. The T1 Oak
  Tree uses `OccludableVisual3D` to fade the CommonTree model when it blocks the
  player. Use the same pattern later for roofs, canopies, or tall props.
- Gatherable scenes should have a separate `StaticBody3D` trunk/rock collider on
  the resource obstacle layer. Keep it close to the solid shape; the larger
  `Selectable` area is only for clicking and hover.
- `add_to_group("gatherable_resources")` makes all gatherable nodes searchable
  by group later.

Keep this folder about the world resource itself. Movement, channeling, and
inventory rewards belong to player or inventory modules.
