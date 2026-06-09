# Samizdat Packaging & Multi-Repo Migration

**Status:** Phases A1–A3, B, D-spike done · core stacked into `main` · D productionize (delete-from-core, remote, CI) + Phase E next · **Owner:** Hans · **Started:** 2026-06-03

This is the durable plan for splitting the Samizdat monorepo into installable CPAN/pkg
distributions across multiple git repos, and for the layered multi-customer/multi-site
configuration model that the split enables. It captures decisions already made so the
arc survives across sessions; execute it slice by slice (plan-mode per code chunk).

---

## 1. Goals & non-goals

**Goals**
- Each module is an installable distribution (`cpanm`/FreeBSD `pkg`), landing in the
  `site_perl` tree exactly like `p5-Mojolicious` / `p5-Mojolicious-Plugin-Mail`.
- Per-repo `CLAUDE.md` and clean, uncluttered per-package trees.
- A deployment installs **only** the modules it needs; private/sensitive code stays private.
- One config model spanning two ends of a control continuum: full-control self-host
  (Rymdweb now) and, later, multi-customer/multi-site SaaS — same engine, additive.
- Production installs are **offline and reproducible**: no network, no node, no
  `make fetchall` at install/runtime.

**Non-goals (now)**
- Phase 2 SaaS features (DB-backed customer/site config, delegation UI, entitlement).
- Rewriting working features. The split is mechanical once the seams exist.

---

## 2. Decisions locked

### 2.1 Repo / dist topology (full polyrepo for public modules)

| Repo | Dist | Audience | Visibility |
|---|---|---|---|
| `samizdat` (core) | `Samizdat` | core | public |
| `samizdat-resources` | `Samizdat-Resources` (vendored 3rd-party assets) | core | public |
| `samizdat-fortnox` | `Samizdat-Plugin-Fortnox` | operator | public |
| `samizdat-invoice` | `Samizdat-Plugin-Invoice` | operator | public |
| `samizdat-<offerable>` … | `Samizdat-Plugin-*` | offerable | public |
| `samizdat-epp` | `Samizdat-Plugin-EPP` (+ `EPP-PRIVATE.md`) | operator | **private** |
| `samizdat-site` | — (deploy: `samizdat.yml`, certs, plugin list, content) | — | **private** |

**Audience** = runtime exposure (`core`/`operator`/`offerable`), declared in the module
manifest. **Visibility** = who can clone; a *hosting* decision, never in code. They are
independent: Fortnox/Invoice are operator-audience **and** public-source; EPP is private
for IP/security reasons.

### 2.2 Namespace ownership (the rule that prevents pkg conflicts)
- Core owns `Samizdat.pm` (namespace root + app class) and the core modules.
- Each feature dist owns only its `*::<Module>` leaves across `Plugin`/`Controller`/
  `Model`/`Command`.
- Shared base classes/helpers live in **exactly one** dist (core); feature dists depend
  on core for them and never redefine a `Samizdat::*` package core ships.
- **Extract = move-out AND delete-from-core, always paired** (two dists shipping the same
  file path = `pkg` conflict).
- Directories are shared across packages; files are owned by exactly one. `pkg which <file>`
  is the source of truth.

### 2.3 Install layout (FreeBSD `hier(7)`)

| Category | Path | Owner |
|---|---|---|
| Code (`lib/`) | `…/site_perl/Samizdat/{Plugin,Controller,Model,Command}/*.pm` | dist (immutable) |
| Bundled read-only assets | `…/site_perl/Samizdat/resources/{templates,public,migrations,settings,locale}/<module>/` | dist (immutable) |
| Built frontend bundle | `…/site_perl/Samizdat/resources/public/assets/` | core dist |
| `bin/samizdat` | `/usr/local/bin/samizdat` | core dist |
| Config + secrets | `/usr/local/etc/samizdat/` (+ per-site overrides) | `samizdat-site` |
| Served per-site content + generated static cache (HTML, WebP) | `/usr/local/www/samizdat/<site>/public/` | runtime |
| Mutable data (Minion, logs, scratch) | `/var/db/samizdat/`, `/var/log/samizdat/` | runtime |

### 2.4 Shared `resources/` tree (single root, registered once)
- All dists install assets into the shared `Samizdat/resources/<kind>/<module>/` tree
  (Mojolicious-native pattern, **not** File::ShareDir `auto/share/dist`).
- Core resolves its own location (`$INC{'Samizdat.pm'}`) → `Samizdat/resources` and
  registers the template/static/locale roots **once**. Plugins push **no paths** — their
  views light up because the files exist under a root core already scans (zero core↔plugin
  coupling).
- **Migrations & settings are enumerated off the loaded-plugin list**, not "whatever files
  exist" (so a disabled plugin never migrates a DB). Files live in the shared tree;
  activation is explicit per loaded plugin (`migrations->name('<module>')->from_dir(
  resources/migrations/<module>)`, load `resources/settings/<module>/schema.yml`).
- **Override path in front:** keep `extratemplates` + a per-site override dir under
  `/usr/local/etc/samizdat/<site>/templates` pushed ahead of the shared root for
  per-site customization (composes with the multi-site direction).
- Ownership: `templates/{layouts,chunks}` are core-owned; plugins write only under their
  own `<kind>/<module>/` subtree.
- **Locale is per-module.** Each dist owns `resources/locale/<module>/<lang>/<module>.po`
  (`make i18n` extracts per module, seeding from the legacy merged `.po` on first run). LTOO's
  loader *overwrites* rather than merges multiple `.mo`, so a build step `msgcat`s all module
  `.po` into one runtime catalog per language (`resources/locale/<lang>.mo`), loaded flat under
  the empty domain so `__('msg')` resolves in code and templates. For multi-dist installs the
  merge moves to deploy time (after the installed plugin set is known).

### 2.5 Frontend
- Per-page JS stays **template-inline** (rendered via `render_to_string`, ships in
  `resources/templates/<module>/…/index.js`), using the base bundle's `window.*` globals
  (`authenticatedFetch`, `handle401Error`, `showToast`). Sharing is **runtime globals**,
  not build-time imports → plugins need **no webpack**.
- The webpack **bundle is core's**: `src/{js,scss}` are build inputs in the core repo,
  **excluded from the install** (`MANIFEST.SKIP`); the **built artifact** ships at
  `resources/public/assets/`. Build runs at package-build/CI time → production needs no node.
- A heavyweight plugin that genuinely needs bundling builds its **own** artifact at its own
  package-build time and ships it in its own `resources/public/assets/` (page loads core
  bundle + that plugin's bundle). No central frontend repo until a plugin needs build-time
  shared imports (then publish `@samizdat/frontend` as an npm package).

### 2.6 Third-party reference assets (`make fetchall`/`make icons`)
- **Vendored (redistributed) at build time** into `Samizdat-Resources`, not fetched at
  install/runtime. Ship only the **used subset**, optimized.
- Per-source license verified and NOTICE shipped (bootstrap-icons MIT, flag-icons MIT,
  i18n-iso-* MIT, fonts per-license OFL/Apache).
- Core depends on `Samizdat-Resources`; the data refreshes independently of core releases.

### 2.7 Configuration model (the reason for the split)
- **Read precedence (low→high):** `package → platform → customer → site`. Customer is the
  tenant; sites belong to a customer and inherit; site is the most specific override.
- **Governance / delegation ceiling per key:** `platform | customer` (monotonic tightening —
  each layer may only lower a lower layer's allowance; secrets are platform-only).
- **Ceilings govern actions too, not only config keys:** an `offerable` module declares both its
  customer-writable config keys AND a customer-permitted *action set* (e.g. Certificate: a customer
  may request/renew, not edit issuer config). The `x-samizdat-*` profile carries an action ACL
  alongside per-key scope.
- **Module audience** gates the above: `core`/`operator` collapse to platform-only config;
  `offerable` gets customer/site layers + entitlement + auto-generated UI (Phase 2).
- **Schema = JSON Schema (Draft 2020-12) + an `x-samizdat-*` profile** (`x-samizdat-audience`,
  `x-samizdat-scope`, `writeOnly` for secrets). Validation/defaults via the already-present
  `JSON::Validator`. Each module ships `resources/settings/<module>/schema.yml`; core
  collects them like it already collects OpenAPI fragments.
- **Phase 1 (Rymdweb):** resolver + schema, package + file (`samizdat.yml`) layers only,
  context is always the operator. **Phase 2 (SaaS):** DB-backed customer/site layers,
  ceiling enforcement, per-site static-cache keying, audit, generated UI — additive.

### 2.8 No per-process tenant state
- Config is resolved **per request with a context**, never captured at startup.
- Tenant state (e.g. OAuth tokens) is **keyed by tenant** (`fortnox:cache:customer:<cid>`,
  not a global `state $model` singleton). Phase 1 has one tenant (operator), but new code
  takes a context and scopes its cache so Phase 2 is additive, not a singleton-unwind.

### 2.9 Foundational entities live in core (Account, Customer)
- `Account` (identity/auth) and `Customer` live in the **core** dist. `Customer` is the
  relationship hub that ties services — invoices, domains, email, payments — by `customerid`,
  so it must be a stable, single-owner entity every feature dist can depend on. Feature dists
  depend on core for them and never redefine them.
- Audience nuance: the **entity is core**; its *management* is operator-facing back-office,
  while the *customer's* self-view is a thin read surface drawn mostly from the Account schema.
  ("core entity + operator admin UI + thin customer self-view" — not a single audience tier.)
- The `Public` country/state/language/flag endpoints are core consumers of the vendored
  reference data (`Samizdat-Resources`), confirming that data is a core-level dependency.

### 2.10 Dist tooling — plain ExtUtils::MakeMaker (Mojolicious-style)
- Hand-written `Makefile.PL` using `ExtUtils::MakeMaker`. **No Dist::Zilla, no Minilla** —
  matches Mojolicious itself (dependency-light, trivial to turn into FreeBSD `p5-*` ports).
- Resources ship under `lib/Samizdat/resources/...` and install to
  `site_perl/Samizdat/resources/...` via EUMM's default scan of `lib/` — the exact mechanism
  Mojolicious uses for its own `resources/` tree. This **dissolves the earlier "non-default
  install" concern**: matching Mojo's tooling makes resources-into-module-tree Just Work.
- The built frontend bundle ships as a **committed resource** (as Mojolicious ships its
  vendored `bootstrap.css`/`highlight.js`), regenerated by `make webpack`; `src/` + `node_modules`
  stay in `MANIFEST.SKIP`; production never builds. (Alternative: a `Makefile.PL` postamble that
  runs `make webpack` at release, only if checked-in bundle churn becomes annoying.)
- Release: `perl Makefile.PL && make && make test && make dist` → tarball → CPAN/darkpan;
  FreeBSD port via `USES=perl5`.

---

## 3. Migration phases

> **Hard principle:** do all self-containment refactoring **while still a monorepo**
> (verifiable, revertible). Split a repo only **after** that module proves self-contained.
> Keep core runnable — Rymdweb working — at every step.

### Phase A — Decouple from cwd (in the current monorepo) · foundation
- **A1** Core path-resolution + resources contract: locate `Samizdat/resources`; register
  template/static/locale roots once; per-site override path in front; helper to find
  config (`/usr/local/etc/samizdat`) and data (`/var`, `www`) dirs.
- **A2** Move `templates/`, `src/public`, `migrations/pg`, locale into
  `resources/<kind>/<module>/`; replace every cwd-relative path
  (`from_dir('migrations/pg')`, `static->paths 'src/public'`, `$app->home`-relative).
- **A3** Webpack outputs to `resources/public/assets`; `src/` + `node_modules` in
  `MANIFEST.SKIP`.
- **Acceptance:** app runs identically from the reorganized checkout; `make` targets green;
  no cwd-relative asset path remains (`grep` clean).

### Phase B — Settings service (core, Phase-1 scope) · ‖ parallel to A, uses A1
- Resolver: package(schema defaults) ← platform(`samizdat.yml`); `resolve('<module>', $ctx)`.
- **Chokepoint (audit §8.2):** every plugin's
  `state $model = Model->new(config => $app->config->{manager}{<m>})` is the single seam.
  Swapping it for a per-context resolve/construct migrates ~25 modules at once and is the
  **same change as Phase C** (it also kills the `state` singleton). Normalize the
  `default_env`/`env.<env>` selection in the resolver. Fill schema gaps: `certificate`, `poll`.
- `x-samizdat-*` profile documented; per-plugin `schema.yml`; validation/defaults via
  `JSON::Validator`; collected like OpenAPI fragments.
- Wire **one** module through it (Fortnox) replacing direct `config->{manager}{module}` reads.
- **Acceptance:** Fortnox config comes from the resolver; invalid config fails validation;
  secrets are `writeOnly` and never logged.

### Phase C — Per-tenant-state hygiene · same chokepoint as B
- **Systemic (audit §8.3):** the `state $model` helper pattern is fleet-wide. Worst cases:
  Fortnox (global `fortnox:cache` + mutable `data`, already half-mitigated), PayPal (OAuth
  token in an in-instance `has access_token` inside a `state $model`), Chat/BuyMeACoffee/SMS
  (global, non-tenant-scoped keys/providers). Copy the good patterns: Account
  `samizdat:$authcookie` and Cache `_getSessionKey` (`:session:<id>`).
- **Acceptance:** no new code captures config at startup or uses a global tenant cache key.

### Phase D — Dist tooling + FIRST extraction = the spike (Fortnox) · the "prove it" milestone
- **D1** Make Fortnox fully self-contained (A+B+C applied; named migrations; `schema.yml`).
- **D2** Build shared tooling **on it**: dzil/Minilla bundle, `MANIFEST.SKIP`, the
  resources-into-module-tree install config, reusable CI, the `.claude` automations plugin,
  the `samizdat-plugin-template`.
- **D3** `git filter-repo` Fortnox → `samizdat-fortnox` (history preserved) **and delete from
  core (paired)**; load via `extraplugins` + `PERL5LIB`.
- **D4** Verify installed-dist path: `cpanm`/`pkg` into a test prefix; app runs from the
  installed tree (not the checkout).
- **Acceptance:** Fortnox runs both from the umbrella checkout and from a clean install;
  `pkg info -l` matches the projected layout; core no longer ships Fortnox files.

**D spike done (2026-06-09, branch `packaging/d-fortnox-dist`)** — the de-risking
question ("can a feature module become an installable dist whose resources reach
`site_perl` where the A1 resolver finds them?") is answered **yes**:
- Extracted `~/IdeaProjects/samizdat-fortnox` with **native `git filter-branch`** (no
  python/`git-filter-repo`) — 60 commits, history for Fortnox's paths preserved.
- Packaged with **plain EUMM** (`Makefile.PL`), not dzil: a `File::Find` PM-hash over
  `lib/` ships the `.ep`/`.yml`/`.mo`/`.svg` resources, which EUMM's default `.pm`-only
  detection would skip. `make test` green (modules load, schema resolves, audience=operator).
- `make install INSTALL_BASE=/tmp/fortnox-prefix` lands exactly the projected layout:
  `…/lib/perl5/Samizdat/{Plugin,Controller,Model,Command}/Fortnox*.pm` **and**
  `…/lib/perl5/Samizdat/resources/{settings,templates,locale}/fortnox/…`. The installed
  module loads from the prefix and its schema sits at the resolver's `$res_inc` path.
- **Productionize follow-ups (deferred, not yet done):** delete-from-core (the paired
  removal — core still ships Fortnox so the checkout keeps running); GitHub remote + CI;
  the `.claude` automations plugin; the `samizdat-plugin-template`; publish/PREREQ-enforce
  core. EUMM chosen over the dzil/Minilla bundle named in D2.

### Phase E — Replicate
- Invoice → offerable modules → `Samizdat-Resources` → EPP (private repo) → stand up
  `samizdat-site`. Mechanical once D's pattern exists.

### Phase F — Phase 2 (later, when SaaS) · out of scope now
- DB config layers, ceiling enforcement, entitlement, customer/site UI, multi-site
  static-cache keying.

---

## 4. Rollout environments (risk ramp)

| Env | Role | Validates |
|---|---|---|
| **localhost / example.com** | dev/integration | A–D; run-from-checkout **and** run-from-installed (cpanm into a local prefix); resources tree; path-resolution |
| **fakenews.com** | first real server (low stakes) | FreeBSD `pkg` install; `/usr/local/etc` config; per-site `www`; offline/no-node install; core packaging |
| **rymdweb.com** | operator production | operator modules (Fortnox/Invoice/EPP); the real deployment; last |

Content sites (example.com, fakenews.com) prove the **packaging/site** machinery before the
operator-only modules and production appear.

---

## 5. Risks & reversibility
- Everything up to **D3** is reversible monorepo reorg. **D3 is the first one-way step**, and
  only for one module — which is why Fortnox is the spike.
- Resources install into the module tree via plain EUMM's default `lib/` scan — the
  Mojolicious mechanism, no special build config needed (see §2.10).
- Cross-cutting changes become N PRs + version bumps → mitigate with versioned core
  interfaces, the dev umbrella (one IntelliJ window, `PERL5LIB`), and CI matrix testing each
  module against released core **and** `core@main`.

---

## 6. Open questions
- ~~Customer model audience~~ — **resolved:** `Customer` is a **core** entity (the hub that
  ties services); operator admin UI + thin customer self-view (§2.9).
- ~~Dist tooling~~ — **resolved:** plain ExtUtils::MakeMaker, Mojolicious-style (§2.10).
- **`Samizdat-Resources`:** separate dist (license isolation, independent refresh) vs fold
  into core if small. Leaning separate.
- **Shared `.claude` automations:** user-level vs a committed Claude plugin installed per repo.

---

## 7. Glossary
- **dist** — a CPAN/pkg distribution (one tarball, one `.packlist`), named for its main module.
- **audience** — runtime exposure tier of a module: `core`/`operator`/`offerable`.
- **visibility** — source-clone access: `public`/`private` (a hosting decision, not in code).
- **ceiling** — the highest config layer permitted to write a given key.
- **operator** — the deployment owner (Rymdweb today; the single tenant in self-host).

---

## 8. Audit surface (parallel agent sweep, 2026-06-07)

### 8.1 Modules, clusters & audience (~30 modules)
**Core** (`Samizdat` dist): Account, Customer, Web, Cache, Public, Icons, Manager,
Captcha, Shortbytes + the app root (`Samizdat.pm`). Customer is the hub everything ties to.

**Offerable — customer self-service hosting suite** (Customer-scoped; customers log in and manage
their own): **Domain, Zone, Website, Email, Database, Certificate, Contact** (Certificate =
*limited* customer actions; **Contact = per-site** contact form, using `account.contacts`) +
registry adapters EPP / RealtimeRegister under Domain. This is the SaaS
surface that gains customer/site config layers + entitlement + UI in Phase 2 — and where
"no per-process tenant state" is mandatory (a customer manages their own domains/email/DBs;
nothing may be shared in a singleton).

**Operator — Rymdweb back-office** (never offered to customers): Fortnox, Invoice, the payment
gateways (Swish, Stripe, PayPal, Nets — billing collection), Mailer (Rymdweb-only for now; may
become offerable later).

**TBD at extraction** (peripheral, non-blocking): Poll, BIS, Chat, SMS, BuyMeACoffee; Example = demo.

EPP = private repo. Dependency edges (inventory audit): payments → `customer.payments`; Domain →
Zone/Certificate/registry; Email/Mailer → Customer; Website → Certificate; Fortnox → Invoice,Cache.
Per-module file manifests captured (Plugin+Controller+Model[+sub]+Command+`templates/<m>/`+
migration#+config section+OpenAPI fragment).

### 8.2 The config-injection chokepoint (key finding)
Every plugin `register()` does
`state $model = Model->new(config => $app->config->{manager}{<m>}, pg/redis => …)`. That one line
**freezes the config slice at startup AND is a process-lifetime `state` singleton** — so the
settings resolver (Phase B) and the no-tenant-state fix (Phase C) are the **same refactor**:
replace frozen-slice + `state` with per-context resolve/construct (or per-tenant-keyed cache).
One pattern change covers ~25 modules. Only `Model/Customer.pm` reads `dbtype` live; the most
scattered *live* read is `manager->{account}` (auth checks in ~9 controllers) → route through the
account/`access` helper. Env-indirection (`default_env`+`env.<env>`) is inconsistent
(zone/email/rtr/paypal/nets/stripe vs swish's `commerce.<env>`) → resolver normalizes "active
env". Schema gaps: `certificate`, `poll` read sections absent from `samizdat.dist.yml`.

### 8.3 Singletons / global tenant state (systemic)
Worst cases: **Fortnox** (`state $model` + global `fortnox:cache`/`fortnox:invoice_list`/
`:invoice_customers` + mutable `data`, half-mitigated via `reload`/`removeCache`); **PayPal**
(OAuth token in `has access_token` inside `state $model` — direct analog); **Chat**
(`chat:conversation:*`), **BuyMeACoffee** (`buymeacoffee:supporters:*`), **SMS** (app-global
OAuth2 provider) — all global, not tenant-scoped. Correct patterns to copy: Account
`samizdat:$authcookie`, Cache `_getSessionKey` (appends `:session:<id>`).

### 8.4 cwd-relative paths to retire (Phase A1/A2)
`Samizdat.pm`: migrations `from_dir('migrations/pg')` (:79), static `src/public` (:19), renderer
`extratemplates` (:18), locale `./locale` (:175). Plugins: `Web.pm`
`Mojo::Home->new('public/'|'templates/')` (:15-16); `Public.pm` `src/countries-data-json/data/`
(:9); `Icons.pm` `src/flag-icons/`,`src/icons/icons/` (:33-34); `Captcha.pm` `src/fonts/`
(:31-45); `Invoice.pm` `src/tmp`,`src/public/`,logos; `Swish.pm` `src/swish/*.png` (:192).
Webpack → `public/assets`. Commands write `public/`, `locale/`, `templates/` symlinks.
**Build on existing convention:** `Captcha.pm` and `Command/makeinstalldata.pm` already fall back
to `/usr/local/share/samizdat/src/...` — A1 generalizes that into the resources contract.

### 8.5 Vendoring set for `Samizdat-Resources` (all permissive)
countries-data-json (~580 JSON, MIT), flag-icons (~542 SVG, MIT), bootstrap-icons (~2078 SVG,
MIT), i18n-iso-languages (32 JSON, MIT), Noto fonts (OFL 1.1; **CJK is 19.5 MB**) + StarJedi
(freeware). Consumers: `Plugin/Public.pm` (countries), `Plugin/Icons.pm` (flags/icons),
`Plugin/Captcha.pm` (fonts). DB tables (countries/states/languages) augment the data. Ship each
upstream LICENSE/NOTICE; consider splitting the 19.5 MB CJK font behind an optional sub-package.

### 8.6 Core surface (namespace-ownership)
No custom base classes (all stock `Mojo::Base`). Core = `Samizdat.pm` (app root, `home`/`manager`
route shortcuts, OpenAPI aggregator, DB/redis/uuid/merger helpers, i18n, defaults, language hook)
+ Account, Customer, Cache, Public, Web, Icons, Manager + `templates/layouts/*` +
`templates/chunks/*`. The `Web` plugin's `after_render` hook (static-cache + CSP + WebP) is the
central rendering pipeline — core, single-registration. Helpers/routes/templates are global
last-write-wins → a feature dist redefining `pg`,`redis`,`account`,`access`,`customer`,`cache`,
`web`,`icon`,`__`, the `home`/`manager` shortcuts, named routes, or `layouts`/`chunks` would
silently shadow core. Customer = hub (`customerid` in 11 models); `Invoice` takes
`customer => $app->customer` injection — the canonical "feature depends on core entity" example.