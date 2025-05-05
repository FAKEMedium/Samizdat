SET search_path=public,pg_catalog,account;
-- ddl-end --


-- [ Created objects ] --
-- object: useruuid | type: COLUMN --
ALTER TABLE account.users DROP COLUMN IF EXISTS useruuid CASCADE;
-- ddl-end --
