-- Rollback migration 18
-- Reverses: meta tables creation, resources columns removal

SET search_path=public,pg_catalog,web,account;

-- [ Drop foreign keys ] --
ALTER TABLE web.metaconnections DROP CONSTRAINT IF EXISTS metavalueid_fk CASCADE;
ALTER TABLE web.metaconnections DROP CONSTRAINT IF EXISTS resourceid_fk CASCADE;
ALTER TABLE web.metavalues DROP CONSTRAINT IF EXISTS metakeyid_fk CASCADE;
ALTER TABLE web.metavalues DROP CONSTRAINT IF EXISTS languageid_fk CASCADE;

-- [ Drop tables ] --
DROP TABLE IF EXISTS web.metaconnections CASCADE;
DROP TABLE IF EXISTS web.metavalues CASCADE;
DROP TABLE IF EXISTS web.metakeys CASCADE;

-- [ Restore dropped columns ] --
ALTER TABLE web.resources ADD COLUMN IF NOT EXISTS title varchar NOT NULL DEFAULT '';
ALTER TABLE web.resources ADD COLUMN IF NOT EXISTS description varchar NOT NULL DEFAULT '';
