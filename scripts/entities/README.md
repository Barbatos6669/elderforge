# Entity Scripts

This folder stores behavior for world entities that are not the local player.

Files:

- `enemy_mob_ai.gd`: first-pass hostile AI for aggro, chase, melee attacks,
  smoothed chase movement, defeat cleanup, death playback, respawn timing, and
  leashing back to its spawn point. It emits `attack_started` for multiplayer
  animation sync and `attack_landed` when damage is actually applied. It can
  also call an optional `LootDropper3D` child when the mob is defeated, and can
  read optional `Stats` and `EquipmentLoadout` children for Forged Trait
  modifiers and item-authored combat abilities. Basic and ability impacts route
  through the shared typed damage resolver.
- `mob_equipment_loadout.gd`: mob-only equipped item source. It resolves
  prototype item ids such as `one_handed_sword_t1` into equipped-slot
  dictionaries without joining player inventory groups or persistence.
- `animals/animal_animation_controller.gd`: small animation bridge for imported
  animal GLBs that already contain idle, walk, attack, and death clips.
- `animals/skinnable_animal_3d.gd`: killable animal behavior. While alive it can
  wander and be attacked; after death it exposes the same gatherable resource
  interface as trees and rocks so the player can skin the corpse for hide.
- `npc/service_npc_visual_3d.gd`: reusable humanoid visual builder for town
  service NPCs such as refiners, tool makers, and smiths. The NPC scene handles
  body, hair, outfit, toon materials, and idle animation while the station script
  still owns recipes and interaction.
- `npc/service_npc_ambient_wander_3d.gd`: lightweight ambience for service NPCs.
  It moves the visual, body collider, selectable area, and selected ring together
  around the station so crafters/refiners can stroll without needing full AI.

GDScript notes:

- Enemy AI is kept off the player controller so hostile mobs can be spawned,
  tuned, or replaced without changing player input code.
- The AI expects reusable child components such as `Health`, `Selectable`, and
  `Animation`. This keeps combat state, targeting, and visuals modular.
- Add a `Stats`, `ForgedTraits`, and optional `TraitAllocator` child when a mob
  or creature should use the same trait/stat rules as players.
- Add an `EquipmentLoadout` child with prototype item ids when a humanoid mob
  should use the active abilities supplied by weapons, helmets, chest armor, or
  boots.
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
- Service NPC wander uses local offsets instead of pathfinding. That keeps
  refiner/crafter scenes easy to tune while we are still blocking out the town.

Use this folder when adding behavior for hostile mobs, NPCs, pets, summons, or
other world actors.
