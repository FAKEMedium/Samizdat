SET search_path=public,pg_catalog,account,web,poll,article,customer,stats;
-- ddl-end --

ALTER TABLE poll.polls ADD COLUMN IF NOT EXISTS title varchar(255) NOT NULL;
-- ddl-end --
ALTER TABLE poll.polls ADD COLUMN IF NOT EXISTS description text;
-- ddl-end --
ALTER TABLE web.homes ADD COLUMN IF NOT EXISTS users_userid bigint NOT NULL;
-- ddl-end --
ALTER TABLE account.emailconfirmationrequests ADD COLUMN IF NOT EXISTS contacts_contactid bigint NOT NULL;
-- ddl-end --

-- object: stats | type: SCHEMA --
DROP SCHEMA IF EXISTS stats CASCADE;
-- ddl-end --

-- object: public."position" | type: TYPE --
DROP TYPE IF EXISTS public."position" CASCADE;
-- ddl-end --

-- object: stats.counters | type: TABLE --
DROP TABLE IF EXISTS stats.counters CASCADE;
-- ddl-end --

-- object: stats.referrers | type: TABLE --
DROP TABLE IF EXISTS stats.referrers CASCADE;
-- ddl-end --

-- object: stats.visitcaches | type: TABLE --
DROP TABLE IF EXISTS stats.visitcaches CASCADE;
-- ddl-end --

-- object: customer.servicestypes | type: TABLE --
DROP TABLE IF EXISTS customer.servicestypes CASCADE;
-- ddl-end --

-- object: customer.servicetypenames | type: TABLE --
DROP TABLE IF EXISTS customer.servicetypenames CASCADE;
-- ddl-end --

-- object: customer.services | type: TABLE --
DROP TABLE IF EXISTS customer.services CASCADE;
-- ddl-end --
ALTER TABLE customer.services OWNER TO samizdat;
-- ddl-end --

-- object: poll.polltranslations | type: TABLE --
DROP TABLE IF EXISTS poll.polltranslations CASCADE;
-- ddl-end --

-- object: contactid | type: COLUMN --
ALTER TABLE account.emailconfirmationrequests DROP COLUMN IF EXISTS contactid CASCADE;
-- ddl-end --


-- object: userid | type: COLUMN --
ALTER TABLE account.emailconfirmationrequests DROP COLUMN IF EXISTS userid CASCADE;
-- ddl-end --


-- object: userid | type: COLUMN --
ALTER TABLE web.homes DROP COLUMN IF EXISTS userid CASCADE;
-- ddl-end --




-- [ Created foreign keys ] --
-- object: languages_fk | type: CONSTRAINT --
ALTER TABLE customer.servicetypenames DROP CONSTRAINT IF EXISTS languages_fk CASCADE;
-- ddl-end --

-- object: servicetypes_fk | type: CONSTRAINT --
ALTER TABLE customer.servicetypenames DROP CONSTRAINT IF EXISTS servicetypes_fk CASCADE;
-- ddl-end --

-- object: customers_fk | type: CONSTRAINT --
ALTER TABLE customer.services DROP CONSTRAINT IF EXISTS customers_fk CASCADE;
-- ddl-end --

-- object: servicetypes_fk | type: CONSTRAINT --
ALTER TABLE customer.services DROP CONSTRAINT IF EXISTS servicetypes_fk CASCADE;
-- ddl-end --

-- object: webservices_fk | type: CONSTRAINT --
ALTER TABLE customer.services DROP CONSTRAINT IF EXISTS webservices_fk CASCADE;
-- ddl-end --

-- object: languages_fk | type: CONSTRAINT --
ALTER TABLE poll.polltranslations DROP CONSTRAINT IF EXISTS languages_fk CASCADE;
-- ddl-end --

-- object: polls_fk | type: CONSTRAINT --
ALTER TABLE poll.polltranslations DROP CONSTRAINT IF EXISTS polls_fk CASCADE;
-- ddl-end --

-- object: users_fk | type: CONSTRAINT --
ALTER TABLE account.emailconfirmationrequests DROP CONSTRAINT IF EXISTS users_fk CASCADE;
-- ddl-end --

