# Samizdat Packaging & Multi-Repo Migration

**Status:** Phases A1–A3, B, D done · **E in progress** — extracted + retired from core: Fortnox, Invoice (`packaging/e-invoice`, multi-dist resolver), Website/Zone/Certificate (`packaging/e-offerable-leaves`), Database/Email (`packaging/e-database-email`), Domain+RealtimeRegister+EPP (`packaging/e-domain`), per-plugin pg migrations + new loader (`packaging/e-migrations`), payment plugins (`packaging/e-payments`), Resources + fakenews.com-src (`packaging/e-resources`) · **extraction COMPLETE — 16 sibling repos** · **next:** GitHub remotes/CI, `.claude` plugin, `samizdat-plugin-template` (productionize) · **Owner:** Hans · **Started:** 2026-06-03

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

### 2.9 Foundational entities (Account in core; Customer is now a foundational dist)
- **SUPERSEDED (2026-06-10):** `Customer` was extracted to its own dist
  `Samizdat-Plugin-Customer` (`packaging/e-customer`). It's still the relationship hub that ties
  services by `customerid` and is *required* for a working install, but it doesn't need to live
  **in** core to do so — core never used the `customer` helper (it was already an `extraplugins`
  entry), so it extracted cleanly. It is now a **foundational dist**: a single-owner entity every
  feature dist depends on, just shipped separately. `Account` (identity/auth) remains in core.
- `Account` (identity/auth) lives in the **core** dist. Feature dists depend on it and never
  redefine it.
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
- **Productionize follow-ups:** delete-from-core **done in Phase E** (paired with Invoice);
  GitHub remote + CI, the `.claude` automations plugin, the `samizdat-plugin-template`, and
  publish/PREREQ-enforce core remain deferred. EUMM chosen over the dzil/Minilla bundle named in D2.

### Phase E — Replicate
- Invoice → offerable modules → `Samizdat-Resources` → EPP (private repo) → stand up
  `samizdat-site`. Mechanical once D's pattern exists.

**E started (2026-06-09, branch `packaging/e-invoice`)** — Invoice extracted **and** the
deferred D delete-from-core done for **both** operator dists:
- **Multi-dist resolver (core)** — the keystone. The resolver anchored every resource kind
  on a single core `Samizdat/resources` dir; now it **unions all `Samizdat/resources` trees
  on `@INC`** (+ `SAMIZDAT_RESOURCES`, checkout home), core first. `resource($kind,@rel)`
  does a file-existence lookup (a module's schema/template resolves to whichever dist ships
  it); new `resources($kind)` feeds the renderer/static/locale path lists. Makes the
  dev-checkout (siblings on `PERL5LIB`) and a real install (shared `site_perl`) resolve
  uniformly. Backward-compatible (routes byte-identical with everything in core).
- **Invoice → `~/IdeaProjects/samizdat-invoice`** (native `git filter-branch`, 66 commits) —
  EUMM dist like Fortnox; `make test` green; installs the 4 modules + resources to the
  projected `site_perl` layout, **including the invoice-owned `customer/*` views and
  `chunks/invoicetable`** (file-level ownership in shared namespaces works).
- **Decoupling** — core `Customer` guarded its 5 `$app->invoice->…` calls with
  `helpers->{invoice}` (so core boots standalone, empty invoice sections without the dist).
  Invoice **requires** core's `Customer` plugin (load order); **optionally** integrates with
  Fortnox (helper-guarded; `recommends` in META). `makereminders` (invoice-reminder command)
  moved to the Invoice dist too.
- **Delete-from-core (paired)** — Fortnox + Invoice code/resources removed from core; the
  checkout runs both via `extraplugins` (already in `samizdat.yml`) **+ `PERL5LIB` pointing at
  the sibling `lib/` dirs**. Verified: `bin/samizdat routes` byte-identical to baseline; moved
  templates + settings schemas resolve at runtime; `samizdat {fortnox,invoice,makereminders}`
  commands discoverable; core test suite unchanged (same pre-existing env failures). The
  `src/public/samizdat/*fortnox*` markdown stays — it's per-site content, not module code.
- **Dev-run note:** the checkout now needs `PERL5LIB=~/IdeaProjects/samizdat-fortnox/lib:`
  `~/IdeaProjects/samizdat-invoice/lib` for `make debug`/`server`/`routes` (or install the dists).
- **Known gaps (follow-ups):** (1) **i18n rebuild** — core's merged per-language `.mo` still
  has the moved modules' strings baked in; a fresh `make i18n` in core would drop them. The
  dists ship `.po` but nothing yet builds them into the runtime merged `.mo`; per-dist i18n
  build / install-time merge is unsolved. (2) `Command/{invoice,makereminders}.pm` moved as
  working-tree copies **without git history** (weren't in the filter keep-set). (3) The
  Customer-side **hook** that would replace core's `include 'customer/invoices'` (so the dist
  injects its tab instead of core referencing it) is still future work. (4) GitHub remotes +
  CI for the dists; `.claude` plugin; `samizdat-plugin-template` — still deferred.

**E offerable leaves done (2026-06-09, branch `packaging/e-offerable-leaves`, stacked on
`packaging/e-invoice`)** — the three **independent** offerable modules extracted, each to its own
history-preserving EUMM dist: **Website** → `samizdat-website`, **Zone** (helper `pdns`) →
`samizdat-zone`, **Certificate** → `samizdat-certificate`. These were the easy ones: **zero core
coupling** (Website's only core reference — Customer's site list — was already `helpers->{website}`-
guarded; Zone/Certificate had none), no inter-module deps, no cross-namespace templates, no settings
schema, no command — so no decoupling commits were needed. All three are **disabled** in
`samizdat.yml` `extraplugins` by default. Each builds, tests, and installs to the projected
`site_perl` layout; verified loading from the sibling dist with routes + templates resolving via the
`@INC` resolver. Deletion from core (85 files) left `routes` byte-identical to baseline; core suite
unchanged. **Still in core (the entangled hosting chain, a separate increment):** **Database** ←
**Domain** ← **Email** (Email depends on Domain+Database; Domain on Database) — these are the
*enabled* offerable modules and need dependency-aware guard work, not a mechanical extraction. Dev
runs now want all five sibling `lib/` dirs on `PERL5LIB`.

**E hosting modules — Database + Email done (2026-06-09, branch `packaging/e-database-email`)** — the
feared "Database←Domain←Email chain" was a **naming-collision mirage**: core models carry their own
`database` attribute (a Mojo::Pg handle; `$self->database->db`), Email's "domains" are postfix **mail**
domains (not registrar domains), and `Email`'s `$self->domain` is its own controller action. The three
hosting modules are actually **independent** — no inter-module deps; each only needs core's
`pg`/`mysql` + `Cache`. So:
- **Database** → `samizdat-database` (clean leaf; Customer's `databases` read already guarded).
- **Email** → `samizdat-email` — carries its own `Model::Email::Postfix` sub-model (separate
  postfixadmin DB), the `email` command, and its `account/email/*` customer-facing views (file-level
  ownership in the `account/` namespace). Customer's mail-domain read guarded (`helpers->{email}`).
- Both **enabled** in `extraplugins`; verified via live `bin/samizdat routes` (byte-identical to
  baseline), helpers present, Email's plugin+Postfix submodel+templates resolving from the sibling.
- **Domain deferred (needs its own plan):** `Model/Domain/Registry/{EPP,RTR}.pm` registry backends,
  the **EPP-private** boundary, the **RealtimeRegister** relationship, the `syncexpiries` command, and
  `customer/domains` + `bis/` cross-namespace templates. This is the one genuinely-entangled offerable
  module and ties into the EPP-private + RealtimeRegister work — not mechanical.

**E Domain + registry deps done (2026-06-09, branch `packaging/e-domain`)** — the entanglement turned
out to be **clean dependency injection**: Domain's registry adapters
`Model/Domain/Registry/{EPP,RTR}.pm` take an injected `client` (no hard `use`), and `Plugin/Domain.pm`
builds an adapter only when that registry's helper is present (`helpers->{epp}`/`{realtimeregister}`).
So Domain has *optional, guarded* runtime deps. Extracted three modules:
- **Domain** → `samizdat-domain` (offerable): trio + the two registry adapters + `syncexpiries`
  command + `domain/`+`bis/`+`customer/domains/` views. `recommends` RealtimeRegister + EPP. Customer's
  domain reads guarded (`helpers->{domain}`).
- **RealtimeRegister** → `samizdat-realtimeregister` (operator): registrar-API integration, used only
  by Domain via injected client; no core coupling.
- **EPP** → `samizdat-epp` (**PRIVATE**): EPP protocol client + `Model/EPP/*.xml.ep` templates. Was
  **untracked** in core → fresh repo (no history). `t/05-epp.t` stays in core's suite (full-app
  Test::Mojo, skips without EPP config).
- Verified with all 10 siblings on `PERL5LIB`: `routes` byte-identical to baseline; the cross-dist DI
  works (`Domain registries built: rtr,se` — the EPP+RTR adapters construct with injected clients from
  the epp/realtimeregister dists); all views resolve from the right siblings; core suite unchanged.

**Per-plugin migration re-architecture done (2026-06-10, branch `packaging/e-migrations`)** — the
monolithic 24-step PG sequence is replaced by **one fresh-snapshot migration per schema**
(`pg_dump --schema-only` of the live dev DB), each loaded as its own **named** Mojo set. Each set is a
directory `resources/migrations/pg/<NN>-<schema>/<version>/{up,down}.sql` (the `from_dir` layout —
version 1 is the snapshot; later pgModeler schema-diff dumps drop in as new version dirs) in the owning
repo (core keeps `public/account/article/customer/web/mailer/poll/sms/stats/example`; payment schemas
`nets/paypal/stripe/swish` and the dist schemas `website/certificate/bis(domain)/postfix(email)/
database/zone` ship in their dists). The new `run_migrations` helper (replacing the single `from_dir`
at `Samizdat.pm:179`) globs the `<NN>-<schema>` dirs under `resources/migrations/{pg,mysql}/` across
every dist on `@INC`, sorts by basename, loads each via `->from_dir`; the `<NN>` prefix encodes
cross-schema FK **dependency tiers** (10 public → 20 account/article → 30 customer → 40 deps → 50
website → 60 web). **Existing deployments are grandfathered** (a snapshot whose first table already
exists is stamped, not re-run). The one cross-schema **cycle FK** `customer.services→website.websites`
was dropped (core shouldn't FK into a dist schema; app-enforced soft ref now). `schema/*.sql` removed:
`bis/paypal/swish` were already captured from the live DB; `nets/stripe` converted to core migrations.
A **mysql** tree is wired in the loader (capability) but no plugin ships mysql migrations yet (the only
mysql is the legacy/external `system2`/`powerdns`). **Validated on scratch DBs**: fresh install builds
20 schemas/124 tables in dependency order; grandfather leaves an existing schema untouched; re-runs are
no-ops; live boot grandfathered 18 sets + applied nets/stripe with the table count otherwise unchanged.
Pre-req for fresh installs on fakenews/rymdweb. (Remaining: extract the payment plugins; `Samizdat-
Resources`; `samizdat-site`; remotes/CI.)

**E payment plugins done (2026-06-10, branch `packaging/e-payments`)** — **Nets, PayPal, Stripe, Swish**
extracted to `samizdat-{nets,paypal,stripe,swish}` (operator). Each was a clean self-contained module:
trio + operator settings schema (writeOnly secrets) + templates + locale + **its own pg migration**
(`40-<name>.sql`, which now travels with the plugin — the first time a per-plugin migration moved out
of core with its plugin). **No core decoupling needed** — core never used the payment helpers; the only
consumers are Invoice's helper-guarded pay-modal flags, and Invoice is a sibling dist. Verified: routes
byte-identical to baseline; the migration loader finds all 20 named sets with the 4 payment migrations
resolving from their sibling repos; core suite unchanged. Payment certs (Swish `.p12`, etc.) stay
deployment secrets — never shipped. **14 sibling dists now.** Remaining: `Samizdat-Resources` (vendored
3rd-party assets), `samizdat-site`, GitHub remotes/CI, the `.claude` plugin, `samizdat-plugin-template`.

**E Resources + site repo done (2026-06-10, branch `packaging/e-resources`)** — the last extractions:
- **`Samizdat-Resources`** (`~/IdeaProjects/samizdat-resources`) — vendors the read-only **runtime**
  third-party data (`countries-data-json/data`, `i18n-iso-languages/langs`, Noto `fonts`; MIT + SIL OFL)
  under `lib/Samizdat/resources/shared/`, so installs are offline (no `make fetchall`/git/npm). Raw
  bootstrap-icons/flag-icons stay build-time (their processed bundle ships in core). The **`sharedir`
  helper became a multi-root resolver** (like the resource resolver): `SAMIZDAT_SHARED_SRC` → install
  share → every `Samizdat/resources/shared` on `@INC` → checkout `src/`; `sharedir(@rel)` returns the
  first root that contains `@rel`; consumers moved from `sharedir->child(x)` to `sharedir(x)`. Noto
  fonts removed from core `src/`. Verified: routes identical; `sharedir` resolves fonts/countries/
  languages from Resources.
- **`fakenews.com-src`** (`~/IdeaProjects/fakenews.com-src`) — the **per-site deploy repo** (the source
  for fakenews.com). Holds the site **content** (`public/`, moved out of core so core is content-free),
  a `samizdat.dist.yml` template, and a secrets `.gitignore`. Core keeps a gitignored `src/public`
  symlink so the dev checkout still renders with the default config; a real deploy sets
  `paths.content` → the site repo. The static content path now follows `contentdir` (not a hardcoded
  `src/public`). Verified: `GET /` renders the home page from the site content via the symlink.

**The extraction is complete** — core ships only core modules + core schemas (plus a minimal default
`src/public/README_en.md` "It works!" landing page that links to the docs); every feature module,
the vendored runtime data, and per-site content live in their own repos (**17 sibling repos**: 13
public plugin dists + private EPP + Samizdat-Resources + two site repos **fakenews.com-src** and
**samizdat.foundation-src**). `samizdat.foundation-src` carries the project site + early
documentation (architecture, distributions, per-plugin migrations, content model, install).

**Customer extracted too (2026-06-10, `packaging/e-customer`)** — see §2.9 (superseded). `Customer` →
`Samizdat-Plugin-Customer` (foundational dist): trio + templates + the `30-customer` migration (which
also holds the invoice/payment tables). No core decoupling (core never used the helper). It's a
**dependency hub**: certificate/database/website/paypal/stripe/swish + core's `mailer` schema FK into
`customer.customers`, and Invoice's data lives in the customer schema — so it's effectively **required**
for a fresh install (loader runs it at tier 30, before its dependents). Verified: routes identical;
fresh install builds all 20 schemas incl. customer (with invoices/payments) from the dist. Known
follow-up: `t/02-webp.t` fetches a `/test/…webp` image that moved to fakenews.com-src with the content
(core is content-free) — the test needs a core fixture or to move to the site repo.

**Six more modules extracted (2026-06-10, `packaging/e-misc`)** — **Mailer, BIS, BuyMeACoffee, Chat,
Poll, SMS** → `samizdat-{mailer,bis,buymeacoffee,chat,poll,sms}`. All clean (no core coupling). Mailer/
Poll/SMS carry their pg migration out; BIS its `bischeck`/`biscollect`/`bisimport` commands. **Corrected
a prior mistake:** the `bis` templates/locale + `40-bis` migration had been wrongly bundled into
samizdat-domain during the Domain extraction — they belong to BIS and are now in samizdat-bis (Domain
has no PG schema of its own — registrar data is legacy mysql/external). Verified: routes identical
(Chat loads from its sibling; the rest weren't in `extraplugins`); fresh install builds all 20 schemas
incl. bis/mailer/poll/sms from their dists. **24 sibling repos now** (21 plugin dists + Samizdat-
Resources + 2 site repos). Core's remaining schemas: public/account/article/example/stats/web.

Remaining is the **productionize tail**: GitHub remotes + CI per dist, the `.claude` automations
plugin, and the `samizdat-plugin-template` — none of which pulls code out of core.

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