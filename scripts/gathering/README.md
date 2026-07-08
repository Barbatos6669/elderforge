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

- `scenes/gathering/trees/SilverneedlePineT1.tscn`: first project-owned
  gatherable tree. It yields `timber_t1` and uses the Silverneedle Pine model.
- `scenes/gathering/rocks/MoonchalkRockT1.tscn`: T1 stone node. It yields
  `stone_t1`, uses the Moonchalk rock model, and swaps to placeholder rubble
  when depleted.

Related art:

- `assets/trees/Silverneedle_Pine_T_var2.glb`: Silverneedle Pine model with
  `Full_Tree`, `Pine_leaves`, `De_Render`, and `Trunk` mesh pieces.
- `assets/Rocks/Moonchalk_Var1.glb`: Moonchalk Rock model used by the T1 stone
  resource.

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
- `active_visuals_path` and `depleted_visuals_path` are still available for
  simple scenes. Silverneedle Pine uses `GatherableResourceModelState` instead
  because active and depleted mesh pieces live inside one imported `.glb`.
- `active_mesh_names` are shown while the resource can be gathered.
- `depleted_mesh_names` are shown after the resource reaches 0 gather ticks.
- `disabled_mesh_names` keeps unused imported helper meshes hidden without
  deleting them from the source GLB.
- Player visibility is intentionally separate from gathering state. Silverneedle
  Pine uses `OccludableVisual3D` to pixel-fade only `Pine_leaves` when they
  block the player. Use the same pattern later for roofs, canopies, or tall
  props.
- Gatherable scenes should have a separate `StaticBody3D` trunk/rock collider on
  the resource obstacle layer. Keep it close to the solid shape; the larger
  `Selectable` area is only for clicking and hover.
- `add_to_group("gatherable_resources")` makes all gatherable nodes searchable
  by group later.

Keep this folder about the world resource itself. Movement, channeling, and
inventory rewards belong to player or inventory modules.
