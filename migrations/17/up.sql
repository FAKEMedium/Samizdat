-- Diff code generated with pgModeler (PostgreSQL Database Modeler)
-- pgModeler version: 1.1.0-beta1
-- Diff date: 2025-12-05 23:45:03
-- Source model: samizdat
-- Database: samizdat
-- PostgreSQL version: 16.0

-- [ Diff summary ]
-- Dropped objects: 1
-- Created objects: 2
-- Changed objects: 0

SET search_path=public,pg_catalog,zone;
-- ddl-end --


-- [ Dropped objects ] --
ALTER TABLE zone.template_records DROP CONSTRAINT IF EXISTS templates_fk CASCADE;
-- ddl-end --
ALTER TABLE zone.template_records DROP COLUMN IF EXISTS templateid_templates CASCADE;
-- ddl-end --


-- [ Created objects ] --
-- object: templateid | type: COLUMN --
-- ALTER TABLE zone.template_records DROP COLUMN IF EXISTS templateid CASCADE;
ALTER TABLE zone.template_records ADD COLUMN templateid bigint NOT NULL;
-- ddl-end --




-- [ Created foreign keys ] --
-- object: templateid_fk | type: CONSTRAINT --
-- ALTER TABLE zone.template_records DROP CONSTRAINT IF EXISTS templateid_fk CASCADE;
ALTER TABLE zone.template_records ADD CONSTRAINT templateid_fk FOREIGN KEY (templateid)
REFERENCES zone.templates (templateid) MATCH SIMPLE
ON DELETE CASCADE ON UPDATE CASCADE;
-- ddl-end --

