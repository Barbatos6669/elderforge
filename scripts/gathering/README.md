# Gathering Scripts

World resource metadata lives here. Player-side gathering behavior lives in
`scripts/player/gathering/`.

Files:

- `gatherable_resource_3d.gd`: metadata attached to a resource node, such as a
  tree. It defines resource family, tier, yield item id, quantity, and gather
  duration.

Related scene:

- `scenes/gathering/Tier1Tree.tscn`

GDScript notes:

- `extends Node3D` means the resource has a 3D transform in the world.
- `get_yield_data() -> Dictionary` returns a small data packet for the player
  gathering module.
- `add_to_group("gatherable_resources")` makes all gatherable nodes searchable
  by group later.

Keep this folder about the world resource itself. Movement, channeling, and
inventory rewards belong to player or inventory modules.
