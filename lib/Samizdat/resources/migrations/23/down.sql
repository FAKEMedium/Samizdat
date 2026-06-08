-- Reverse migration 23: Restore userid-based password lookup

SET search_path=public,pg_catalog,account;

-- Restore userid column to passwords
ALTER TABLE account.passwords
  ADD COLUMN IF NOT EXISTS userid bigint;

-- Drop FK constraint
ALTER TABLE account.users DROP CONSTRAINT IF EXISTS users_passwordid_fk;

-- Drop passwordid column from users
ALTER TABLE account.users DROP COLUMN IF EXISTS passwordid;
