-- Reverse migration 20

SET search_path=public,pg_catalog,customer,account,article,web;
-- ddl-end --

-- Revert FK constraint to original (incorrect) state
ALTER TABLE customer.customers DROP CONSTRAINT IF EXISTS contacts_fk;
-- ddl-end --
ALTER TABLE customer.customers
  ADD CONSTRAINT contacts_fk FOREIGN KEY (customerid)
    REFERENCES account.contacts (contactid) MATCH SIMPLE
    ON DELETE SET NULL ON UPDATE CASCADE;
-- ddl-end --
