# Combat Scripts

Shared combat components live here. Player-only combat behavior lives in
`scripts/player/combat/`.

Files:

- `combat_health.gd`: reusable health component used by prototype targets,
  players, and enemies. Emits `damage_taken` whenever damage actually lowers
  HP. Passive regeneration can be paused by combat state or future debuffs.
- `damage_request.gd`, `damage_result.gd`, and `damage_resolver.gd`: the shared
  damage application entry point. Player auto-attacks and equipment abilities,
  mob basic attacks and equipment abilities, and server-routed mob damage use
  this path. Physical damage checks armor, magical damage checks magical
  resistance, and true damage bypasses defense mitigation.
- `combat_state.gd`: reusable in-combat/out-of-combat timer. Gameplay systems
  call `notify_combat_activity()` to keep the owner in combat.
- `resource_pool.gd`: reusable current/max resource pool for mana, energy,
  stamina, and future spell costs.
- `damage_number_emitter_3d.gd`: listens to a nearby `CombatHealth` node and
  spawns readable floating damage numbers.
- `floating_damage_number_3d.gd`: one short-lived 3D number that faces the
  camera, rises, fades, and frees itself.

GDScript notes:

- `signal health_changed(...)` style events let UI or combat systems react
  without hard dependencies.
- Health logic should stay generic here. Do not add player input or animation
  code to this folder.
- Attack callers validate intent, hostility, range, and timing before creating
  a request. `DamageResolver` normalizes the damage type, reads defense, applies
  mitigation, and delegates immunity, absorb shields, health loss, and defeat
  to `CombatHealth`.
- `DamageResult.applied_damage` means actual health lost after mitigation,
  immunity, and absorb shields. Use it for confirmed-hit feedback.

Use this folder for reusable combat state such as health, damage receivers,
threat tables, or future server-side combat helpers.
