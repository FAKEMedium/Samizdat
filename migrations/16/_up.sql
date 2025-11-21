--
-- PostgreSQL database dump
--

\restrict EmgghU1pVIPJ2LqtLI097vFpwR96eg0g2qcSXxNUQIOsxksgtBqxEaCfUktbjjt

-- Dumped from database version 18.0
-- Dumped by pg_dump version 18.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: powerdns; Type: SCHEMA; Schema: -; Owner: powerdns
--

CREATE SCHEMA powerdns;


ALTER SCHEMA powerdns OWNER TO powerdns;

--
-- Name: SCHEMA powerdns; Type: COMMENT; Schema: -; Owner: powerdns
--

COMMENT ON SCHEMA powerdns IS 'standard powerdns schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: comments; Type: TABLE; Schema: powerdns; Owner: powerdns
--

CREATE TABLE powerdns.comments (
                               id integer NOT NULL,
                               domain_id integer NOT NULL,
                               name character varying(255) NOT NULL,
                               type character varying(10) NOT NULL,
                               modified_at integer NOT NULL,
                               account character varying(40) DEFAULT NULL::character varying,
                               comment character varying(65535) NOT NULL,
                               CONSTRAINT c_lowercase_name CHECK (((name)::text = lower((name)::text)))
);


ALTER TABLE powerdns.comments OWNER TO powerdns;

--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: powerdns; Owner: powerdns
--

CREATE SEQUENCE powerdns.comments_id_seq
  AS integer
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;


ALTER SEQUENCE powerdns.comments_id_seq OWNER TO powerdns;

--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: powerdns; Owner: powerdns
--

ALTER SEQUENCE powerdns.comments_id_seq OWNED BY powerdns.comments.id;


--
-- Name: cryptokeys; Type: TABLE; Schema: powerdns; Owner: powerdns
--

CREATE TABLE powerdns.cryptokeys (
                                 id integer NOT NULL,
                                 domain_id integer,
                                 flags integer NOT NULL,
                                 active boolean,
                                 published boolean DEFAULT true,
                                 content text
);


ALTER TABLE powerdns.cryptokeys OWNER TO powerdns;

--
-- Name: cryptokeys_id_seq; Type: SEQUENCE; Schema: powerdns; Owner: powerdns
--

CREATE SEQUENCE powerdns.cryptokeys_id_seq
  AS integer
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;


ALTER SEQUENCE powerdns.cryptokeys_id_seq OWNER TO powerdns;

--
-- Name: cryptokeys_id_seq; Type: SEQUENCE OWNED BY; Schema: powerdns; Owner: powerdns
--

ALTER SEQUENCE powerdns.cryptokeys_id_seq OWNED BY powerdns.cryptokeys.id;


--
-- Name: domainmetadata; Type: TABLE; Schema: powerdns; Owner: powerdns
--

CREATE TABLE powerdns.domainmetadata (
                                     id integer NOT NULL,
                                     domain_id integer,
                                     kind character varying(32),
                                     content text
);


ALTER TABLE powerdns.domainmetadata OWNER TO powerdns;

--
-- Name: domainmetadata_id_seq; Type: SEQUENCE; Schema: powerdns; Owner: powerdns
--

CREATE SEQUENCE powerdns.domainmetadata_id_seq
  AS integer
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;


ALTER SEQUENCE powerdns.domainmetadata_id_seq OWNER TO powerdns;

--
-- Name: domainmetadata_id_seq; Type: SEQUENCE OWNED BY; Schema: powerdns; Owner: powerdns
--

ALTER SEQUENCE powerdns.domainmetadata_id_seq OWNED BY powerdns.domainmetadata.id;


--
-- Name: domains; Type: TABLE; Schema: powerdns; Owner: powerdns
--

CREATE TABLE powerdns.domains (
                              id integer NOT NULL,
                              name character varying(255) NOT NULL,
                              master character varying(128) DEFAULT NULL::character varying,
                              last_check integer,
                              type text NOT NULL,
                              notified_serial bigint,
                              account character varying(40) DEFAULT NULL::character varying,
                              customerid integer DEFAULT 0,
                              options text,
                              catalog text,
                              CONSTRAINT c_lowercase_name CHECK (((name)::text = lower((name)::text)))
);


ALTER TABLE powerdns.domains OWNER TO powerdns;

--
-- Name: domains_id_seq; Type: SEQUENCE; Schema: powerdns; Owner: powerdns
--

CREATE SEQUENCE powerdns.domains_id_seq
  AS integer
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;


ALTER SEQUENCE powerdns.domains_id_seq OWNER TO powerdns;

--
-- Name: domains_id_seq; Type: SEQUENCE OWNED BY; Schema: powerdns; Owner: powerdns
--

ALTER SEQUENCE powerdns.domains_id_seq OWNED BY powerdns.domains.id;


--
-- Name: records; Type: TABLE; Schema: powerdns; Owner: powerdns
--

CREATE TABLE powerdns.records (
                              id bigint NOT NULL,
                              domain_id integer,
                              name character varying(255) DEFAULT NULL::character varying,
                              type character varying(10) DEFAULT NULL::character varying,
                              content character varying(65535) DEFAULT NULL::character varying,
                              ttl integer,
                              prio integer,
                              disabled boolean DEFAULT false,
                              ordername character varying(255),
                              auth boolean DEFAULT true,
                              CONSTRAINT c_lowercase_name CHECK (((name)::text = lower((name)::text)))
);


ALTER TABLE powerdns.records OWNER TO powerdns;

--
-- Name: records_id_seq; Type: SEQUENCE; Schema: powerdns; Owner: powerdns
--

CREATE SEQUENCE powerdns.records_id_seq
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;


ALTER SEQUENCE powerdns.records_id_seq OWNER TO powerdns;

--
-- Name: records_id_seq; Type: SEQUENCE OWNED BY; Schema: powerdns; Owner: powerdns
--

ALTER SEQUENCE powerdns.records_id_seq OWNED BY powerdns.records.id;


--
-- Name: supermasters; Type: TABLE; Schema: powerdns; Owner: powerdns
--

CREATE TABLE powerdns.supermasters (
                                   ip inet NOT NULL,
                                   nameserver character varying(255) NOT NULL,
                                   account character varying(40) NOT NULL
);


ALTER TABLE powerdns.supermasters OWNER TO powerdns;

--
-- Name: tsigkeys; Type: TABLE; Schema: powerdns; Owner: powerdns
--

CREATE TABLE powerdns.tsigkeys (
                               id integer NOT NULL,
                               name character varying(255),
                               algorithm character varying(50),
                               secret character varying(255),
                               CONSTRAINT c_lowercase_name CHECK (((name)::text = lower((name)::text)))
);


ALTER TABLE powerdns.tsigkeys OWNER TO powerdns;

--
-- Name: tsigkeys_id_seq; Type: SEQUENCE; Schema: powerdns; Owner: powerdns
--

CREATE SEQUENCE powerdns.tsigkeys_id_seq
  AS integer
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;


ALTER SEQUENCE powerdns.tsigkeys_id_seq OWNER TO powerdns;

--
-- Name: tsigkeys_id_seq; Type: SEQUENCE OWNED BY; Schema: powerdns; Owner: powerdns
--

ALTER SEQUENCE powerdns.tsigkeys_id_seq OWNED BY powerdns.tsigkeys.id;


--
-- Name: comments id; Type: DEFAULT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.comments ALTER COLUMN id SET DEFAULT nextval('powerdns.comments_id_seq'::regclass);


--
-- Name: cryptokeys id; Type: DEFAULT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.cryptokeys ALTER COLUMN id SET DEFAULT nextval('powerdns.cryptokeys_id_seq'::regclass);


--
-- Name: domainmetadata id; Type: DEFAULT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.domainmetadata ALTER COLUMN id SET DEFAULT nextval('powerdns.domainmetadata_id_seq'::regclass);


--
-- Name: domains id; Type: DEFAULT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.domains ALTER COLUMN id SET DEFAULT nextval('powerdns.domains_id_seq'::regclass);


--
-- Name: records id; Type: DEFAULT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.records ALTER COLUMN id SET DEFAULT nextval('powerdns.records_id_seq'::regclass);


--
-- Name: tsigkeys id; Type: DEFAULT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.tsigkeys ALTER COLUMN id SET DEFAULT nextval('powerdns.tsigkeys_id_seq'::regclass);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.comments
  ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: cryptokeys cryptokeys_pkey; Type: CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.cryptokeys
  ADD CONSTRAINT cryptokeys_pkey PRIMARY KEY (id);


--
-- Name: domainmetadata domainmetadata_pkey; Type: CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.domainmetadata
  ADD CONSTRAINT domainmetadata_pkey PRIMARY KEY (id);


--
-- Name: domains domains_pkey; Type: CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.domains
  ADD CONSTRAINT domains_pkey PRIMARY KEY (id);


--
-- Name: records records_pkey; Type: CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.records
  ADD CONSTRAINT records_pkey PRIMARY KEY (id);


--
-- Name: supermasters supermasters_pkey; Type: CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.supermasters
  ADD CONSTRAINT supermasters_pkey PRIMARY KEY (ip, nameserver);


--
-- Name: tsigkeys tsigkeys_pkey; Type: CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.tsigkeys
  ADD CONSTRAINT tsigkeys_pkey PRIMARY KEY (id);


--
-- Name: catalog_idx; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE INDEX catalog_idx ON powerdns.domains USING btree (catalog);


--
-- Name: comments_domain_id_idx; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE INDEX comments_domain_id_idx ON powerdns.comments USING btree (domain_id);


--
-- Name: comments_name_type_idx; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE INDEX comments_name_type_idx ON powerdns.comments USING btree (name, type);


--
-- Name: comments_order_idx; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE INDEX comments_order_idx ON powerdns.comments USING btree (domain_id, modified_at);


--
-- Name: domain_id; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE INDEX domain_id ON powerdns.records USING btree (domain_id);


--
-- Name: domainidindex; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE INDEX domainidindex ON powerdns.cryptokeys USING btree (domain_id);


--
-- Name: domainidmetaindex; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE INDEX domainidmetaindex ON powerdns.domainmetadata USING btree (domain_id);


--
-- Name: name_index; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE UNIQUE INDEX name_index ON powerdns.domains USING btree (name);


--
-- Name: namealgoindex; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE UNIQUE INDEX namealgoindex ON powerdns.tsigkeys USING btree (name, algorithm);


--
-- Name: nametype_index; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE INDEX nametype_index ON powerdns.records USING btree (name, type);


--
-- Name: rec_name_index; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE INDEX rec_name_index ON powerdns.records USING btree (name);


--
-- Name: recordorder; Type: INDEX; Schema: powerdns; Owner: powerdns
--

CREATE INDEX recordorder ON powerdns.records USING btree (domain_id, ordername text_pattern_ops);


--
-- Name: cryptokeys cryptokeys_domain_id_fkey; Type: FK CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.cryptokeys
  ADD CONSTRAINT cryptokeys_domain_id_fkey FOREIGN KEY (domain_id) REFERENCES powerdns.domains(id) ON DELETE CASCADE;


--
-- Name: records domain_exists; Type: FK CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.records
  ADD CONSTRAINT domain_exists FOREIGN KEY (domain_id) REFERENCES powerdns.domains(id) ON DELETE CASCADE;


--
-- Name: comments domain_exists; Type: FK CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.comments
  ADD CONSTRAINT domain_exists FOREIGN KEY (domain_id) REFERENCES powerdns.domains(id) ON DELETE CASCADE;


--
-- Name: domainmetadata domainmetadata_domain_id_fkey; Type: FK CONSTRAINT; Schema: powerdns; Owner: powerdns
--

ALTER TABLE ONLY powerdns.domainmetadata
  ADD CONSTRAINT domainmetadata_domain_id_fkey FOREIGN KEY (domain_id) REFERENCES powerdns.domains(id) ON DELETE CASCADE;


--
-- Name: SCHEMA powerdns; Type: ACL; Schema: -; Owner: powerdns
--

REVOKE USAGE ON SCHEMA powerdns FROM powerdns;
GRANT ALL ON SCHEMA powerdns TO powerdns;

-- Grant samizdat user permission to update account and customerid columns
GRANT USAGE ON SCHEMA powerdns TO samizdat;
GRANT SELECT, UPDATE (account, customerid) ON powerdns.domains TO samizdat;


--
-- PostgreSQL database dump complete
--

\unrestrict EmgghU1pVIPJ2LqtLI097vFpwR96eg0g2qcSXxNUQIOsxksgtBqxEaCfUktbjjt
