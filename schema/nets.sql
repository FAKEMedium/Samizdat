-- Nets Payment Integration Schema
-- Documentation: https://developer.nexigroup.com/nexi-checkout/en-EU/docs/

-- Create schema for Nets tables
CREATE SCHEMA IF NOT EXISTS nets;
ALTER SCHEMA nets OWNER TO samizdat;

-- Payments table for tracking Nets Easy Checkout payments
CREATE TABLE IF NOT EXISTS nets.payments (
  id SERIAL PRIMARY KEY,
  payment_id VARCHAR(255) UNIQUE NOT NULL,  -- Nets payment ID
  checkout_url TEXT,                         -- Hosted payment page URL
  amount INTEGER NOT NULL,                   -- Amount in smallest currency unit (e.g., cents)
  currency VARCHAR(3) NOT NULL DEFAULT 'SEK',-- ISO 4217 currency code
  reference VARCHAR(255),                    -- Merchant reference
  status VARCHAR(50) NOT NULL DEFAULT 'created', -- created, pending, charged, cancelled, failed

  -- Customer information
  customer_email VARCHAR(255),
  customer_name VARCHAR(255),
  customer_phone VARCHAR(50),

  -- Order details
  order_items JSONB,                         -- Array of order items
  custom_data JSONB,                         -- Custom merchant data

  -- Payment details (populated after charge)
  charged_amount INTEGER,                    -- Actual charged amount
  charged_at TIMESTAMP,                      -- When payment was charged
  refunded_amount INTEGER DEFAULT 0,         -- Total refunded amount
  payment_method VARCHAR(100),               -- Card type, swish, etc.
  masked_pan VARCHAR(50),                    -- Masked card number

  -- Webhooks and events
  webhook_data JSONB,                        -- Latest webhook data
  events JSONB DEFAULT '[]'::JSONB,          -- Array of payment events

  -- Metadata
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  CONSTRAINT payments_amount_check CHECK (amount > 0)
);

ALTER TABLE nets.payments OWNER TO samizdat;

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_payments_payment_id ON nets.payments(payment_id);
CREATE INDEX IF NOT EXISTS idx_payments_reference ON nets.payments(reference);
CREATE INDEX IF NOT EXISTS idx_payments_status ON nets.payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON nets.payments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_customer_email ON nets.payments(customer_email);

-- Webhook log for debugging and audit trail
CREATE TABLE IF NOT EXISTS nets.webhook_log (
  id SERIAL PRIMARY KEY,
  payment_id VARCHAR(255),                   -- Related payment ID
  event_type VARCHAR(100),                   -- payment.created, payment.charged, etc.
  event_data JSONB NOT NULL,                 -- Full webhook payload
  source_ip INET,                            -- Request IP address
  verified BOOLEAN DEFAULT false,            -- IP verification status
  processed BOOLEAN DEFAULT false,           -- Whether webhook was processed
  processing_error TEXT,                     -- Error message if processing failed
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

ALTER TABLE nets.webhook_log OWNER TO samizdat;

CREATE INDEX IF NOT EXISTS idx_webhook_log_payment_id ON nets.webhook_log(payment_id);
CREATE INDEX IF NOT EXISTS idx_webhook_log_event_type ON nets.webhook_log(event_type);
CREATE INDEX IF NOT EXISTS idx_webhook_log_created_at ON nets.webhook_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_log_processed ON nets.webhook_log(processed);

-- Refunds table for tracking refund operations
CREATE TABLE IF NOT EXISTS nets.refunds (
  id SERIAL PRIMARY KEY,
  payment_id VARCHAR(255) NOT NULL REFERENCES nets.payments(payment_id),
  refund_id VARCHAR(255) UNIQUE NOT NULL,    -- Nets refund ID
  amount INTEGER NOT NULL,                   -- Refund amount in smallest currency unit
  reason TEXT,                               -- Reason for refund
  status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, completed, failed
  error_message TEXT,                        -- Error message if failed
  refunded_at TIMESTAMP,                     -- When refund was completed
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),

  CONSTRAINT refunds_amount_check CHECK (amount > 0)
);

ALTER TABLE nets.refunds OWNER TO samizdat;

CREATE INDEX IF NOT EXISTS idx_refunds_payment_id ON nets.refunds(payment_id);
CREATE INDEX IF NOT EXISTS idx_refunds_status ON nets.refunds(status);
CREATE INDEX IF NOT EXISTS idx_refunds_created_at ON nets.refunds(created_at DESC);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION nets.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at on payments
DROP TRIGGER IF EXISTS payments_updated_at ON nets.payments;
CREATE TRIGGER payments_updated_at
  BEFORE UPDATE ON nets.payments
  FOR EACH ROW
  EXECUTE FUNCTION nets.update_timestamp();

-- Comments for documentation
COMMENT ON SCHEMA nets IS 'Nets Easy Checkout payment integration';
COMMENT ON TABLE nets.payments IS 'Nets Easy Checkout payment records';
COMMENT ON COLUMN nets.payments.amount IS 'Amount in smallest currency unit (øre for SEK/NOK/DKK, cents for EUR)';
COMMENT ON COLUMN nets.payments.payment_id IS 'Unique payment identifier from Nets';
COMMENT ON COLUMN nets.payments.status IS 'Payment status: created, pending, charged, cancelled, failed';
COMMENT ON COLUMN nets.payments.custom_data IS 'Merchant custom data for linking to internal systems';

COMMENT ON TABLE nets.webhook_log IS 'Audit log of webhook events from Nets';
COMMENT ON COLUMN nets.webhook_log.verified IS 'Whether source IP matches Nets webhook origin CIDR';

COMMENT ON TABLE nets.refunds IS 'Refund operations for Nets payments';
