-- Diff code generated with pgModeler (PostgreSQL Database Modeler)
-- pgModeler version: 1.1.0-beta1
-- Diff date: 2025-09-11 21:25:50
-- Source model: samizdat
-- Database: samizdat
-- PostgreSQL version: 16.0

-- [ Diff summary ]
-- Dropped objects: 0
-- Created objects: 2
-- Changed objects: 0

SET search_path=public,pg_catalog,web,account;
-- ddl-end --


-- [ Created objects ] --
-- object: src | type: COLUMN --
 ALTER TABLE web.resources DROP COLUMN IF EXISTS src CASCADE;
-- ddl-end --

COMMENT ON COLUMN web.resources.src IS E'Markdown source file in src tree.';
-- ddl-end --




-- [ Created foreign keys ] --
-- object: users_fk | type: CONSTRAINT --
ALTER TABLE web.homes DROP CONSTRAINT IF EXISTS users_fk CASCADE;
-- ddl-end --

