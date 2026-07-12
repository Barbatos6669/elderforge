# Shared Stat Scripts

This folder contains stat systems that are not owned by the player alone.

Files:

- `forged_trait_catalog.gd`: the shared list of Forged Traits, their unlock
  levels, point costs, active-slot rules, and stat modifiers.
- `forged_trait_loadout.gd`: stores one entity's level, earned trait points,
  purchased trait ranks, and active traits. Purchased traits do nothing until
  activated.
- `entity_stats.gd`: a small stat component for mobs, creatures, and NPCs. It
  uses the same stat ids as the player where possible, so AI can read stats
  without knowing whether the owner is a player or creature.

GDScript notes:

- `class_name` makes a script globally available by name after Godot imports it.
- `StringName` values, written like `&"max_health"`, are fast stable ids. Use
  them for stat ids and trait ids instead of display text.
- Traits are data first. Gameplay asks a loadout for `get_active_stat_modifiers()`
  and decides how to apply those numbers.
- The active-slot limit is level based. Buying a trait rank spends points, but
  activating it decides whether the stat bonus is currently applied.
- Mobs and creatures can use the same loadout script. Their AI may auto-purchase
  and activate traits later, while players will eventually choose traits through
  UI.

Use this folder when adding shared progression, trait, formula, buff, or entity
stat logic that should apply beyond the local player prefab.
