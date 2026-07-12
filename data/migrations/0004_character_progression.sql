-- Elderforge persistence schema v4: character progression and forged traits.

BEGIN;

CREATE TABLE IF NOT EXISTS character_progression (
	character_id INTEGER PRIMARY KEY,
	character_level INTEGER NOT NULL DEFAULT 1 CHECK(character_level >= 1),
	current_xp INTEGER NOT NULL DEFAULT 0 CHECK(current_xp >= 0),
	total_xp INTEGER NOT NULL DEFAULT 0 CHECK(total_xp >= 0),
	unspent_trait_points INTEGER NOT NULL DEFAULT 0 CHECK(unspent_trait_points >= 0),
	purchased_traits_json TEXT NOT NULL DEFAULT '{}',
	active_traits_json TEXT NOT NULL DEFAULT '[]',
	updated_at_unix INTEGER NOT NULL,
	FOREIGN KEY(character_id) REFERENCES characters(character_id) ON DELETE CASCADE
);

INSERT OR IGNORE INTO schema_migrations(version, name, applied_at_unix)
VALUES(4, 'character_progression', strftime('%s', 'now'));

COMMIT;
