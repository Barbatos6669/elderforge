# Player Gathering Scripts

This folder owns the player's gathering flow: approach a resource, start a
channel, and apply rewards when the channel completes.

Files:

- `player_gathering.gd`: validates gatherable targets, finds approach
  destinations, starts `PlayerChanneling`, and adds completed yields to
  `PlayerInventory`. After a reward is accepted, it consumes one tick from the
  resource and queues the next channel if the resource still has ticks left.

Related scripts:

- `scripts/gathering/gatherable_resource_3d.gd`
- `scripts/player/channeling/player_channeling.gd`
- `scripts/inventory/player_inventory.gd`

GDScript notes:

- `context: Dictionary` carries gather result data through the channel system.
- `remaining_ticks` and `max_ticks` come from the resource and are used to name
  the channel, such as `Gathering Crude Tree 2/3`.
- `complete_gather()` rewards only the completed tick. Depletion belongs to the
  resource script through `consume_gather_tick()`.
- Natural replenishment also belongs to the resource script, so the player
  module does not need to know whether a tree restores ticks in 30 seconds or a
  rare ore restores them much later.
- `get_tree().get_first_node_in_group("player_inventory")` finds the inventory
  without hard-wiring this script to `Main.tscn`.
- `Node3D.global_position` is used to calculate range and facing direction.

Keep world resource data in `scripts/gathering/`; keep player behavior here.
