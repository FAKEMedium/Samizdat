# Samizdat settings schemas

Each module ships `lib/Samizdat/resources/settings/<module>/schema.yml` — a JSON Schema
(Draft 2020-12) describing its configuration. The core resolver
(`Samizdat::Model::Settings`) loads it, applies `default`s as the **package layer**, merges
the **platform layer** (`samizdat.yml` → `manager.<module>`) on top, and validates the result.

`__('msg')`-style runtime translation aside, this is the single source of truth for a module's
config contract: defaults live here (not in `samizdat.dist.yml`, which keeps only secrets and
site-specifics).

## The `x-samizdat-*` profile (standard JSON Schema + extensions)

| Keyword | Where | Meaning |
|---|---|---|
| `default` | per key | package-layer default value (resolver applies it; JSON::Validator does not) |
| `writeOnly: true` | per key | **secret** — never logged or exposed to a customer (standard JSON Schema hint) |
| `x-samizdat-audience` | schema root | `core` \| `operator` \| `offerable` — who the module is for |
| `x-samizdat-scope` | per key | delegation ceiling `platform` \| `customer` — declared now, **enforced in Phase 2** |
| `x-samizdat-version` | schema root | schema version (for future migrations) |

Schemas are permissive (`additionalProperties` not set to `false`) so a module may carry extra
keys the schema doesn't yet describe.

## Phase status
- **Phase 1 (now):** package + platform layers, validation, defaults. Context is always the
  operator; `x-samizdat-scope` is declared but not enforced.
- **Phase 2:** DB-backed customer + site layers, per-key `x-samizdat-scope` ceiling enforcement,
  and an auto-generated settings UI driven by these schemas.
