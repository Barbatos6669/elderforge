# Persistence Migrations

These SQL files define the database shape Elderforge is growing toward.

Runtime status:

- The current active backend is still JSON through `PlayerDatabase`.
- SQLite is the next target, but Godot needs a SQLite GDExtension/addon before
  these migrations can run in-game.
- Keep migrations append-only. Do not rewrite old migrations once playtest data
  exists on a real server.

Naming:

- Use four digits and a short purpose: `0001_player_core.sql`.
- One migration should be safe to run once, inside a transaction.
- Prefer stable IDs like `account_id`, `character_id`, `world_id`, and
  `zone_id` even while the prototype only has one world and one zone.
