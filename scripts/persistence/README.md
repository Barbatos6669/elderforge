# Persistence Scripts

This folder owns prototype save/load boundaries.

Files:

- `player_database.gd`: file-backed player database autoload. It stores player
  records in `user://player_database.json` with account name, display name,
  password hash for the prototype sign-in flow, appearance, inventory snapshots,
  stat snapshots, and last-position space for later.
- `json_player_database_backend.gd`: active storage backend for the current
  playtest. It reads and writes the whole player database snapshot as JSON.
- `sqlite_player_database_backend.gd`: dormant backend slot for the next
  database step. It will stay inactive until a SQLite GDExtension/addon is
  installed and its runtime API is wired.
- `res://data/migrations/`: SQL schema files for the SQLite/Postgres-shaped
  future backend.

How to use it:

- Use `/root/PlayerDatabase` instead of opening JSON files directly from
  gameplay scripts.
- Store compact snapshots, not live scene nodes. Inventory uses
  `PlayerInventory.get_network_snapshot()` and `apply_network_snapshot()`.
- Treat the method names as the future service boundary. If we replace JSON
  with SQLite or a web database, most gameplay scripts should not need to move.
- Keep backend-specific code in backend scripts. Gameplay should call
  `PlayerDatabase`; backend scripts should know about files, SQL, or migrations.

GDScript notes:

- `user://` is Godot's writable app-data folder. It is not committed to Git.
- `Dictionary.duplicate(true)` makes a deep copy so callers cannot mutate the
  database record by accident.
- `Variant` means the value may be any Godot type. The database sanitizes
  `Variant` input before saving so corrupt JSON or bad client data does not
  crash normal play.
- `@export_enum("json", "sqlite")` exposes the intended backend selector. JSON
  remains the runtime default until SQLite support is genuinely implemented.

Security note:

This is still playtest persistence, not production MMO authentication. The
server owns the file, but clients still report some prototype state. Real auth
will need server-issued sessions, password handling outside Godot gameplay code,
and server-authoritative inventory/economy commands.
