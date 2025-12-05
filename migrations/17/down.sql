-- Reverse migration 17: Restore templateid_templates column

SET search_path=public,pg_catalog,zone;

-- Drop the new constraint and column
ALTER TABLE zone.template_records DROP CONSTRAINT IF EXISTS templateid_fk CASCADE;
ALTER TABLE zone.template_records DROP COLUMN IF EXISTS templateid CASCADE;

-- Restore the original column
ALTER TABLE zone.template_records ADD COLUMN templateid_templates bigint NOT NULL;

-- Restore the original foreign key
ALTER TABLE zone.template_records ADD CONSTRAINT templates_fk FOREIGN KEY (templateid_templates)
REFERENCES zone.templates (templateid) MATCH FULL
ON DELETE CASCADE ON UPDATE CASCADE;
