-- Swish Payment Integration Schema
-- Swedish mobile payment service using mTLS certificates
-- Documentation: https://developer.swish.nu/

-- Create Swish schema
CREATE SCHEMA IF NOT EXISTS swish;
ALTER SCHEMA swish OWNER TO samizdat;

-- Payments table for tracking Swish payment requests
CREATE TABLE IF NOT EXISTS swish.payments (
  paymentid SERIAL PRIMARY KEY,
  customerid BIGINT,                                -- Link to customer.customers
  instruction_id UUID UNIQUE NOT NULL,             -- Merchant-generated UUID
  payment_reference VARCHAR(36),                    -- Swish payment reference (from callback)
  amount INTEGER NOT NULL,                          -- Amount in smallest currency unit (öre)
  currency VARCHAR(3) NOT NULL DEFAULT 'SEK',       -- ISO 4217 currency code
  message VARCHAR(50),                              -- Payment message (max 50 chars)
  status VARCHAR(50) NOT NULL DEFAULT 'CREATED',    -- CREATED, PAID, DECLINED, ERROR, CANCELLED

  -- Merchant info
  payee_alias VARCHAR(20) NOT NULL,                 -- Merchant Swish number (46XXXXXXXXX)
  payee_payment_reference VARCHAR(36),              -- Merchant's internal reference

  -- Payer info
  payer_alias VARCHAR(20),                          -- Payer phone number (for e-commerce)
  payer_name VARCHAR(255),                          -- Payer's name (from callback)

  -- Flow type
  flow_type VARCHAR(20) NOT NULL DEFAULT 'ecommerce', -- 'ecommerce' or 'mcommerce'
  payment_request_token VARCHAR(255),               -- Token for m-commerce (QR/app link)

  -- Error info
  error_code VARCHAR(20),                           -- Error code if failed
  error_message TEXT,                               -- Error message if failed

  -- Callback tracking
  callback_url TEXT,
  callback_data JSONB,                              -- Latest callback payload

  -- Metadata
  custom_data JSONB,                                -- Custom merchant data
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  paid_at TIMESTAMP,

  CONSTRAINT swish_payments_amount_check CHECK (amount > 0)
);
ALTER TABLE swish.payments OWNER TO samizdat;

-- Indexes for quick lookups
CREATE INDEX IF NOT EXISTS idx_swish_payments_instruction ON swish.payments(instruction_id);
CREATE INDEX IF NOT EXISTS idx_swish_payments_reference ON swish.payments(payment_reference);
CREATE INDEX IF NOT EXISTS idx_swish_payments_status ON swish.payments(status);
CREATE INDEX IF NOT EXISTS idx_swish_payments_created ON swish.payments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_swish_payments_payee_ref ON swish.payments(payee_payment_reference);
CREATE INDEX IF NOT EXISTS idx_swish_payments_customer ON swish.payments(customerid);

-- Foreign key to customer
ALTER TABLE swish.payments
  ADD CONSTRAINT customers_fk FOREIGN KEY (customerid)
    REFERENCES customer.customers (customerid) MATCH SIMPLE
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Callback log for debugging and audit trail
CREATE TABLE IF NOT EXISTS swish.callback_log (
  callbackid SERIAL PRIMARY KEY,
  instruction_id UUID,                              -- Related payment instruction ID
  event_type VARCHAR(100),                          -- PAID, DECLINED, ERROR, CANCELLED
  event_data JSONB NOT NULL,                        -- Full callback payload
  source_ip INET,                                   -- Request IP address
  processed BOOLEAN DEFAULT false,                  -- Whether callback was processed
  processing_error TEXT,                            -- Error message if processing failed
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
ALTER TABLE swish.callback_log OWNER TO samizdat;

CREATE INDEX IF NOT EXISTS idx_swish_callback_instruction ON swish.callback_log(instruction_id);
CREATE INDEX IF NOT EXISTS idx_swish_callback_type ON swish.callback_log(event_type);
CREATE INDEX IF NOT EXISTS idx_swish_callback_created ON swish.callback_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_swish_callback_processed ON swish.callback_log(processed);

-- Refunds table for tracking refund operations
CREATE TABLE IF NOT EXISTS swish.refunds (
  refundid SERIAL PRIMARY KEY,
  instruction_id UUID UNIQUE NOT NULL,              -- Merchant-generated UUID for refund
  original_payment_reference VARCHAR(36) NOT NULL,  -- Original payment to refund
  refund_reference VARCHAR(36),                     -- Swish refund reference (from callback)
  amount INTEGER NOT NULL,                          -- Refund amount in öre
  currency VARCHAR(3) NOT NULL DEFAULT 'SEK',
  message VARCHAR(50),                              -- Refund message
  status VARCHAR(50) NOT NULL DEFAULT 'CREATED',    -- CREATED, PAID, DECLINED, ERROR

  -- Payer info (merchant is payer in refund)
  payer_alias VARCHAR(20) NOT NULL,                 -- Merchant Swish number
  payer_payment_reference VARCHAR(36),              -- Merchant's internal reference

  -- Error info
  error_code VARCHAR(20),
  error_message TEXT,

  -- Callback tracking
  callback_url TEXT,
  callback_data JSONB,

  -- Metadata
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  refunded_at TIMESTAMP,

  CONSTRAINT swish_refunds_amount_check CHECK (amount > 0)
);
ALTER TABLE swish.refunds OWNER TO samizdat;

CREATE INDEX IF NOT EXISTS idx_swish_refunds_instruction ON swish.refunds(instruction_id);
CREATE INDEX IF NOT EXISTS idx_swish_refunds_original ON swish.refunds(original_payment_reference);
CREATE INDEX IF NOT EXISTS idx_swish_refunds_status ON swish.refunds(status);
CREATE INDEX IF NOT EXISTS idx_swish_refunds_created ON swish.refunds(created_at DESC);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION swish.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at on swish.payments
DROP TRIGGER IF EXISTS payments_updated_at ON swish.payments;
CREATE TRIGGER payments_updated_at
  BEFORE UPDATE ON swish.payments
  FOR EACH ROW
  EXECUTE FUNCTION swish.update_timestamp();

-- Trigger to auto-update updated_at on swish.refunds
DROP TRIGGER IF EXISTS refunds_updated_at ON swish.refunds;
CREATE TRIGGER refunds_updated_at
  BEFORE UPDATE ON swish.refunds
  FOR EACH ROW
  EXECUTE FUNCTION swish.update_timestamp();

-- Comments for documentation
COMMENT ON SCHEMA swish IS 'Swish mobile payment integration';

COMMENT ON TABLE swish.payments IS 'Swish payment request records';
COMMENT ON COLUMN swish.payments.customerid IS 'Reference to customer.customers';
COMMENT ON COLUMN swish.payments.instruction_id IS 'Merchant-generated UUID for payment request';
COMMENT ON COLUMN swish.payments.amount IS 'Amount in smallest currency unit (öre for SEK)';
COMMENT ON COLUMN swish.payments.payee_alias IS 'Merchant Swish number in format 46XXXXXXXXX';
COMMENT ON COLUMN swish.payments.flow_type IS 'ecommerce: phone number provided, mcommerce: QR/app link';
COMMENT ON COLUMN swish.payments.status IS 'Payment status: CREATED, PAID, DECLINED, ERROR, CANCELLED';

COMMENT ON TABLE swish.callback_log IS 'Audit log of callback events from Swish';

COMMENT ON TABLE swish.refunds IS 'Refund operations for Swish payments';
COMMENT ON COLUMN swish.refunds.original_payment_reference IS 'Payment reference of the original payment to refund';
