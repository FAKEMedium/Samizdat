-- Migration 21: Add missing fields from MySQL schema
-- Add vatno/moss to orgnos, various settings fields, and audit columns to customers

SET search_path=public,pg_catalog,customer,account,article,web;
-- ddl-end --

-- Add vatno and moss to customer.orgnos
ALTER TABLE customer.orgnos
  ADD COLUMN IF NOT EXISTS vatno VARCHAR(25),
  ADD COLUMN IF NOT EXISTS moss BOOLEAN DEFAULT FALSE;
-- ddl-end --
COMMENT ON COLUMN customer.orgnos.vatno IS 'VAT registration number';
-- ddl-end --
COMMENT ON COLUMN customer.orgnos.moss IS 'Mini One Stop Shop (EU VAT scheme)';
-- ddl-end --

-- Add missing fields to customer.settings
ALTER TABLE customer.settings
  ADD COLUMN IF NOT EXISTS recommendedby TEXT,
  ADD COLUMN IF NOT EXISTS period VARCHAR(20) DEFAULT 'monthly',
  ADD COLUMN IF NOT EXISTS invoicetype VARCHAR(20) DEFAULT 'email',
  ADD COLUMN IF NOT EXISTS vat NUMERIC(5,4) DEFAULT 0.25,
  ADD COLUMN IF NOT EXISTS trust INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS newsletter BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS reference VARCHAR(255),
  ADD COLUMN IF NOT EXISTS freetext TEXT;
-- ddl-end --
COMMENT ON COLUMN customer.settings.recommendedby IS 'Name of referring customer';
-- ddl-end --
COMMENT ON COLUMN customer.settings.period IS 'Billing period (monthly, quarterly, yearly)';
-- ddl-end --
COMMENT ON COLUMN customer.settings.invoicetype IS 'Invoice delivery method (email, paper, einvoice)';
-- ddl-end --
COMMENT ON COLUMN customer.settings.vat IS 'VAT rate (0.25 = 25%)';
-- ddl-end --
COMMENT ON COLUMN customer.settings.trust IS 'Trust level for payment terms';
-- ddl-end --
COMMENT ON COLUMN customer.settings.active IS 'Customer account is active';
-- ddl-end --
COMMENT ON COLUMN customer.settings.newsletter IS 'Subscribed to newsletter';
-- ddl-end --
COMMENT ON COLUMN customer.settings.reference IS 'Customer reference for invoices';
-- ddl-end --
COMMENT ON COLUMN customer.settings.freetext IS 'Free text notes about customer';
-- ddl-end --

-- Add audit columns to customer.customers
ALTER TABLE customer.customers
  ADD COLUMN IF NOT EXISTS created TIMESTAMP DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated TIMESTAMP,
  ADD COLUMN IF NOT EXISTS creator INTEGER,
  ADD COLUMN IF NOT EXISTS updater INTEGER;
-- ddl-end --
COMMENT ON COLUMN customer.customers.created IS 'Record creation timestamp';
-- ddl-end --
COMMENT ON COLUMN customer.customers.updated IS 'Last update timestamp';
-- ddl-end --
COMMENT ON COLUMN customer.customers.creator IS 'User who created the record';
-- ddl-end --
COMMENT ON COLUMN customer.customers.updater IS 'User who last updated the record';
-- ddl-end --

-- Add lastcheck to account.contacts (for verifying contact details)
ALTER TABLE account.contacts
  ADD COLUMN IF NOT EXISTS lastcheck TIMESTAMP;
-- ddl-end --
COMMENT ON COLUMN account.contacts.lastcheck IS 'Last verification of contact details';
-- ddl-end --

-- Add FK for creator/updater
ALTER TABLE customer.customers
  ADD CONSTRAINT customers_creator_fk FOREIGN KEY (creator)
    REFERENCES account.users (userid) MATCH SIMPLE
    ON DELETE SET NULL ON UPDATE CASCADE;
-- ddl-end --
ALTER TABLE customer.customers
  ADD CONSTRAINT customers_updater_fk FOREIGN KEY (updater)
    REFERENCES account.users (userid) MATCH SIMPLE
    ON DELETE SET NULL ON UPDATE CASCADE;
-- ddl-end --
