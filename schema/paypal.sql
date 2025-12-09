-- PayPal Payment Integration Schema
-- REST API v2 with OAuth 2.0 authentication
-- Documentation: https://developer.paypal.com/api/rest/

-- Create PayPal schema
CREATE SCHEMA IF NOT EXISTS paypal;
ALTER SCHEMA paypal OWNER TO samizdat;

-- IPN/Transaction log table for tracking PayPal payments
CREATE TABLE IF NOT EXISTS paypal.ipn_log (
  id SERIAL PRIMARY KEY,
  customerid BIGINT,                            -- Link to customer.customers
  txn_id VARCHAR(255) UNIQUE,                   -- PayPal transaction ID
  txn_type VARCHAR(100),                        -- Transaction type (web_accept, cart, etc.)
  payment_status VARCHAR(50),                   -- Payment status (Completed, Pending, Refunded, etc.)
  payer_email VARCHAR(255),                     -- Payer's email address
  receiver_email VARCHAR(255),                  -- Merchant's email address
  amount DECIMAL(10,2),                         -- Payment amount
  currency VARCHAR(10),                         -- ISO 4217 currency code
  item_number VARCHAR(255),                     -- Item/product identifier
  custom TEXT,                                  -- Custom merchant data
  raw_data JSONB,                               -- Full IPN/API response payload
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
ALTER TABLE paypal.ipn_log OWNER TO samizdat;

-- Indexes for quick lookups
CREATE INDEX IF NOT EXISTS idx_paypal_txn_id ON paypal.ipn_log(txn_id);
CREATE INDEX IF NOT EXISTS idx_paypal_status ON paypal.ipn_log(payment_status);
CREATE INDEX IF NOT EXISTS idx_paypal_created ON paypal.ipn_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_paypal_payer ON paypal.ipn_log(payer_email);
CREATE INDEX IF NOT EXISTS idx_paypal_customer ON paypal.ipn_log(customerid);

-- Foreign key to customer
ALTER TABLE paypal.ipn_log
  ADD CONSTRAINT customers_fk FOREIGN KEY (customerid)
    REFERENCES customer.customers (customerid) MATCH SIMPLE
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Comments for documentation
COMMENT ON SCHEMA paypal IS 'PayPal payment integration';
COMMENT ON TABLE paypal.ipn_log IS 'PayPal payment transaction log (IPN and REST API)';
COMMENT ON COLUMN paypal.ipn_log.customerid IS 'Reference to customer.customers';
COMMENT ON COLUMN paypal.ipn_log.txn_id IS 'PayPal transaction ID or capture ID';
COMMENT ON COLUMN paypal.ipn_log.txn_type IS 'Transaction type: web_accept, cart, express_checkout, etc.';
COMMENT ON COLUMN paypal.ipn_log.payment_status IS 'Status: Completed, Pending, Refunded, Failed, Denied';
COMMENT ON COLUMN paypal.ipn_log.raw_data IS 'Full API response or IPN payload as JSON';
