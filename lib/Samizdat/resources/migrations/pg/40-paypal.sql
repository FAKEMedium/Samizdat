-- 1 up
--
-- PostgreSQL database dump
--


-- Dumped from database version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)


--
-- Name: paypal; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS paypal;


--
-- Name: SCHEMA paypal; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA paypal IS 'PayPal payment integration';




--
-- Name: ipn_log; Type: TABLE; Schema: paypal; Owner: -
--

CREATE TABLE paypal.ipn_log (
    id integer NOT NULL,
    customerid bigint,
    txn_id character varying(255),
    txn_type character varying(100),
    payment_status character varying(50),
    payer_email character varying(255),
    receiver_email character varying(255),
    amount numeric(10,2),
    currency character varying(10),
    item_number character varying(255),
    custom text,
    raw_data jsonb,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE ipn_log; Type: COMMENT; Schema: paypal; Owner: -
--

COMMENT ON TABLE paypal.ipn_log IS 'PayPal payment transaction log (IPN and REST API)';


--
-- Name: COLUMN ipn_log.customerid; Type: COMMENT; Schema: paypal; Owner: -
--

COMMENT ON COLUMN paypal.ipn_log.customerid IS 'Reference to customer.customers';


--
-- Name: COLUMN ipn_log.txn_id; Type: COMMENT; Schema: paypal; Owner: -
--

COMMENT ON COLUMN paypal.ipn_log.txn_id IS 'PayPal transaction ID or capture ID';


--
-- Name: COLUMN ipn_log.txn_type; Type: COMMENT; Schema: paypal; Owner: -
--

COMMENT ON COLUMN paypal.ipn_log.txn_type IS 'Transaction type: web_accept, cart, express_checkout, etc.';


--
-- Name: COLUMN ipn_log.payment_status; Type: COMMENT; Schema: paypal; Owner: -
--

COMMENT ON COLUMN paypal.ipn_log.payment_status IS 'Status: Completed, Pending, Refunded, Failed, Denied';


--
-- Name: COLUMN ipn_log.raw_data; Type: COMMENT; Schema: paypal; Owner: -
--

COMMENT ON COLUMN paypal.ipn_log.raw_data IS 'Full API response or IPN payload as JSON';


--
-- Name: ipn_log_id_seq; Type: SEQUENCE; Schema: paypal; Owner: -
--

CREATE SEQUENCE paypal.ipn_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ipn_log_id_seq; Type: SEQUENCE OWNED BY; Schema: paypal; Owner: -
--

ALTER SEQUENCE paypal.ipn_log_id_seq OWNED BY paypal.ipn_log.id;


--
-- Name: ipn_log id; Type: DEFAULT; Schema: paypal; Owner: -
--

ALTER TABLE ONLY paypal.ipn_log ALTER COLUMN id SET DEFAULT nextval('paypal.ipn_log_id_seq'::regclass);


--
-- Name: ipn_log ipn_log_pkey; Type: CONSTRAINT; Schema: paypal; Owner: -
--

ALTER TABLE ONLY paypal.ipn_log
    ADD CONSTRAINT ipn_log_pkey PRIMARY KEY (id);


--
-- Name: ipn_log ipn_log_txn_id_key; Type: CONSTRAINT; Schema: paypal; Owner: -
--

ALTER TABLE ONLY paypal.ipn_log
    ADD CONSTRAINT ipn_log_txn_id_key UNIQUE (txn_id);


--
-- Name: idx_paypal_created; Type: INDEX; Schema: paypal; Owner: -
--

CREATE INDEX idx_paypal_created ON paypal.ipn_log USING btree (created_at DESC);


--
-- Name: idx_paypal_customer; Type: INDEX; Schema: paypal; Owner: -
--

CREATE INDEX idx_paypal_customer ON paypal.ipn_log USING btree (customerid);


--
-- Name: idx_paypal_payer; Type: INDEX; Schema: paypal; Owner: -
--

CREATE INDEX idx_paypal_payer ON paypal.ipn_log USING btree (payer_email);


--
-- Name: idx_paypal_status; Type: INDEX; Schema: paypal; Owner: -
--

CREATE INDEX idx_paypal_status ON paypal.ipn_log USING btree (payment_status);


--
-- Name: idx_paypal_txn_id; Type: INDEX; Schema: paypal; Owner: -
--

CREATE INDEX idx_paypal_txn_id ON paypal.ipn_log USING btree (txn_id);


--
-- Name: ipn_log customers_fk; Type: FK CONSTRAINT; Schema: paypal; Owner: -
--

ALTER TABLE ONLY paypal.ipn_log
    ADD CONSTRAINT customers_fk FOREIGN KEY (customerid) REFERENCES customer.customers(customerid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

-- 1 down
DROP SCHEMA IF EXISTS paypal CASCADE;
