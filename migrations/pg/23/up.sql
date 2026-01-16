-- Migration 23: Refactor passwords - move passwordid to users table
-- Cleaner schema: user references password instead of password referencing user

SET search_path=public,pg_catalog,account;

-- Add passwordid column to account.users
ALTER TABLE account.users
  ADD COLUMN IF NOT EXISTS passwordid bigint;

-- Add FK constraint
ALTER TABLE account.users
  ADD CONSTRAINT users_passwordid_fk FOREIGN KEY (passwordid)
  REFERENCES account.passwords (passwordid) MATCH SIMPLE
  ON DELETE SET NULL ON UPDATE CASCADE;

-- Remove userid from passwords (relationship is now via users.passwordid)
ALTER TABLE account.passwords DROP COLUMN IF EXISTS userid;
