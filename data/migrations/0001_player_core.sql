-- Elderforge persistence schema v1: accounts, characters, and positions.
-- This is authored for SQLite first. Keep it conservative so it can be moved
-- to Postgres later with minimal changes.

BEGIN;

CREATE TABLE IF NOT EXISTS schema_migrations (
	version INTEGER PRIMARY KEY,
	name TEXT NOT NULL,
	applied_at_unix INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS accounts (
	account_id INTEGER PRIMARY KEY AUTOINCREMENT,
	account_name TEXT NOT NULL UNIQUE,
	password_hash TEXT NOT NULL DEFAULT '',
	created_at_unix INTEGER NOT NULL,
	updated_at_unix INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS characters (
	character_id INTEGER PRIMARY KEY AUTOINCREMENT,
	account_id INTEGER NOT NULL,
	world_id TEXT NOT NULL DEFAULT 'main',
	zone_id TEXT NOT NULL DEFAULT 'starting_city',
	display_name TEXT NOT NULL,
	body_type TEXT NOT NULL DEFAULT 'male',
	skin_color TEXT NOT NULL DEFAULT '',
	hair_style TEXT NOT NULL DEFAULT 'short',
	hair_color TEXT NOT NULL DEFAULT '',
	created_at_unix INTEGER NOT NULL,
	updated_at_unix INTEGER NOT NULL,
	UNIQUE(account_id, world_id),
	FOREIGN KEY(account_id) REFERENCES accounts(account_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS character_positions (
	character_id INTEGER NOT NULL,
	world_id TEXT NOT NULL DEFAULT 'main',
	zone_id TEXT NOT NULL DEFAULT 'starting_city',
	x REAL NOT NULL DEFAULT 0,
	y REAL NOT NULL DEFAULT 0,
	z REAL NOT NULL DEFAULT 0,
	updated_at_unix INTEGER NOT NULL,
	PRIMARY KEY(character_id, world_id, zone_id),
	FOREIGN KEY(character_id) REFERENCES characters(character_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_characters_world_zone
	ON characters(world_id, zone_id);

INSERT OR IGNORE INTO schema_migrations(version, name, applied_at_unix)
VALUES(1, 'player_core', strftime('%s', 'now'));

COMMIT;
