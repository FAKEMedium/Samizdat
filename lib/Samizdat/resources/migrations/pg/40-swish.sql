-- 1 up
--
-- PostgreSQL database dump
--


-- Dumped from database version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)


--
-- Name: swish; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS swish;


--
-- Name: SCHEMA swish; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA swish IS 'Swish mobile payment integration';


--
-- Name: update_timestamp(); Type: FUNCTION; Schema: swish; Owner: -
--

CREATE FUNCTION swish.update_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;




--
-- Name: callback_log; Type: TABLE; Schema: swish; Owner: -
--

CREATE TABLE swish.callback_log (
    callbackid integer NOT NULL,
    instruction_id uuid,
    event_type character varying(100),
    event_data jsonb NOT NULL,
    source_ip inet,
    processed boolean DEFAULT false,
    processing_error text,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE callback_log; Type: COMMENT; Schema: swish; Owner: -
--

COMMENT ON TABLE swish.callback_log IS 'Audit log of callback events from Swish';


--
-- Name: callback_log_callbackid_seq; Type: SEQUENCE; Schema: swish; Owner: -
--

CREATE SEQUENCE swish.callback_log_callbackid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: callback_log_callbackid_seq; Type: SEQUENCE OWNED BY; Schema: swish; Owner: -
--

ALTER SEQUENCE swish.callback_log_callbackid_seq OWNED BY swish.callback_log.callbackid;


--
-- Name: payments; Type: TABLE; Schema: swish; Owner: -
--

CREATE TABLE swish.payments (
    paymentid integer NOT NULL,
    customerid bigint,
    instruction_id uuid NOT NULL,
    payment_reference character varying(36),
    amount integer NOT NULL,
    currency character varying(3) DEFAULT 'SEK'::character varying NOT NULL,
    message character varying(50),
    status character varying(50) DEFAULT 'CREATED'::character varying NOT NULL,
    payee_alias character varying(20) NOT NULL,
    payee_payment_reference character varying(36),
    payer_alias character varying(20),
    payer_name character varying(255),
    flow_type character varying(20) DEFAULT 'ecommerce'::character varying NOT NULL,
    payment_request_token character varying(255),
    error_code character varying(20),
    error_message text,
    callback_url text,
    callback_data jsonb,
    custom_data jsonb,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    paid_at timestamp without time zone,
    CONSTRAINT swish_payments_amount_check CHECK ((amount > 0))
);


--
-- Name: TABLE payments; Type: COMMENT; Schema: swish; Owner: -
--

COMMENT ON TABLE swish.payments IS 'Swish payment request records';


--
-- Name: COLUMN payments.customerid; Type: COMMENT; Schema: swish; Owner: -
--

COMMENT ON COLUMN swish.payments.customerid IS 'Reference to customer.customers';


--
-- Name: COLUMN payments.instruction_id; Type: COMMENT; Schema: swish; Owner: -
--

COMMENT ON COLUMN swish.payments.instruction_id IS 'Merchant-generated UUID for payment request';


--
-- Name: COLUMN payments.amount; Type: COMMENT; Schema: swish; Owner: -
--

COMMENT ON COLUMN swish.payments.amount IS 'Amount in smallest currency unit (öre for SEK)';


--
-- Name: COLUMN payments.status; Type: COMMENT; Schema: swish; Owner: -
--

COMMENT ON COLUMN swish.payments.status IS 'Payment status: CREATED, PAID, DECLINED, ERROR, CANCELLED';


--
-- Name: COLUMN payments.payee_alias; Type: COMMENT; Schema: swish; Owner: -
--

COMMENT ON COLUMN swish.payments.payee_alias IS 'Merchant Swish number in format 46XXXXXXXXX';


--
-- Name: COLUMN payments.flow_type; Type: COMMENT; Schema: swish; Owner: -
--

COMMENT ON COLUMN swish.payments.flow_type IS 'ecommerce: phone number provided, mcommerce: QR/app link';


--
-- Name: payments_paymentid_seq; Type: SEQUENCE; Schema: swish; Owner: -
--

CREATE SEQUENCE swish.payments_paymentid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_paymentid_seq; Type: SEQUENCE OWNED BY; Schema: swish; Owner: -
--

ALTER SEQUENCE swish.payments_paymentid_seq OWNED BY swish.payments.paymentid;


--
-- Name: refunds; Type: TABLE; Schema: swish; Owner: -
--

CREATE TABLE swish.refunds (
    refundid integer NOT NULL,
    instruction_id uuid NOT NULL,
    original_payment_reference character varying(36) NOT NULL,
    refund_reference character varying(36),
    amount integer NOT NULL,
    currency character varying(3) DEFAULT 'SEK'::character varying NOT NULL,
    message character varying(50),
    status character varying(50) DEFAULT 'CREATED'::character varying NOT NULL,
    payer_alias character varying(20) NOT NULL,
    payer_payment_reference character varying(36),
    error_code character varying(20),
    error_message text,
    callback_url text,
    callback_data jsonb,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    refunded_at timestamp without time zone,
    CONSTRAINT swish_refunds_amount_check CHECK ((amount > 0))
);


--
-- Name: TABLE refunds; Type: COMMENT; Schema: swish; Owner: -
--

COMMENT ON TABLE swish.refunds IS 'Refund operations for Swish payments';


--
-- Name: COLUMN refunds.original_payment_reference; Type: COMMENT; Schema: swish; Owner: -
--

COMMENT ON COLUMN swish.refunds.original_payment_reference IS 'Payment reference of the original payment to refund';


--
-- Name: refunds_refundid_seq; Type: SEQUENCE; Schema: swish; Owner: -
--

CREATE SEQUENCE swish.refunds_refundid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refunds_refundid_seq; Type: SEQUENCE OWNED BY; Schema: swish; Owner: -
--

ALTER SEQUENCE swish.refunds_refundid_seq OWNED BY swish.refunds.refundid;


--
-- Name: callback_log callbackid; Type: DEFAULT; Schema: swish; Owner: -
--

ALTER TABLE ONLY swish.callback_log ALTER COLUMN callbackid SET DEFAULT nextval('swish.callback_log_callbackid_seq'::regclass);


--
-- Name: payments paymentid; Type: DEFAULT; Schema: swish; Owner: -
--

ALTER TABLE ONLY swish.payments ALTER COLUMN paymentid SET DEFAULT nextval('swish.payments_paymentid_seq'::regclass);


--
-- Name: refunds refundid; Type: DEFAULT; Schema: swish; Owner: -
--

ALTER TABLE ONLY swish.refunds ALTER COLUMN refundid SET DEFAULT nextval('swish.refunds_refundid_seq'::regclass);


--
-- Name: callback_log callback_log_pkey; Type: CONSTRAINT; Schema: swish; Owner: -
--

ALTER TABLE ONLY swish.callback_log
    ADD CONSTRAINT callback_log_pkey PRIMARY KEY (callbackid);


--
-- Name: payments payments_instruction_id_key; Type: CONSTRAINT; Schema: swish; Owner: -
--

ALTER TABLE ONLY swish.payments
    ADD CONSTRAINT payments_instruction_id_key UNIQUE (instruction_id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: swish; Owner: -
--

ALTER TABLE ONLY swish.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (paymentid);


--
-- Name: refunds refunds_instruction_id_key; Type: CONSTRAINT; Schema: swish; Owner: -
--

ALTER TABLE ONLY swish.refunds
    ADD CONSTRAINT refunds_instruction_id_key UNIQUE (instruction_id);


--
-- Name: refunds refunds_pkey; Type: CONSTRAINT; Schema: swish; Owner: -
--

ALTER TABLE ONLY swish.refunds
    ADD CONSTRAINT refunds_pkey PRIMARY KEY (refundid);


--
-- Name: idx_swish_callback_created; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_callback_created ON swish.callback_log USING btree (created_at DESC);


--
-- Name: idx_swish_callback_instruction; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_callback_instruction ON swish.callback_log USING btree (instruction_id);


--
-- Name: idx_swish_callback_processed; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_callback_processed ON swish.callback_log USING btree (processed);


--
-- Name: idx_swish_callback_type; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_callback_type ON swish.callback_log USING btree (event_type);


--
-- Name: idx_swish_payments_created; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_payments_created ON swish.payments USING btree (created_at DESC);


--
-- Name: idx_swish_payments_customer; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_payments_customer ON swish.payments USING btree (customerid);


--
-- Name: idx_swish_payments_instruction; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_payments_instruction ON swish.payments USING btree (instruction_id);


--
-- Name: idx_swish_payments_payee_ref; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_payments_payee_ref ON swish.payments USING btree (payee_payment_reference);


--
-- Name: idx_swish_payments_reference; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_payments_reference ON swish.payments USING btree (payment_reference);


--
-- Name: idx_swish_payments_status; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_payments_status ON swish.payments USING btree (status);


--
-- Name: idx_swish_refunds_created; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_refunds_created ON swish.refunds USING btree (created_at DESC);


--
-- Name: idx_swish_refunds_instruction; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_refunds_instruction ON swish.refunds USING btree (instruction_id);


--
-- Name: idx_swish_refunds_original; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_refunds_original ON swish.refunds USING btree (original_payment_reference);


--
-- Name: idx_swish_refunds_status; Type: INDEX; Schema: swish; Owner: -
--

CREATE INDEX idx_swish_refunds_status ON swish.refunds USING btree (status);


--
-- Name: payments payments_updated_at; Type: TRIGGER; Schema: swish; Owner: -
--

CREATE TRIGGER payments_updated_at BEFORE UPDATE ON swish.payments FOR EACH ROW EXECUTE FUNCTION swish.update_timestamp();


--
-- Name: refunds refunds_updated_at; Type: TRIGGER; Schema: swish; Owner: -
--

CREATE TRIGGER refunds_updated_at BEFORE UPDATE ON swish.refunds FOR EACH ROW EXECUTE FUNCTION swish.update_timestamp();


--
-- Name: payments customers_fk; Type: FK CONSTRAINT; Schema: swish; Owner: -
--

ALTER TABLE ONLY swish.payments
    ADD CONSTRAINT customers_fk FOREIGN KEY (customerid) REFERENCES customer.customers(customerid) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

-- 1 down
DROP SCHEMA IF EXISTS swish CASCADE;
