-- Reverse migration 24: Move websites/domains back to web schema as webservices
-- Handles both old (webservices/webserviceid) and new (websites/websiteid) versions

SET search_path TO public,pg_catalog,web,account,customer,website,certificate;

-- 1. Drop FK constraints from other schemas to website
ALTER TABLE web.resources DROP CONSTRAINT IF EXISTS resources_websiteid_fk;
ALTER TABLE web.resources DROP CONSTRAINT IF EXISTS webservices_fk;
ALTER TABLE web.menus DROP CONSTRAINT IF EXISTS menus_websiteid_fk;
ALTER TABLE web.menus DROP CONSTRAINT IF EXISTS webservices_fk;
ALTER TABLE customer.services DROP CONSTRAINT IF EXISTS services_websiteid_fk;
ALTER TABLE customer.services DROP CONSTRAINT IF EXISTS webservices_fk;

-- 2. Drop FK constraints in website schema (handle both old and new names)
ALTER TABLE website.domains DROP CONSTRAINT IF EXISTS domains_websiteid_fk;
ALTER TABLE website.domains DROP CONSTRAINT IF EXISTS domains_webserviceid_fk;
ALTER TABLE website.domains DROP CONSTRAINT IF EXISTS domains_customerid_fk;
ALTER TABLE website.domains DROP CONSTRAINT IF EXISTS webservices_fk;

-- Try dropping constraints from both table names
DO $$
BEGIN
  -- New name: websites
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'website' AND table_name = 'websites') THEN
    ALTER TABLE website.websites DROP CONSTRAINT IF EXISTS websites_primarydomain_fk;
    ALTER TABLE website.websites DROP CONSTRAINT IF EXISTS websites_serverid_fk;
    ALTER TABLE website.websites DROP CONSTRAINT IF EXISTS websites_passwordid_fk;
    ALTER TABLE website.websites DROP CONSTRAINT IF EXISTS websites_certificateid_fk;
    ALTER TABLE website.websites DROP CONSTRAINT IF EXISTS websites_customerid_fk;
    ALTER TABLE website.websites DROP CONSTRAINT IF EXISTS websites_shellid_fk;
  END IF;
  -- Old name: webservices
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'website' AND table_name = 'webservices') THEN
    ALTER TABLE website.webservices DROP CONSTRAINT IF EXISTS webservices_primarydomain_fk;
    ALTER TABLE website.webservices DROP CONSTRAINT IF EXISTS webservices_serverid_fk;
    ALTER TABLE website.webservices DROP CONSTRAINT IF EXISTS webservices_passwordid_fk;
    ALTER TABLE website.webservices DROP CONSTRAINT IF EXISTS webservices_certificateid_fk;
    ALTER TABLE website.webservices DROP CONSTRAINT IF EXISTS webservices_customerid_fk;
  END IF;
END $$;

-- 3. Drop config tables
DROP TABLE IF EXISTS website.phpconfigs CASCADE;
DROP TABLE IF EXISTS website.serverextras CASCADE;

-- 4. Rename table and move to web schema
DO $$
BEGIN
  -- If new name exists, rename to old name first
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'website' AND table_name = 'websites') THEN
    ALTER TABLE website.websites RENAME TO webservices;
  END IF;
  -- Rename sequence if it was renamed (handle both cases)
  IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'website' AND sequencename = 'websites_websiteid_seq') THEN
    ALTER SEQUENCE website.websites_websiteid_seq RENAME TO webservices_webserviceid_seq;
  END IF;
END $$;

ALTER TABLE website.webservices SET SCHEMA web;
ALTER TABLE website.domains SET SCHEMA web;

-- 5. Rename columns back if they were renamed (websiteid -> webserviceid)
DO $$
BEGIN
  -- web.resources
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'web' AND table_name = 'resources' AND column_name = 'websiteid') THEN
    ALTER TABLE web.resources RENAME COLUMN websiteid TO webserviceid;
  END IF;
  -- web.menus
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'web' AND table_name = 'menus' AND column_name = 'websiteid') THEN
    ALTER TABLE web.menus RENAME COLUMN websiteid TO webserviceid;
  END IF;
  -- customer.services
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'customer' AND table_name = 'services' AND column_name = 'websiteid') THEN
    ALTER TABLE customer.services RENAME COLUMN websiteid TO webserviceid;
  END IF;
  -- web.domains
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'web' AND table_name = 'domains' AND column_name = 'websiteid') THEN
    ALTER TABLE web.domains RENAME COLUMN websiteid TO webserviceid;
  END IF;
  -- web.webservices
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'web' AND table_name = 'webservices' AND column_name = 'websiteid') THEN
    ALTER TABLE web.webservices RENAME COLUMN websiteid TO webserviceid;
  END IF;
  -- Rename 'home' back to 'path' if needed
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'web' AND table_name = 'webservices' AND column_name = 'home') THEN
    ALTER TABLE web.webservices RENAME COLUMN home TO path;
  END IF;
END $$;

-- 6. Drop new columns from webservices
ALTER TABLE web.webservices
  DROP COLUMN IF EXISTS customerid,
  DROP COLUMN IF EXISTS serverid,
  DROP COLUMN IF EXISTS passwordid,
  DROP COLUMN IF EXISTS certificateid,
  DROP COLUMN IF EXISTS shellid,
  DROP COLUMN IF EXISTS ip4,
  DROP COLUMN IF EXISTS ip6,
  DROP COLUMN IF EXISTS ip_only,
  DROP COLUMN IF EXISTS redirecturl,
  DROP COLUMN IF EXISTS active,
  DROP COLUMN IF EXISTS web_usage;

-- 7. Drop new columns from domains
ALTER TABLE web.domains
  DROP COLUMN IF EXISTS customerid,
  DROP COLUMN IF EXISTS incert;

-- 8. Re-add original FK constraints
ALTER TABLE web.webservices ADD CONSTRAINT primarydomain_fk
  FOREIGN KEY (primarydomain) REFERENCES web.domains (domainid)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE web.domains ADD CONSTRAINT webservices_fk
  FOREIGN KEY (webserviceid) REFERENCES web.webservices (webserviceid)
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE web.resources ADD CONSTRAINT webservices_fk
  FOREIGN KEY (webserviceid) REFERENCES web.webservices (webserviceid)
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE web.menus ADD CONSTRAINT webservices_fk
  FOREIGN KEY (webserviceid) REFERENCES web.webservices (webserviceid)
  ON DELETE CASCADE ON UPDATE CASCADE;

-- 9. Drop new tables in reverse dependency order
DROP TABLE IF EXISTS website.servers CASCADE;
DROP TABLE IF EXISTS website.servertypes CASCADE;
DROP TABLE IF EXISTS website.shells CASCADE;
DROP TABLE IF EXISTS certificate.certificates CASCADE;
DROP TABLE IF EXISTS certificate.issuers CASCADE;

-- 10. Drop new schemas
DROP SCHEMA IF EXISTS website CASCADE;
DROP SCHEMA IF EXISTS certificate CASCADE;
