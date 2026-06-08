-- Reverse migration 22: Database management schema

DROP TABLE IF EXISTS database.databases CASCADE;
DROP TABLE IF EXISTS database.databasetypes CASCADE;
DROP SCHEMA IF EXISTS database CASCADE;
