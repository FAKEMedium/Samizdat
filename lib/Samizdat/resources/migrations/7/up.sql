-- Diff code generated with pgModeler (PostgreSQL Database Modeler)
-- pgModeler version: 0.9.4
-- Diff date: 2025-05-05 15:22:20
-- Source model: samizdat
-- Database: samizdat
-- PostgreSQL version: 13.0

-- [ Diff summary ]
-- Dropped objects: 0
-- Created objects: 2
-- Changed objects: 0

SET search_path=public,pg_catalog,account;
-- ddl-end --


-- [ Created objects ] --
-- object: useruuid | type: COLUMN --
-- ALTER TABLE account.users DROP COLUMN IF EXISTS useruuid CASCADE;
ALTER TABLE account.users ADD COLUMN useruuid uuid NOT NULL DEFAULT gen_random_uuid();
-- ddl-end --


