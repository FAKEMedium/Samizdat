# Database migrations

## Per-plugin fresh-snapshot migrations (current convention)

Each PostgreSQL schema has ONE fresh-snapshot migration that creates its current
tables, named `pg/<NN>-<schema>.sql` (a Mojo migration with `-- 1 up` / `-- 1 down`
markers). Every plugin distribution ships its own schema's migration under its
`resources/migrations/pg/` — this core tree holds only the **core** schemas; the
offerable/dist schemas live in their dist repos (e.g. `website` in samizdat-website,
`certificate` in samizdat-certificate, `bis` in samizdat-domain, `postfix` in
samizdat-email, `database` in samizdat-database, `zone` in samizdat-zone).

The `run_migrations` helper in `Samizdat.pm` globs `resources/migrations/{pg,mysql}/
*.sql` across every dist on `@INC`, sorts by basename, and runs each as its own named
set (`samizdat-<schema>`). The `<NN>` prefix encodes cross-schema **dependency tiers**
so a fresh install builds schemas in FK order: `10` public → `20` account/article →
`30` customer → `40` everything that depends only on those → `50` website → `60` web.
Existing databases are **grandfathered** (a snapshot whose first table already exists
is stamped as applied, not re-run). To regenerate a snapshot: `pg_dump --schema-only
--no-owner --no-privileges --schema=<s>`, strip `\restrict`/`SET search_path` lines,
wrap in up/down. There is no cross-schema FK from a core schema into a dist schema
(the old `customer.services → website.websites` FK was dropped — app-enforced now).

A `mysql/` tree is supported by the loader for plugins that need it (none yet).
The numbered-step history below ("added migration N") is historical context only.

## Schema Design

### Schemas

- `public` - Shared reference data (languages, currencies, countries)
- `account` - User accounts, contacts, passwords, authentication
- `customer` - Customer entities, billing, invoices, services
- `database` - Database management (now in samizdat-database)
- `web` - Samizdat app content (resources, menus, templates)
- `website` - Web hosting infrastructure (now in samizdat-website)
- `certificate` - SSL certificate management (now in samizdat-certificate)
- `mailer` - Email system (lists, addresses, mails, deliveries)
- `poll` - Polling/survey system

### Core Entity Relationships

#### Contacts and Users (account schema)

- `account.contacts` - Contact information (email, name, address, phone)
- `account.users` - Login accounts, linked to contacts via `contactid`
  - `passwordid` - FK to account.passwords (added migration 23)
- `account.passwords` - Password hashes (multiple formats for migration)
  - Note: `userid` column removed in migration 23 (relationship is now via users.passwordid)

A user always has exactly one contact. Contacts can exist without users (e.g., billing contacts).
A user references their password via `passwordid` (cleaner schema after migration 23).

#### Customers (customer schema)

- `customer.customers` - Customer entities
  - `contactid` - Primary contact (FK to account.contacts)
  - `orgnoid` - Organization number (FK to customer.orgnos)
  - `entitytypeid` - Type: 1=individual, 2=company

- `customer.orgnos` - Organization/VAT numbers with country
  - `orgnoid` - Primary key
  - `orgno` - Organization number
  - `country` - FK to public.countries
  - `vatno` - VAT registration number (added migration 21)
  - `moss` - Mini One Stop Shop EU VAT scheme (added migration 21)

- `customer.settings` - Customer preferences
  - `customerid` - FK to customer.customers
  - `languageid` - FK to public.languages
  - `currencyid` - FK to public.currencies
  - `period` - Billing period (monthly, quarterly, yearly) (added migration 21)
  - `invoicetype` - Delivery method (email, paper, einvoice) (added migration 21)
  - `vat` - VAT rate, default 0.25 (added migration 21)
  - `trust` - Trust level for payment terms (added migration 21)
  - `active` - Customer account is active (added migration 21)
  - `newsletter` - Newsletter subscription (added migration 21)
  - `reference` - Customer reference for invoices (added migration 21)
  - `freetext` - Notes about customer (added migration 21)
  - `recommendedby` - Name of referring customer (added migration 21)

- `customer.customers` - Customer entities (audit fields added migration 21)
  - `created` - Record creation timestamp
  - `updated` - Last update timestamp
  - `creator` - FK to account.users (who created)
  - `updater` - FK to account.users (who updated)

- `account.contacts` - Contact information (lastcheck added migration 21)
  - `lastcheck` - Last verification of contact details

#### Customer-Contact Relationship via Roles

Contacts are linked to customers through the role system:

```
account.contacts → account.users → customer.entityroleusers → customer.customers
                                          ↓
                                   account.roles
```

- `customer.entityroleusers` - Junction table linking users to customers with roles
  - `roleuserid` - Primary key
  - `userid` - FK to account.users (who has the role)
  - `customerid` - FK to customer.customers (for which customer)
  - `roleid` - FK to account.roles (what role)

#### Roles (account.roles)

Roles define what a user can do for a customer:

| roleid | Role      | Description                              |
|--------|-----------|------------------------------------------|
| 1      | owner     | Full access, primary contact             |
| 2      | billing   | Receives invoices, manages payments      |
| 3      | mail      | Manages email accounts and settings      |
| 4      | web       | Manages websites and hosting             |
| 5      | database  | Manages databases                        |
| 6      | domains   | Manages domain registrations             |
| 7      | accounting| Access to financial reports              |

Role names are translated via `account.rolenames` (rolename, languageid, roleid).

#### Entity Types (customer.entitytypes)

The `entitytypeid` on `customer.customers` indicates the type of customer entity:

| entitytypeid | Type       | Description                                    |
|--------------|------------|------------------------------------------------|
| 1            | individual | Private person (global pattern)                |
| 2            | company    | Business/organization (may differ by country)  |

Note: Individual (1) is the global default pattern. Company types and their
identification may differ between countries (e.g., Swedish orgno analysis).

#### Databases (database schema, added migration 22)

- `database.databasetypes` - Database type lookup
  - `databasetypeid` - Primary key
  - `databasetypename` - Type name (mariadb, postgresql, valkey)

- `database.databases` - Customer database instances
  - `databaseid` - Primary key
  - `customerid` - FK to customer.customers
  - `databasetypeid` - FK to database.databasetypes (default: 1=mariadb)
  - `databasename` - Unique database name
  - `username` - Database user
  - `password` - Database password
  - `db_usage` - Storage usage in bytes
  - `created` - Creation timestamp
  - `creator` - Who created
  - `updated` - Last update timestamp
  - `updater` - Who updated

| databasetypeid | Type       | Description                    |
|----------------|------------|--------------------------------|
| 1              | mariadb    | MariaDB/MySQL database         |
| 2              | postgresql | PostgreSQL database            |
| 3              | valkey     | Valkey (Redis-compatible) store|

#### Web Hosting (website schema, added migration 24)

Moved from `web` schema to separate hosting concerns from app content.
Renamed `webservices` to `websites`, `webserviceid` to `websiteid`.

- `website.websites` - Hosted websites/services
  - `websiteid` - Primary key
  - `customerid` - FK to customer.customers
  - `home` - Home directory path (renamed from `path`)
  - `primarydomain` - FK to website.domains
  - `serverid` - FK to website.servers
  - `passwordid` - FK to account.passwords (FTP/SSH access)
  - `certificateid` - FK to certificate.certificates
  - `shellid` - FK to website.shells
  - `ipsetid` - FK to website.ipsets
  - `redirecturl` - Redirect URL if applicable
  - `active` - Service is active
  - `web_usage` - Storage usage in bytes

- `website.domains` - Domain names
  - `domainid` - Primary key
  - `websiteid` - FK to website.websites
  - `domainname` - Unique domain name
  - `customerid` - FK to customer.customers
  - `incert` - Include in multi-SAN certificate (default true)

- `website.servers` - Physical/virtual servers
  - `serverid` - Primary key
  - `hostname` - Server hostname
  - `jailname` - FreeBSD jail name (if applicable)
  - `servertypeid` - FK to website.servertypes

- `website.servertypes` - Server software types
  - `servertypeid` - Primary key
  - `servertypename` - Type name (nginx, apache2, openresty, mojolicious)

- `website.shells` - User shells for FTP/SSH access
  - `shellid` - Primary key
  - `shell` - Shell path (/bin/ftponly, /bin/bash, etc.)

- `website.ipsets` - IP address groups per server
  - `ipsetid` - Primary key
  - `serverid` - FK to website.servers

- `website.ips` - IP addresses
  - `ipid` - Primary key
  - `ipsetid` - FK to website.ipsets
  - `ip` - IP address (inet type)

- `website.serverextras` - Extra Apache/Nginx configuration
  - `serverextraid` - Primary key
  - `configextra` - Configuration directives
  - `websiteid` - FK to website.websites

- `website.phpconfigs` - PHP configuration per website
  - `phpconfigid` - Primary key
  - `phpconfig` - PHP configuration
  - `websiteid` - FK to website.websites

#### SSL Certificates (certificate schema, added migration 24)

- `certificate.certificates` - SSL/TLS certificates
  - `certificateid` - Primary key
  - `customerid` - FK to customer.customers
  - `value` - Certificate PEM content
  - `fullvalue` - Full chain PEM content
  - `notafter` - Expiration timestamp
  - `keyfile` - Path to private key file
  - `certfile` - Path to certificate file
  - `hash` - Certificate hash for identification
  - `issuerid` - FK to certificate.issuers

- `certificate.issuers` - Certificate authorities
  - `issuerid` - Primary key
  - `issuername` - CA name (Let's Encrypt, DigiCert, etc.)

### Reference Data (public schema)

- `public.languages` - Language codes (en, sv, ru...)
- `public.currencies` - Currency symbols (SEK, EUR, USD...)
- `public.countries` - Country data with alpha2/alpha3 codes

### Migration from MySQL

The `migratemysql` command handles data migration from the legacy MySQL database:

```bash
samizdat migratemysql --list
samizdat migratemysql --table=customer --dry-run
samizdat migratemysql --table=snapusers --dry-run
samizdat migratemysql --table=databases --dry-run
```

Mapping:
- MySQL `customer` → account.contacts + customer.orgnos + customer.settings + customer.customers
- MySQL `snapusers` → account.contacts + account.users + account.passwords
- MySQL `databases` → database.databasetypes + database.databases

Note: Database types (mariadb, postgresql, valkey) are created automatically during migration.
All legacy MySQL databases are assigned type `mariadb` (databasetypeid=1).
