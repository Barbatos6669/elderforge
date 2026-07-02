# Player Gathering Scripts

This folder owns the player's gathering flow: approach a resource, start a
channel, and apply rewards when the channel completes.

Files:

- `player_gathering.gd`: validates gatherable targets, finds approach
  destinations, starts `PlayerChanneling`, and adds completed yields to
  `PlayerInventory`.

Related scripts:

- `scripts/gathering/gatherable_resource_3d.gd`
- `scripts/player/channeling/player_channeling.gd`
- `scripts/inventory/player_inventory.gd`

GDScript notes:

- `context: Dictionary` carries gather result data through the channel system.
- `get_tree().get_first_node_in_group("player_inventory")` finds the inventory
  without hard-wiring this script to `Main.tscn`.
- `Node3D.global_position` is used to calculate range and facing direction.

Keep world resource data in `scripts/gathering/`; keep player behavior here.
