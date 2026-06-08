-- Reverse migration 21

SET search_path=public,pg_catalog,customer,account,article,web;
-- ddl-end --

-- Remove FK constraints from customer.customers
ALTER TABLE customer.customers DROP CONSTRAINT IF EXISTS customers_creator_fk;
-- ddl-end --
ALTER TABLE customer.customers DROP CONSTRAINT IF EXISTS customers_updater_fk;
-- ddl-end --

-- Remove lastcheck from account.contacts
ALTER TABLE account.contacts
  DROP COLUMN IF EXISTS lastcheck;
-- ddl-end --

-- Remove audit columns from customer.customers
ALTER TABLE customer.customers
  DROP COLUMN IF EXISTS created,
  DROP COLUMN IF EXISTS updated,
  DROP COLUMN IF EXISTS creator,
  DROP COLUMN IF EXISTS updater;
-- ddl-end --

-- Remove FK constraint from customer.settings
ALTER TABLE customer.settings DROP CONSTRAINT IF EXISTS settings_recommendedby_fk;
-- ddl-end --

-- Remove added fields from customer.settings
ALTER TABLE customer.settings
  DROP COLUMN IF EXISTS recommendedby,
  DROP COLUMN IF EXISTS period,
  DROP COLUMN IF EXISTS invoicetype,
  DROP COLUMN IF EXISTS vat,
  DROP COLUMN IF EXISTS trust,
  DROP COLUMN IF EXISTS active,
  DROP COLUMN IF EXISTS newsletter,
  DROP COLUMN IF EXISTS reference,
  DROP COLUMN IF EXISTS freetext;
-- ddl-end --

-- Remove vatno and moss from customer.orgnos
ALTER TABLE customer.orgnos
  DROP COLUMN IF EXISTS vatno,
  DROP COLUMN IF EXISTS moss;
-- ddl-end --
