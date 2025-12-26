-- Diff code generated with pgModeler (PostgreSQL Database Modeler)
-- pgModeler version: 1.1.0-beta1
-- Diff date: 2025-12-26 22:17:32
-- Source model: samizdat
-- Database: samizdat
-- PostgreSQL version: 16.0

-- [ Diff summary ]
-- Dropped objects: 0
-- Created objects: 7
-- Changed objects: 0

SET search_path=public,pg_catalog,web,account;
-- ddl-end --


-- [ Dropped objects ] --
ALTER TABLE web.resources DROP COLUMN IF EXISTS title CASCADE;
-- ddl-end --
ALTER TABLE web.resources DROP COLUMN IF EXISTS description CASCADE;
-- ddl-end --


-- [ Created objects ] --
-- object: web.metakeys | type: TABLE --
-- DROP TABLE IF EXISTS web.metakeys CASCADE;
CREATE TABLE web.metakeys (
	metakeyid serial NOT NULL,
	metakey varchar NOT NULL,
	CONSTRAINT metakey_uq UNIQUE (metakey),
	CONSTRAINT metakeys_pk PRIMARY KEY (metakeyid)
);
-- ddl-end --
COMMENT ON COLUMN web.metakeys.metakey IS E'''tags'', ''categories'', etc.';
-- ddl-end --
ALTER TABLE web.metakeys OWNER TO samizdat;
-- ddl-end --

-- object: web.metavalues | type: TABLE --
-- DROP TABLE IF EXISTS web.metavalues CASCADE;
CREATE TABLE web.metavalues (
	metavalueid serial NOT NULL,
	metavalue varchar,
	metakeyid bigint NOT NULL,
	languageid bigint NOT NULL DEFAULT 1,
	CONSTRAINT metavalues_pk PRIMARY KEY (metakeyid,languageid),
	CONSTRAINT metavalues_uq UNIQUE (metavalueid)
);
-- ddl-end --
COMMENT ON COLUMN web.metavalues.metavalueid IS E'shared across languages for same concept';
-- ddl-end --
COMMENT ON COLUMN web.metavalues.metavalue IS E'localized value: ''one'', ''en'', ''ein''';
-- ddl-end --
ALTER TABLE web.metavalues OWNER TO samizdat;
-- ddl-end --

-- object: web.metaconnections | type: TABLE --
-- DROP TABLE IF EXISTS web.metaconnections CASCADE;
CREATE TABLE web.metaconnections (
	resourceid bigint NOT NULL,
	metavalueid bigint NOT NULL,
	CONSTRAINT metaconnections_pk PRIMARY KEY (resourceid,metavalueid)
);
-- ddl-end --
COMMENT ON COLUMN web.metaconnections.metavalueid IS E'links to all language versions';
-- ddl-end --
ALTER TABLE web.metaconnections OWNER TO samizdat;
-- ddl-end --



-- [ Created foreign keys ] --
-- object: languageid_fk | type: CONSTRAINT --
-- ALTER TABLE web.metavalues DROP CONSTRAINT IF EXISTS languageid_fk CASCADE;
ALTER TABLE web.metavalues ADD CONSTRAINT languageid_fk FOREIGN KEY (languageid)
REFERENCES public.languages (languageid) MATCH SIMPLE
ON DELETE NO ACTION ON UPDATE NO ACTION;
-- ddl-end --

-- object: metakeyid_fk | type: CONSTRAINT --
-- ALTER TABLE web.metavalues DROP CONSTRAINT IF EXISTS metakeyid_fk CASCADE;
ALTER TABLE web.metavalues ADD CONSTRAINT metakeyid_fk FOREIGN KEY (metakeyid)
REFERENCES web.metakeys (metakeyid) MATCH SIMPLE
ON DELETE CASCADE ON UPDATE CASCADE;
-- ddl-end --

-- object: resourceid_fk | type: CONSTRAINT --
-- ALTER TABLE web.metaconnections DROP CONSTRAINT IF EXISTS resourceid_fk CASCADE;
ALTER TABLE web.metaconnections ADD CONSTRAINT resourceid_fk FOREIGN KEY (resourceid)
REFERENCES web.resources (resourceid) MATCH SIMPLE
ON DELETE CASCADE ON UPDATE CASCADE;
-- ddl-end --

-- object: metavalueid_fk | type: CONSTRAINT --
-- ALTER TABLE web.metaconnections DROP CONSTRAINT IF EXISTS metavalueid_fk CASCADE;
ALTER TABLE web.metaconnections ADD CONSTRAINT metavalueid_fk FOREIGN KEY (metavalueid)
REFERENCES web.metavalues (metavalueid) MATCH SIMPLE
ON DELETE CASCADE ON UPDATE CASCADE;
-- ddl-end --

