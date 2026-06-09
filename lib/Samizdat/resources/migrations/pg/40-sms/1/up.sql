--
-- PostgreSQL database dump
--


-- Dumped from database version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)


--
-- Name: sms; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS sms;




--
-- Name: messages; Type: TABLE; Schema: sms; Owner: -
--

CREATE TABLE sms.messages (
    id integer NOT NULL,
    direction character varying(10) NOT NULL,
    phone character varying(20) NOT NULL,
    message text NOT NULL,
    tx_id character varying(50),
    msg_id character varying(50),
    status character varying(20) DEFAULT 'pending'::character varying,
    sent_at timestamp with time zone,
    received_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: sms; Owner: -
--

CREATE SEQUENCE sms.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: sms; Owner: -
--

ALTER SEQUENCE sms.messages_id_seq OWNED BY sms.messages.id;


--
-- Name: messages id; Type: DEFAULT; Schema: sms; Owner: -
--

ALTER TABLE ONLY sms.messages ALTER COLUMN id SET DEFAULT nextval('sms.messages_id_seq'::regclass);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: sms; Owner: -
--

ALTER TABLE ONLY sms.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: idx_sms_messages_created_at; Type: INDEX; Schema: sms; Owner: -
--

CREATE INDEX idx_sms_messages_created_at ON sms.messages USING btree (created_at DESC);


--
-- Name: idx_sms_messages_direction; Type: INDEX; Schema: sms; Owner: -
--

CREATE INDEX idx_sms_messages_direction ON sms.messages USING btree (direction);


--
-- Name: idx_sms_messages_phone; Type: INDEX; Schema: sms; Owner: -
--

CREATE INDEX idx_sms_messages_phone ON sms.messages USING btree (phone);


--
-- Name: idx_sms_messages_phone_created; Type: INDEX; Schema: sms; Owner: -
--

CREATE INDEX idx_sms_messages_phone_created ON sms.messages USING btree (phone, created_at DESC);


--
-- Name: idx_sms_messages_status; Type: INDEX; Schema: sms; Owner: -
--

CREATE INDEX idx_sms_messages_status ON sms.messages USING btree (status);


--
-- PostgreSQL database dump complete
--
