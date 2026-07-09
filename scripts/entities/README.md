# Entity Scripts

This folder stores behavior for world entities that are not the local player.

Files:

- `enemy_mob_ai.gd`: first-pass hostile AI for aggro, chase, melee attacks,
  smoothed chase movement, defeat cleanup, death playback, respawn timing, and
  leashing back to its spawn point. It emits `attack_started` for multiplayer
  animation sync and `attack_landed` when damage is actually applied. It can
  also call an optional `LootDropper3D` child when the mob is defeated.
- `animals/animal_animation_controller.gd`: small animation bridge for imported
  animal GLBs that already contain idle, walk, attack, and death clips.
- `animals/skinnable_animal_3d.gd`: killable animal behavior. While alive it can
  wander and be attacked; after death it exposes the same gatherable resource
  interface as trees and rocks so the player can skin the corpse for hide.

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
- Skinnable animals join both `network_mobs` and `gatherable_resources`, because
  their health/death state uses mob sync and their corpse skinning state uses
  resource sync.

Use this folder when adding behavior for hostile mobs, NPCs, pets, summons, or
other world actors.
