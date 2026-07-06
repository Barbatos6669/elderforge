# Entity Scripts

This folder stores behavior for world entities that are not the local player.

Files:

- `enemy_mob_ai.gd`: first-pass hostile AI for aggro, chase, melee attacks,
  smoothed chase movement, defeat cleanup, death playback, respawn timing, and
  leashing back to its spawn point. It can also call an optional `LootDropper3D`
  child when the mob is defeated.

GDScript notes:

- Enemy AI is kept off the player controller so hostile mobs can be spawned,
  tuned, or replaced without changing player input code.
- The AI expects reusable child components such as `Health`, `Selectable`, and
  `Animation`. This keeps combat state, targeting, and visuals modular.
- Defeated mobs are made unselectable/non-colliding immediately, play their
  death animation while still visible, then hide after the visible death window
  until `respawn_delay` finishes.
- Loot drops are delegated to a child component so enemy behavior does not need
  to know loot-table or loot-bag details.
- `get_tree().get_nodes_in_group("player")` finds player characters that can
  draw aggro. The player controller adds the local player to that group.

Use this folder when adding behavior for hostile mobs, NPCs, pets, summons, or
other world actors.
