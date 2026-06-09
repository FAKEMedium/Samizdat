--
-- PostgreSQL database dump
--


-- Dumped from database version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)


--
-- Name: example; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA IF NOT EXISTS example;


--
-- Name: SCHEMA example; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA example IS 'Example plugin schema demonstrating Samizdat plugin structure';




--
-- Name: example; Type: TABLE; Schema: example; Owner: -
--

CREATE TABLE example.example (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    content text,
    status character varying(50) DEFAULT 'draft'::character varying,
    category character varying(100),
    tags text[],
    active boolean DEFAULT false,
    featured boolean DEFAULT false,
    published boolean DEFAULT false,
    creator integer,
    updater integer,
    created timestamp with time zone DEFAULT now(),
    updated timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE example; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON TABLE example.example IS 'Example table demonstrating typical Samizdat plugin structure';


--
-- Name: COLUMN example.id; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.id IS 'Primary key';


--
-- Name: COLUMN example.title; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.title IS 'Example title';


--
-- Name: COLUMN example.description; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.description IS 'Short description or summary';


--
-- Name: COLUMN example.content; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.content IS 'Full content, may contain HTML';


--
-- Name: COLUMN example.status; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.status IS 'Status: draft, active, inactive';


--
-- Name: COLUMN example.category; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.category IS 'Category for grouping';


--
-- Name: COLUMN example.tags; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.tags IS 'Array of tags for filtering';


--
-- Name: COLUMN example.active; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.active IS 'Whether the example is active';


--
-- Name: COLUMN example.featured; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.featured IS 'Whether to feature this example';


--
-- Name: COLUMN example.published; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.published IS 'Whether this is published';


--
-- Name: COLUMN example.creator; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.creator IS 'User ID who created this';


--
-- Name: COLUMN example.updater; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.updater IS 'User ID who last updated this';


--
-- Name: COLUMN example.created; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.created IS 'Creation timestamp';


--
-- Name: COLUMN example.updated; Type: COMMENT; Schema: example; Owner: -
--

COMMENT ON COLUMN example.example.updated IS 'Last update timestamp';


--
-- Name: example_id_seq; Type: SEQUENCE; Schema: example; Owner: -
--

CREATE SEQUENCE example.example_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: example_id_seq; Type: SEQUENCE OWNED BY; Schema: example; Owner: -
--

ALTER SEQUENCE example.example_id_seq OWNED BY example.example.id;


--
-- Name: example id; Type: DEFAULT; Schema: example; Owner: -
--

ALTER TABLE ONLY example.example ALTER COLUMN id SET DEFAULT nextval('example.example_id_seq'::regclass);


--
-- Name: example example_pkey; Type: CONSTRAINT; Schema: example; Owner: -
--

ALTER TABLE ONLY example.example
    ADD CONSTRAINT example_pkey PRIMARY KEY (id);


--
-- Name: idx_example_active; Type: INDEX; Schema: example; Owner: -
--

CREATE INDEX idx_example_active ON example.example USING btree (active);


--
-- Name: idx_example_category; Type: INDEX; Schema: example; Owner: -
--

CREATE INDEX idx_example_category ON example.example USING btree (category);


--
-- Name: idx_example_created; Type: INDEX; Schema: example; Owner: -
--

CREATE INDEX idx_example_created ON example.example USING btree (created DESC);


--
-- Name: idx_example_fulltext; Type: INDEX; Schema: example; Owner: -
--

CREATE INDEX idx_example_fulltext ON example.example USING gin (to_tsvector('english'::regconfig, (((((COALESCE(title, ''::character varying))::text || ' '::text) || COALESCE(description, ''::text)) || ' '::text) || COALESCE(content, ''::text))));


--
-- Name: idx_example_published; Type: INDEX; Schema: example; Owner: -
--

CREATE INDEX idx_example_published ON example.example USING btree (published);


--
-- Name: idx_example_status; Type: INDEX; Schema: example; Owner: -
--

CREATE INDEX idx_example_status ON example.example USING btree (status);


--
-- Name: idx_example_tags; Type: INDEX; Schema: example; Owner: -
--

CREATE INDEX idx_example_tags ON example.example USING gin (tags);


--
-- PostgreSQL database dump complete
--
