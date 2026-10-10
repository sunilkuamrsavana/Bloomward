-- One account-owned, revision-checked snapshot. No emails, names from Clerk, or tokens.
CREATE TABLE IF NOT EXISTS account_snapshots (
  user_id TEXT PRIMARY KEY NOT NULL,
  revision INTEGER NOT NULL CHECK (revision > 0),
  snapshot TEXT NOT NULL CHECK (json_valid(snapshot)),
  updated_at TEXT NOT NULL
);
-- Prevent a still-valid short-lived session from recreating a deleted account's data.
CREATE TABLE IF NOT EXISTS deleted_accounts (
  user_id TEXT PRIMARY KEY NOT NULL,
  deleted_at TEXT NOT NULL
);
