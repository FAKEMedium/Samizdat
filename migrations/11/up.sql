-- SMS schema for Teltonika device integration
-- Migration 11 - SMS functionality
-- Created: 2025-09-03

-- Create SMS schema
CREATE SCHEMA IF NOT EXISTS sms;

-- Create SMS messages table
CREATE TABLE IF NOT EXISTS sms.messages (
    id SERIAL PRIMARY KEY,
    direction VARCHAR(10) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    tx_id VARCHAR(50),
    msg_id VARCHAR(50),
    status VARCHAR(20) DEFAULT 'pending',
    sent_at TIMESTAMP WITH TIME ZONE,
    received_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_sms_messages_direction ON sms.messages (direction);
CREATE INDEX IF NOT EXISTS idx_sms_messages_phone ON sms.messages (phone);
CREATE INDEX IF NOT EXISTS idx_sms_messages_status ON sms.messages (status);
CREATE INDEX IF NOT EXISTS idx_sms_messages_created_at ON sms.messages (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sms_messages_phone_created ON sms.messages (phone, created_at DESC);