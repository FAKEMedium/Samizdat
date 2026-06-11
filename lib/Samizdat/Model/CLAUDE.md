# Samizdat models

This directory holds the **core** models that ship with the Samizdat distribution:
**Web**, **Account**, **Cache**, **Public** and **Settings**.

Most domain, hosting, payment and third-party-integration modules have been **split out
into their own installable dists** — one `Plugin` + `Controller` + `Model` trio per repo
(`samizdat-<name>` under the FAKEMedium org), published to CPAN/pkg. Each dist carries its
own documentation, JSON-Schema settings, per-plugin migrations, templates and locale; those
resources are discovered at runtime by the resource resolver in `Samizdat.pm` (every
`Samizdat/resources` tree on `@INC` is unioned). See [Split-out modules](#split-out-modules)
below — the detailed per-module docs that used to live here now live in each dist.

Core wires plugins together loosely: cross-module calls are **helper-guarded**
(`$app->renderer->helpers->{<helper>} ? … : …`), so a module is optional — if its dist is
not installed, the helper is absent and core degrades gracefully rather than failing.

## Web

Routes are primarily linked to Samizdate controllers with definitions in Plugins.
The default wildcard route is defined in the Web plugin.
The Web model first looks for a matching route in the database,
then looks for files in the src public directory where README.md will be
converted to index.html.

Multiple languages are supported. If a route is not found for the requested language,
the model will fall back to the default language if available, and
finally return a 404 if no match is found.

Routes are matched against web.uris table with fields for path and resourceid.
web.webservices and web.domains defines alias domains, primary domain,
and subpath.
Web pages are stored in web.resources table with fields for path, language, title, content, metadata, etc.
The src fields store the file path in the src/public directory if applicable.
web.resourceconnections builds a tree structure for storing resources.

Menus are stored in web.menus and web.menulinks tables.
web.menutitles stores localized titles for menus.
Menu links can point to internal resources or external URLs.

## Account

User accounts, authentication and authorisation. Session state lives in Redis as
`samizdat:<authcookie>` hashes via the `redis` helper (see Cache for the backend and its
fallback). Config **superadmins** under `manager.account.superadmins` authenticate from
config alone — so the app can boot for first-run setup and an operator can log in before a
database exists. PostgreSQL is optional at boot: when `dsn.pg` is unset core skips the `pg`
helper, migrations and Minion, and plugins' `helpers->{pg}` guards become real.

## Cache

Encrypted key/value cache and the session backing store, layered on the `redis` helper. The
Redis/Valkey connection is configured under `manager.cache.redis` (legacy top-level
`dsn.redis` is still honoured). When neither is set, the helper returns an in-process
fallback (`Samizdat::RedisFallback`) implementing the command subset the app uses, so
Samizdat runs without a Redis server — **single-process and non-persistent (dev / first-run
only)**; a multi-worker production deploy still needs real Redis. Cached values are
AES-256-GCM encrypted when a session is present (`manager.cache.encrypt`).

## Public

Reference / lookup data shared across the app: languages (with localized display names),
countries and states. Used by helpers and views for i18n and address/geography pickers.

## Settings

Layered, schema-validated configuration resolver. A module's effective config is its
package defaults (from the JSON Schema it ships in `resources/settings/<module>/schema.yml`)
overlaid with the site's `manager.<module>` block from `samizdat.yml`, validated against the
schema. Models read their resolved config via `$app->settings->resolve('<module>')` (or
`->get('<module>', 'dotted.key')`). Because each dist ships its own schema, a module's
defaults travel with the dist; `samizdat.yml` only carries site secrets and overrides. The
operator-only seam (`$ctx`) is where the planned customer/site layers and per-key delegation
ceilings will hook in.

## Split-out modules

Each module below is its own dist (`samizdat-<name>`), installed independently and resolved
at runtime. Full configuration, schema, migrations and usage docs are in each repo's README /
POD — they are no longer duplicated here.

### Offerable / hosting

| Module | Dist | What it does |
| --- | --- | --- |
| Customer | `samizdat-customer` | Customer records; aggregates a customer's domains, invoices, services |
| Invoice | `samizdat-invoice` | Invoicing and reminders (LaTeX/PDF render, dunning) |
| Domain | `samizdat-domain` | Domain registration; registry adapters with optional EPP + RealtimeRegister backends. Includes the IIS/`api.registry.se` (.se) listing |
| Zone | `samizdat-zone` | Authoritative DNS zones (PowerDNS) |
| Website | `samizdat-website` | Website / web-hosting offerable |
| Database | `samizdat-database` | Database-hosting offerable |
| Email | `samizdat-email` | Mailbox hosting (PostfixAdmin backend) |
| Certificate | `samizdat-certificate` | TLS certificate provisioning |

### Registrar backends

| Module | Dist | What it does |
| --- | --- | --- |
| RealtimeRegister | `samizdat-realtimeregister` | Realtime Register registrar API (API-key auth) — injected client for Domain |
| EPP | `samizdat-epp` (**private**) | EPP protocol (RFC 5730-5734) registry client — injected client for Domain |

### Payments & accounting

| Module | Dist | What it does |
| --- | --- | --- |
| Fortnox | `samizdat-fortnox` | Fortnox accounting/invoicing sync (OAuth2) |
| Stripe | `samizdat-stripe` | Stripe payments (embedded components) |
| PayPal | `samizdat-paypal` | PayPal REST v2 payments (OAuth2 client-credentials) |
| Swish | `samizdat-swish` | Swish mobile payments (mTLS, QR/e-commerce). Bundles the QR-logo resource; test certs are gitignored |
| Nets | `samizdat-nets` | Nets/Nexi Checkout payments |
| BuyMeACoffee | `samizdat-buymeacoffee` | Buy Me a Coffee tips/button |

### Communication & misc

| Module | Dist | What it does |
| --- | --- | --- |
| SMS | `samizdat-sms` | Teltonika (RUTXR1) SMS send/receive + SMS-to-HTTP gateway (CGI or OAuth2 API) |
| Mailer | `samizdat-mailer` | Bulk / transactional mail |
| BIS | `samizdat-bis` | "Based in Sweden" hosting-compliance tracker (DNS/IP/ASN geolocation, scoring) |
| Chat | `samizdat-chat` | Chat |
| Poll | `samizdat-poll` | Polls |
| Example | `samizdat-example` | Reference module showing the trio pattern |

### Non-module dists

| Dist | What it is |
| --- | --- |
| `samizdat-plugin-template` | Skeleton (`Skeleton.pm`) + `new-plugin.sh` to scaffold a new plugin dist |
| `samizdat-resources` | Shared resource bundle (multi-root `sharedir`) |
| `samizdat-ports` | FreeBSD ports overlay (core app port + `p5-Samizdat-Plugin-*`), incl. the `rc` scripts |

See `MIGRATION.md` for the monorepo→polyrepo split, the multi-dist resource resolver, the
per-plugin migration layout (`resources/migrations/pg/<NN>-<schema>/<version>/{up,down}.sql`)
and the layered-config rollout.
