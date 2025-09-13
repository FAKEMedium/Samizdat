-- Diff code generated with pgModeler (PostgreSQL Database Modeler)
-- pgModeler version: 1.1.0-beta1
-- Diff date: 2025-09-13 17:08:20
-- Source model: samizdat
-- Database: samizdat
-- PostgreSQL version: 16.0

-- [ Diff summary ]
-- Dropped objects: 1
-- Created objects: 4
-- Changed objects: 0

SET search_path=public,pg_catalog,web,account;
-- ddl-end --


-- [ Created objects ] --
-- object: web.resourceconnections | type: TABLE --
DROP TABLE IF EXISTS web.resourceconnections;

-- [ Created constraints ] --
-- object: src_lang_uq | type: CONSTRAINT --
ALTER TABLE web.resources DROP CONSTRAINT IF EXISTS src_lang_uq;
-- ddl-end --
