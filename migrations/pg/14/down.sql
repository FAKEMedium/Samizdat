-- Migration 14 down: Remove example schema and table

-- Drop the table first (CASCADE will drop all dependent objects like indexes)
DROP TABLE IF EXISTS example.example CASCADE;

-- Drop the schema
DROP SCHEMA IF EXISTS example;