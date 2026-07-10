-- Elderforge persistence schema v2: stable account creation order.
-- `join_order` preserves the first, second, third, etc. account created on a
-- server so early playtesters can be recognized later without scraping logs.

BEGIN;

ALTER TABLE accounts
	ADD COLUMN join_order INTEGER NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_join_order
	ON accounts(join_order)
	WHERE join_order > 0;

INSERT OR IGNORE INTO schema_migrations(version, name, applied_at_unix)
VALUES(2, 'account_join_order', strftime('%s', 'now'));

COMMIT;
