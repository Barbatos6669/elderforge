# Combat Scripts

Shared combat components live here. Player-only combat behavior lives in
`scripts/player/combat/`.

Files:

- `combat_health.gd`: simple health component used by prototype targets.

GDScript notes:

- `signal health_changed(...)` style events let UI or combat systems react
  without hard dependencies.
- Health logic should stay generic here. Do not add player input or animation
  code to this folder.

Use this folder for reusable combat state such as health, damage receivers,
threat tables, or future server-side combat helpers.
