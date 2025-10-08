-- Schema copied from postfixadmin
--
SET search_path = public,pg_catalog,postfix;

CREATE SCHEMA IF NOT EXISTS postfix;
ALTER SCHEMA postfix OWNER TO samizdat;
COMMENT ON SCHEMA postfix IS 'standard postfix schema';

CREATE FUNCTION postfix.merge_quota() RETURNS TRIGGER
  LANGUAGE plpgsql
AS
$$
BEGIN
  IF NEW.messages < 0 OR NEW.messages IS NULL THEN
    -- ugly kludge: we came here from this function, really do try to insert
    IF NEW.messages IS NULL THEN
      NEW.messages = 0;
    ELSE
      NEW.messages = -NEW.messages;
    END IF;
    RETURN NEW;
  END IF;

  LOOP
    UPDATE quota
    SET
      bytes    = NEW.bytes,
      messages = NEW.messages
    WHERE username = NEW.username;
    IF found THEN
      RETURN NULL;
    END IF;

    BEGIN
      IF NEW.messages = 0 THEN
        INSERT INTO quota (bytes, messages, username)
        VALUES (NEW.bytes, NULL, NEW.username);
      ELSE
        INSERT INTO quota (bytes, messages, username)
        VALUES (NEW.bytes, -NEW.messages, NEW.username);
      END IF;
      RETURN NULL;
    EXCEPTION
      WHEN unique_violation THEN
      -- someone just inserted the record, update it
    END;
  END LOOP;
END;
$$;

ALTER FUNCTION postfix.merge_quota() OWNER TO samizdat;

SET default_tablespace = '';
SET default_table_access_method = heap;

CREATE TABLE postfix.admin
(
  username       CHARACTER VARYING(255)                                 NOT NULL,
  password       CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  created        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  modified       TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  active         BOOLEAN                  DEFAULT TRUE                  NOT NULL,
  superadmin     BOOLEAN                  DEFAULT FALSE                 NOT NULL,
  phone          CHARACTER VARYING(30)    DEFAULT ''::CHARACTER VARYING NOT NULL,
  email_other    CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  token          CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  token_validity TIMESTAMP WITH TIME ZONE DEFAULT '2000-01-01 00:00:00+00'::TIMESTAMP WITH TIME ZONE
);
ALTER TABLE postfix.admin
  OWNER TO samizdat;
COMMENT ON TABLE postfix.admin IS 'Postfix Admin - Virtual Admins';

CREATE TABLE postfix.alias
(
  address  CHARACTER VARYING(255)                NOT NULL,
  goto     TEXT                                  NOT NULL,
  domain   CHARACTER VARYING(255)                NOT NULL,
  created  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  modified TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  active   BOOLEAN                  DEFAULT TRUE NOT NULL
);
ALTER TABLE postfix.alias
  OWNER TO samizdat;
COMMENT ON TABLE postfix.alias IS 'Postfix Admin - Virtual Aliases';

CREATE TABLE postfix.alias_domain
(
  alias_domain  CHARACTER VARYING(255)                NOT NULL,
  target_domain CHARACTER VARYING(255)                NOT NULL,
  created       TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  modified      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  active        BOOLEAN                  DEFAULT TRUE NOT NULL
);
ALTER TABLE postfix.alias_domain
  OWNER TO samizdat;
COMMENT ON TABLE postfix.alias_domain IS 'Postfix Admin - Domain Aliases';

CREATE TABLE postfix.config
(
  id    INTEGER               NOT NULL,
  name  CHARACTER VARYING(20) NOT NULL,
  value CHARACTER VARYING(20) NOT NULL
);
ALTER TABLE postfix.config
  OWNER TO samizdat;

CREATE TABLE postfix.domain
(
  domain          CHARACTER VARYING(255)                                 NOT NULL,
  description     CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  aliases         INTEGER                  DEFAULT 0                     NOT NULL,
  mailboxes       INTEGER                  DEFAULT 0                     NOT NULL,
  maxquota        BIGINT                   DEFAULT 0                     NOT NULL,
  quota           BIGINT                   DEFAULT 0                     NOT NULL,
  transport       CHARACTER VARYING(255)   DEFAULT NULL::CHARACTER VARYING,
  backupmx        BOOLEAN                  DEFAULT FALSE                 NOT NULL,
  created         TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  modified        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  active          BOOLEAN                  DEFAULT TRUE                  NOT NULL,
  password_expiry INTEGER                  DEFAULT 0,
  customerid      INTEGER                  DEFAULT 0                     NOT NULL
);
ALTER TABLE postfix.domain
  OWNER TO samizdat;
COMMENT ON TABLE postfix.domain IS 'Postfix Admin - Virtual Domains';

CREATE TABLE postfix.domain_admins
(
  username CHARACTER VARYING(255)                NOT NULL,
  domain   CHARACTER VARYING(255)                NOT NULL,
  created  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  active   BOOLEAN                  DEFAULT TRUE NOT NULL,
  id       INTEGER                               NOT NULL
);
ALTER TABLE postfix.domain_admins
  OWNER TO samizdat;
COMMENT ON TABLE postfix.domain_admins IS 'Postfix Admin - Domain Admins';

CREATE TABLE postfix.fetchmail
(
  id             INTEGER                                                NOT NULL,
  mailbox        CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  src_server     CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  src_auth       CHARACTER VARYING(15)                                  NOT NULL,
  src_user       CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  src_password   CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  src_folder     CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  poll_time      INTEGER                  DEFAULT 10                    NOT NULL,
  fetchall       BOOLEAN                  DEFAULT FALSE                 NOT NULL,
  keep           BOOLEAN                  DEFAULT FALSE                 NOT NULL,
  protocol       CHARACTER VARYING(15)                                  NOT NULL,
  extra_options  TEXT,
  returned_text  TEXT,
  mda            CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  date           TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  usessl         BOOLEAN                  DEFAULT FALSE                 NOT NULL,
  sslcertck      BOOLEAN                  DEFAULT FALSE                 NOT NULL,
  sslcertpath    CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING,
  sslfingerprint CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING,
  domain         CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING,
  active         BOOLEAN                  DEFAULT FALSE                 NOT NULL,
  created        TIMESTAMP WITH TIME ZONE DEFAULT '2000-01-01 00:00:00+00'::TIMESTAMP WITH TIME ZONE,
  modified       TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  src_port       INTEGER                  DEFAULT 0                     NOT NULL,
  CONSTRAINT fetchmail_protocol_check CHECK (( ( protocol )::TEXT = ANY
                                                  ( ARRAY [( 'POP3'::CHARACTER VARYING )::TEXT, ( 'IMAP'::CHARACTER VARYING )::TEXT, ( 'POP2'::CHARACTER VARYING )::TEXT, ( 'ETRN'::CHARACTER VARYING )::TEXT, ( 'AUTO'::CHARACTER VARYING )::TEXT] ) )),
  CONSTRAINT fetchmail_src_auth_check CHECK (( ( src_auth )::TEXT = ANY
                                                  ( ARRAY [( 'password'::CHARACTER VARYING )::TEXT, ( 'kerberos_v5'::CHARACTER VARYING )::TEXT, ( 'kerberos'::CHARACTER VARYING )::TEXT, ( 'kerberos_v4'::CHARACTER VARYING )::TEXT, ( 'gssapi'::CHARACTER VARYING )::TEXT, ( 'cram-md5'::CHARACTER VARYING )::TEXT, ( 'otp'::CHARACTER VARYING )::TEXT, ( 'ntlm'::CHARACTER VARYING )::TEXT, ( 'msn'::CHARACTER VARYING )::TEXT, ( 'ssh'::CHARACTER VARYING )::TEXT, ( 'any'::CHARACTER VARYING )::TEXT] ) ))
);
ALTER TABLE postfix.fetchmail
  OWNER TO samizdat;

CREATE TABLE postfix.log
(
  id          INTEGER                                                NOT NULL,
  "timestamp" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  username    CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  domain      CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  action      CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  data        TEXT                     DEFAULT ''::TEXT              NOT NULL
);
ALTER TABLE postfix.log
  OWNER TO samizdat;
COMMENT ON TABLE postfix.log IS 'Postfix Admin - Log';

CREATE TABLE postfix.mailbox
(
  username        CHARACTER VARYING(255)                                 NOT NULL,
  password        CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  name            CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  maildir         CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  quota           BIGINT                   DEFAULT 0                     NOT NULL,
  created         TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  modified        TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  active          BOOLEAN                  DEFAULT TRUE                  NOT NULL,
  domain          CHARACTER VARYING(255),
  local_part      CHARACTER VARYING(255)                                 NOT NULL,
  phone           CHARACTER VARYING(30)    DEFAULT ''::CHARACTER VARYING NOT NULL,
  email_other     CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  token           CHARACTER VARYING(255)   DEFAULT ''::CHARACTER VARYING NOT NULL,
  token_validity  TIMESTAMP WITH TIME ZONE DEFAULT '2000-01-01 00:00:00+00'::TIMESTAMP WITH TIME ZONE,
  password_expiry TIMESTAMP WITH TIME ZONE DEFAULT '2000-01-01 00:00:00+00'::TIMESTAMP WITH TIME ZONE
);
ALTER TABLE postfix.mailbox
  OWNER TO samizdat;
COMMENT ON TABLE postfix.mailbox IS 'Postfix Admin - Virtual Mailboxes';

CREATE SEQUENCE IF NOT EXISTS postfix.config_id_seq
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  MAXVALUE 2147483647
  CACHE 1;

ALTER SEQUENCE postfix.config_id_seq OWNER TO samizdat;

ALTER TABLE postfix.config
  ALTER COLUMN id SET DEFAULT NEXTVAL('postfix.config_id_seq'::regclass);


CREATE SEQUENCE IF NOT EXISTS postfix.domain_admins_id_seq
  AS INTEGER
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  NO MAXVALUE
  CACHE 1;

ALTER SEQUENCE postfix.domain_admins_id_seq OWNER TO samizdat;

ALTER SEQUENCE postfix.domain_admins_id_seq OWNED BY postfix.domain_admins.id;

CREATE SEQUENCE IF NOT EXISTS postfix.fetchmail_id_seq
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  MAXVALUE 2147483647
  CACHE 1;

ALTER SEQUENCE postfix.fetchmail_id_seq OWNER TO samizdat;

ALTER TABLE postfix.fetchmail
  ALTER COLUMN id SET DEFAULT NEXTVAL('postfix.fetchmail_id_seq'::regclass);

CREATE SEQUENCE IF NOT EXISTS postfix.log_id_seq
  START WITH 1
  INCREMENT BY 1
  NO MINVALUE
  MAXVALUE 2147483647
  CACHE 1;

ALTER SEQUENCE postfix.log_id_seq OWNER TO samizdat;

ALTER TABLE postfix.log
  ALTER COLUMN id SET DEFAULT NEXTVAL('postfix.log_id_seq'::regclass);


CREATE TABLE postfix.quota
(
  username CHARACTER VARYING(100) NOT NULL,
  bytes    BIGINT  DEFAULT 0      NOT NULL,
  messages INTEGER DEFAULT 0      NOT NULL
);
ALTER TABLE postfix.quota
  OWNER TO samizdat;

CREATE TABLE postfix.vacation
(
  email         CHARACTER VARYING(255)                    NOT NULL,
  subject       CHARACTER VARYING(255)                    NOT NULL,
  body          TEXT                     DEFAULT ''::TEXT NOT NULL,
  created       TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  active        BOOLEAN                  DEFAULT TRUE     NOT NULL,
  domain        CHARACTER VARYING(255),
  modified      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  activefrom    TIMESTAMP WITH TIME ZONE DEFAULT '2000-01-01 00:00:00+00'::TIMESTAMP WITH TIME ZONE,
  activeuntil   TIMESTAMP WITH TIME ZONE DEFAULT '2038-01-18 00:00:00+00'::TIMESTAMP WITH TIME ZONE,
  interval_time INTEGER                  DEFAULT 0        NOT NULL
);
ALTER TABLE postfix.vacation
  OWNER TO samizdat;

CREATE TABLE postfix.vacation_notification
(
  on_vacation CHARACTER VARYING(255)                 NOT NULL,
  notified    CHARACTER VARYING(255)                 NOT NULL,
  notified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);
ALTER TABLE postfix.vacation_notification
  OWNER TO samizdat;

ALTER TABLE ONLY postfix.domain_admins
  ALTER COLUMN id SET DEFAULT NEXTVAL('postfix.domain_admins_id_seq'::regclass);

ALTER TABLE ONLY postfix.admin
  ADD CONSTRAINT admin_key PRIMARY KEY (username);

ALTER TABLE ONLY postfix.alias
  ADD CONSTRAINT alias_key PRIMARY KEY (address);

ALTER TABLE ONLY postfix.domain
  ADD CONSTRAINT domain_key PRIMARY KEY (domain);

ALTER TABLE ONLY postfix.mailbox
  ADD CONSTRAINT mailbox_key PRIMARY KEY (username);

ALTER TABLE ONLY postfix.alias_domain
  ADD CONSTRAINT alias_domain_pkey PRIMARY KEY (alias_domain);

ALTER TABLE ONLY postfix.config
  ADD CONSTRAINT config_name_key UNIQUE (name);

ALTER TABLE ONLY postfix.config
  ADD CONSTRAINT config_pkey PRIMARY KEY (id);

ALTER TABLE ONLY postfix.domain_admins
  ADD CONSTRAINT domain_admins_pkey PRIMARY KEY (id);

ALTER TABLE ONLY postfix.domain_admins
  ADD CONSTRAINT domain_admins_username_domain_key UNIQUE (username, domain);

ALTER TABLE ONLY postfix.fetchmail
  ADD CONSTRAINT fetchmail_pkey PRIMARY KEY (id);

ALTER TABLE ONLY postfix.log
  ADD CONSTRAINT log_pkey PRIMARY KEY (id);

ALTER TABLE ONLY postfix.quota
  ADD CONSTRAINT quota2_pkey PRIMARY KEY (username);

ALTER TABLE ONLY postfix.vacation
  ADD CONSTRAINT vacation_pkey PRIMARY KEY (email);

ALTER TABLE ONLY postfix.vacation_notification
  ADD CONSTRAINT vacation_notification_pkey PRIMARY KEY (on_vacation, notified);

CREATE INDEX alias_address_active ON postfix.alias USING btree (address, active) WITH (FILLFACTOR ='90');
CREATE INDEX alias_domain_active ON postfix.alias_domain USING btree (alias_domain, active) WITH (FILLFACTOR ='90');
CREATE INDEX domain_domain_active ON postfix.domain USING btree (domain, active) WITH (FILLFACTOR ='90');
CREATE INDEX idx ON postfix.log USING btree (username, "timestamp");
CREATE INDEX mailbox_username_active ON postfix.mailbox USING btree (username, active) WITH (FILLFACTOR ='90');
CREATE INDEX alias_domain_idx ON postfix.alias USING btree (domain) WITH (FILLFACTOR ='90');
CREATE INDEX mailbox_domain_idx ON postfix.mailbox USING btree (domain) WITH (FILLFACTOR ='90');
CREATE INDEX vacation_email_active ON postfix.vacation USING btree (email, active) WITH (FILLFACTOR ='90');
CREATE TRIGGER mergequota
  BEFORE INSERT
  ON postfix.quota
  FOR EACH ROW
EXECUTE FUNCTION postfix.merge_quota();

ALTER TABLE ONLY postfix.alias_domain
  ADD CONSTRAINT alias_domain_alias_domain_fkey FOREIGN KEY (alias_domain) REFERENCES postfix.domain (domain) ON DELETE CASCADE;

ALTER TABLE ONLY postfix.alias
  ADD CONSTRAINT alias_domain_fkey FOREIGN KEY (domain) REFERENCES postfix.domain (domain);

ALTER TABLE ONLY postfix.alias_domain
  ADD CONSTRAINT alias_domain_target_domain_fkey FOREIGN KEY (target_domain) REFERENCES postfix.domain (domain) ON DELETE CASCADE;

ALTER TABLE ONLY postfix.domain_admins
  ADD CONSTRAINT domain_admins_domain_fkey FOREIGN KEY (domain) REFERENCES postfix.domain (domain);

ALTER TABLE ONLY postfix.mailbox
  ADD CONSTRAINT mailbox_domain_fkey1 FOREIGN KEY (domain) REFERENCES postfix.domain (domain);

ALTER TABLE ONLY postfix.vacation
  ADD CONSTRAINT vacation_domain_fkey1 FOREIGN KEY (domain) REFERENCES postfix.domain (domain);

ALTER TABLE ONLY postfix.vacation_notification
  ADD CONSTRAINT vacation_notification_on_vacation_fkey FOREIGN KEY (on_vacation) REFERENCES postfix.vacation (email) ON DELETE CASCADE;