-- Reverse migration 16: Drop zone schema and tables

DROP TABLE IF EXISTS zone.template_records CASCADE;
DROP TABLE IF EXISTS zone.templates CASCADE;
DROP SCHEMA IF EXISTS zone CASCADE;
