-- Elderforge persistence schema v3: inventory, equipment, currency, stats,
-- and item transaction history.

BEGIN;

CREATE TABLE IF NOT EXISTS character_currency (
	character_id INTEGER PRIMARY KEY,
	silver INTEGER NOT NULL DEFAULT 0 CHECK(silver >= 0),
	gold INTEGER NOT NULL DEFAULT 0 CHECK(gold >= 0),
	updated_at_unix INTEGER NOT NULL,
	FOREIGN KEY(character_id) REFERENCES characters(character_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS inventory_slots (
	character_id INTEGER NOT NULL,
	container_id TEXT NOT NULL DEFAULT 'bag',
	slot_index INTEGER NOT NULL,
	item_id TEXT NOT NULL,
	quantity INTEGER NOT NULL CHECK(quantity > 0),
	updated_at_unix INTEGER NOT NULL,
	PRIMARY KEY(character_id, container_id, slot_index),
	FOREIGN KEY(character_id) REFERENCES characters(character_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS equipment_slots (
	character_id INTEGER NOT NULL,
	slot_id TEXT NOT NULL,
	item_id TEXT NOT NULL,
	quantity INTEGER NOT NULL DEFAULT 1 CHECK(quantity > 0),
	updated_at_unix INTEGER NOT NULL,
	PRIMARY KEY(character_id, slot_id),
	FOREIGN KEY(character_id) REFERENCES characters(character_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS character_stats (
	character_id INTEGER NOT NULL,
	stat_id TEXT NOT NULL,
	value REAL NOT NULL DEFAULT 0,
	updated_at_unix INTEGER NOT NULL,
	PRIMARY KEY(character_id, stat_id),
	FOREIGN KEY(character_id) REFERENCES characters(character_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS item_transactions (
	transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
	character_id INTEGER,
	world_id TEXT NOT NULL DEFAULT 'main',
	zone_id TEXT NOT NULL DEFAULT 'starting_city',
	transaction_type TEXT NOT NULL,
	item_id TEXT NOT NULL,
	quantity_delta INTEGER NOT NULL,
	context_json TEXT NOT NULL DEFAULT '{}',
	created_at_unix INTEGER NOT NULL,
	FOREIGN KEY(character_id) REFERENCES characters(character_id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_inventory_slots_character
	ON inventory_slots(character_id, container_id);

CREATE INDEX IF NOT EXISTS idx_item_transactions_character_created
	ON item_transactions(character_id, created_at_unix);

INSERT OR IGNORE INTO schema_migrations(version, name, applied_at_unix)
VALUES(3, 'inventory_economy', strftime('%s', 'now'));

COMMIT;
