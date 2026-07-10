# Persistence Architecture

Elderforge uses `PlayerDatabase` as the gameplay-facing persistence facade.
Gameplay code should not know whether records are stored in JSON, SQLite,
Postgres, or a remote service.

## Current Runtime

- Active backend: JSON.
- File: `user://player_database.json`.
- Owned data today: account name, display name, prototype password hash,
  appearance, inventory snapshot, stat snapshot, item transaction history, and
  position fields.

JSON is still useful while systems are moving quickly because it has no server
setup cost and is easy to inspect during playtests.

## Next Runtime Target

SQLite is the next persistence target for a single dedicated playtest server.
The migration files in `data/migrations/` define the schema we should move to:

- `accounts`
- `characters`
- `character_positions`
- `character_currency`
- `inventory_slots`
- `equipment_slots`
- `character_stats`
- `item_transactions`

Godot needs a SQLite GDExtension/addon before the SQLite backend can execute
queries at runtime. Until then, `sqlite_player_database_backend.gd` remains a
dormant slot and `PlayerDatabase` falls back to JSON.

## Expansion Rule

Use stable IDs now even when there is only one world:

- `account_id`
- `character_id`
- `world_id`
- `zone_id`

That lets us add zone servers, multiple worlds, or a larger database later
without rewriting every save record.

## Later Live MMO Path

The upgrade path should be:

1. JSON playtest snapshots.
2. SQLite single-server persistence.
3. Server-authoritative inventory/economy commands.
4. Postgres or another central database if multiple world/zone servers need to
   write shared state.

Do not skip directly to a giant backend unless the game actually needs it.
