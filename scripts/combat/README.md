# Combat Scripts

Shared combat components live here. Player-only combat behavior lives in
`scripts/player/combat/`.

Files:

- `combat_health.gd`: reusable health component used by prototype targets,
  players, and enemies. Emits `damage_taken` whenever damage actually lowers
  HP. Passive regeneration can be paused by combat state or future debuffs.
- `damage_request.gd`, `damage_result.gd`, and `damage_resolver.gd`: the shared
  damage application entry point. Player auto-attacks and hostile mob melee use
  this path while preserving current `CombatHealth.apply_damage` behavior,
  giving future mitigation and server-authoritative rules a single contract.
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

Use this folder for reusable combat state such as health, damage receivers,
threat tables, or future server-side combat helpers.
