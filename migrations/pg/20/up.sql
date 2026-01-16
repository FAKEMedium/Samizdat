-- Diff code generated with pgModeler (PostgreSQL Database Modeler)
-- pgModeler version: 1.1.0-beta1
-- Diff date: 2026-01-14 21:34:18
-- Source model: samizdat
-- Database: samizdat
-- PostgreSQL version: 16.0

-- [ Diff summary ]
-- Dropped objects: 0
-- Created objects: 0
-- Changed objects: 2

SET search_path=public,pg_catalog,customer,account,article,web;
-- ddl-end --


-- [ Changed objects ] --
COMMENT ON TABLE customer.customers IS E'Customer';
-- ddl-end --
COMMENT ON COLUMN customer.customers.entitytypeid IS E'Legal entitype';
-- ddl-end --

-- Fix FK constraint: should reference contactid, not customerid
ALTER TABLE customer.customers DROP CONSTRAINT IF EXISTS contacts_fk;
-- ddl-end --
ALTER TABLE customer.customers
  ADD CONSTRAINT contacts_fk FOREIGN KEY (contactid)
    REFERENCES account.contacts (contactid) MATCH SIMPLE
    ON DELETE SET NULL ON UPDATE CASCADE;
-- ddl-end --
