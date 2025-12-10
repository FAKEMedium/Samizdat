-- Stripe Payment Integration Schema
-- Embedded components with API key authentication
-- Documentation: https://docs.stripe.com

-- Create Stripe schema
CREATE SCHEMA IF NOT EXISTS stripe;
ALTER SCHEMA stripe OWNER TO samizdat;

-- Payment intents table for tracking Stripe payments
CREATE TABLE IF NOT EXISTS stripe.payments (
  paymentid SERIAL PRIMARY KEY,
  customerid BIGINT,                            -- Link to customer.customers
  payment_intent_id VARCHAR(255) UNIQUE,        -- Stripe PaymentIntent ID (pi_xxx)
  checkout_session_id VARCHAR(255),             -- Stripe Checkout Session ID (cs_xxx)
  amount INTEGER NOT NULL,                      -- Amount in smallest currency unit (cents/öre)
  currency VARCHAR(3) NOT NULL DEFAULT 'SEK',   -- ISO 4217 currency code
  status VARCHAR(50) NOT NULL DEFAULT 'created', -- created, pending, succeeded, failed, canceled

  -- Customer info from Stripe
  stripe_customer_id VARCHAR(255),              -- Stripe Customer ID (cus_xxx)
  customer_email VARCHAR(255),
  customer_name VARCHAR(255),

  -- Payment details
  payment_method_type VARCHAR(50),              -- card, klarna, swish, etc.
  description TEXT,
  metadata JSONB,                               -- Custom metadata

  -- Error info
  error_code VARCHAR(100),
  error_message TEXT,

  -- Webhook tracking
  last_webhook_event VARCHAR(100),
  webhook_data JSONB,

  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMP,

  CONSTRAINT stripe_payments_amount_check CHECK (amount > 0)
);
ALTER TABLE stripe.payments OWNER TO samizdat;

-- Indexes for quick lookups
CREATE INDEX IF NOT EXISTS idx_stripe_payments_intent ON stripe.payments(payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_stripe_payments_session ON stripe.payments(checkout_session_id);
CREATE INDEX IF NOT EXISTS idx_stripe_payments_status ON stripe.payments(status);
CREATE INDEX IF NOT EXISTS idx_stripe_payments_created ON stripe.payments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stripe_payments_customer ON stripe.payments(customerid);
CREATE INDEX IF NOT EXISTS idx_stripe_payments_stripe_customer ON stripe.payments(stripe_customer_id);

-- Foreign key to customer
ALTER TABLE stripe.payments
  ADD CONSTRAINT customers_fk FOREIGN KEY (customerid)
    REFERENCES customer.customers (customerid) MATCH SIMPLE
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Webhook event log for debugging and audit trail
CREATE TABLE IF NOT EXISTS stripe.webhook_log (
  webhookid SERIAL PRIMARY KEY,
  event_id VARCHAR(255) UNIQUE,                 -- Stripe event ID (evt_xxx)
  event_type VARCHAR(100) NOT NULL,             -- payment_intent.succeeded, etc.
  payment_intent_id VARCHAR(255),
  event_data JSONB NOT NULL,                    -- Full event payload
  processed BOOLEAN DEFAULT false,
  processing_error TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
ALTER TABLE stripe.webhook_log OWNER TO samizdat;

CREATE INDEX IF NOT EXISTS idx_stripe_webhook_event ON stripe.webhook_log(event_id);
CREATE INDEX IF NOT EXISTS idx_stripe_webhook_type ON stripe.webhook_log(event_type);
CREATE INDEX IF NOT EXISTS idx_stripe_webhook_intent ON stripe.webhook_log(payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_stripe_webhook_created ON stripe.webhook_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stripe_webhook_processed ON stripe.webhook_log(processed);

-- Refunds table
CREATE TABLE IF NOT EXISTS stripe.refunds (
  refundid SERIAL PRIMARY KEY,
  stripe_refund_id VARCHAR(255) UNIQUE,         -- Stripe Refund ID (re_xxx)
  payment_intent_id VARCHAR(255) NOT NULL,      -- Original payment
  amount INTEGER NOT NULL,                      -- Refund amount
  currency VARCHAR(3) NOT NULL DEFAULT 'SEK',
  status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, succeeded, failed, canceled
  reason VARCHAR(100),                          -- duplicate, fraudulent, requested_by_customer
  error_message TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

  CONSTRAINT stripe_refunds_amount_check CHECK (amount > 0)
);
ALTER TABLE stripe.refunds OWNER TO samizdat;

CREATE INDEX IF NOT EXISTS idx_stripe_refunds_id ON stripe.refunds(stripe_refund_id);
CREATE INDEX IF NOT EXISTS idx_stripe_refunds_intent ON stripe.refunds(payment_intent_id);
CREATE INDEX IF NOT EXISTS idx_stripe_refunds_status ON stripe.refunds(status);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION stripe.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS payments_updated_at ON stripe.payments;
CREATE TRIGGER payments_updated_at
  BEFORE UPDATE ON stripe.payments
  FOR EACH ROW
  EXECUTE FUNCTION stripe.update_timestamp();

DROP TRIGGER IF EXISTS refunds_updated_at ON stripe.refunds;
CREATE TRIGGER refunds_updated_at
  BEFORE UPDATE ON stripe.refunds
  FOR EACH ROW
  EXECUTE FUNCTION stripe.update_timestamp();

-- Comments
COMMENT ON SCHEMA stripe IS 'Stripe payment integration';
COMMENT ON TABLE stripe.payments IS 'Stripe payment intent records';
COMMENT ON COLUMN stripe.payments.customerid IS 'Reference to customer.customers';
COMMENT ON COLUMN stripe.payments.payment_intent_id IS 'Stripe PaymentIntent ID';
COMMENT ON COLUMN stripe.payments.amount IS 'Amount in smallest currency unit (cents/öre)';
COMMENT ON COLUMN stripe.payments.status IS 'Payment status: created, pending, succeeded, failed, canceled';
COMMENT ON TABLE stripe.webhook_log IS 'Audit log of webhook events from Stripe';
COMMENT ON TABLE stripe.refunds IS 'Refund operations for Stripe payments';
