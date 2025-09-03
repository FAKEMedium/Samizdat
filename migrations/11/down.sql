-- SMS schema rollback
-- Migration 11 rollback - SMS functionality
-- Created: 2025-09-03

-- Drop indexes
DROP INDEX IF EXISTS sms.idx_sms_messages_phone_created;
DROP INDEX IF EXISTS sms.idx_sms_messages_created_at;
DROP INDEX IF EXISTS sms.idx_sms_messages_status;
DROP INDEX IF EXISTS sms.idx_sms_messages_phone;
DROP INDEX IF EXISTS sms.idx_sms_messages_direction;

-- Drop table
DROP TABLE IF EXISTS sms.messages;

-- Drop schema
DROP SCHEMA IF EXISTS sms;