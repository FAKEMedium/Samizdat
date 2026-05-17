---
name: new-module
description: Scaffold a new Samizdat feature module — the Model + Controller + Plugin trio plus templates and a test, and optionally a bin/samizdat CLI command, wired to conventions (route names, OpenAPI, model ownership, index.html.ep template naming). Use when adding a new manager/feature area.
disable-model-invocation: true
---

# new-module

Scaffold a complete Samizdat feature module following the conventions in `CLAUDE.md`,
`lib/Samizdat/Controller/CLAUDE.md`, and `lib/Samizdat/Model/CLAUDE.md`.

The canonical reference implementation is the **Example** trio — read these three files
first and mirror their structure:

- `lib/Samizdat/Model/Example.pm`
- `lib/Samizdat/Controller/Example.pm`
- `lib/Samizdat/Plugin/Example.pm`

## Inputs

Ask the user for (if not given as arguments):

1. **Module name** in StudlyCaps, e.g. `Invoice`, `Poll`. Derive:
   - Package suffix: the name as-is (`Foo`)
   - Helper / lower name: lowercased (`foo`)
   - Route slug (plural for manager): ask, default lowercased+`s` (`foos`)
   - PG schema + table: ask, default `foo.foo`
2. **dbtype**: `postgresql` (default), `mysql`, or `redis`. Drives whether the
   model takes `pg`/`mysql`/`redis` and which table names it uses.
3. Whether it needs **manager (HTML)** routes, **OpenAPI (JSON)** routes, or both.
4. **Does it need a `bin/samizdat` CLI command too?** Ask explicitly — default
   no. Only scaffold step 4 if the user says yes (e.g. for cron jobs, batch
   sync, imports, dumps). If yes, ask for the command name (default: lowercased
   module name) and a one-line description.

## Steps

### 1. Model — `lib/Samizdat/Model/<Foo>.pm`

- `use Mojo::Base -base, -signatures;`
- `has 'pg';` (or `mysql`/`redis` per dbtype) and `has 'config';`
- CRUD methods mirroring `Model/Example.pm`: `get`, `find`, `create`, `update`,
  `delete`, `count`, `search`. Use `$self->pg->db->...` query/insert/update/delete
  with `{returning => '*'}`. Never put SQL in the controller.
- **Sub-model ownership** (project rule): if this model needs a helper sub-model
  (DB wrapper, external API client, CLI bridge), the parent owns it as a lazy attr:
  `has bar => sub ($self) { Samizdat::Model::<Foo>::Bar->new(config => $self->config) };`
  The plugin must NOT instantiate sub-models. (See memory: model composition by
  ownership, not injection. Zone's inject-from-plugin pattern is legacy — do not copy.)

### 2. Controller — `lib/Samizdat/Controller/<Foo>.pm`

- `use Mojo::Base 'Mojolicious::Controller', -signatures;`
- Field arrays at top: `$fields`, `$checkfields`, `$setfields`.
- Actions `index`, `show`, `edit`, `create`, `update`, `delete` exactly like
  `Controller/Example.pm`:
  - Each GET branches on `Accept`: non-JSON renders the HTML template (for the
    static cache); JSON path calls `$self->access({...})` then the model.
  - Controllers only pass data as JSON; **no DB queries in the controller**.
  - Set `$self->stash(docpath => '/<slug>/show/index.html')` on routes with
    dynamic `:id` so the static cache collapses to one file per view.
  - Pass templating vars via the `web => \$web` stash; render the JS template into
    `$web->{script}` with `render_to_string(template => '<slug>/index', format => 'js')`.
  - Private `_formdata` helper for param extraction/validation.

### 3. Plugin — `lib/Samizdat/Plugin/<Foo>.pm`

- `use Mojo::Base 'Mojolicious::Plugin', -signatures;` + `use Samizdat::Model::<Foo>;`
- In `register`:
  - Manager HTML routes via `$r->manager('<slug>')->to(controller => '<Foo>')`
    with **named** routes (`<foo>_index`, `<foo>_show`, `<foo>_edit`, `<foo>_new`)
    so `url_for` works. Never hardcode links.
  - JSON/data routes defined in the `@@ openapi.yaml` `__DATA__` section with
    `operationId` + `x-mojo-to`, stored via
    `$app->config->{openapi_fragments}{<Foo>} = data_section(...)`.
  - Helper instantiates **only the top-level model**, passing the scoped config:
    ```perl
    $app->helper(<foo> => sub {
      state $model = Samizdat::Model::<Foo>->new({
        pg     => $app->pg,                       # or mysql/redis per dbtype
        config => $app->config->{manager}->{<foo>},
      });
      return $model;
    });
    ```
  - Include the POD + NGINX regex-route notes block like `Plugin/Example.pm`.

### 4. CLI command — `lib/Samizdat/Command/<name>.pm` *(only if the user asked for one)*

Skip this step entirely unless the user answered yes in input 4. Model after
`lib/Samizdat/Command/syncdomaincustomers.pm`:

- `package Samizdat::Command::<name>;`
- `use Mojo::Base 'Mojolicious::Command', -signatures;` + `use Mojo::Util qw(getopt);`
- `has description => '<one-line description>';`
- `has usage => sub ($self) { $self->extract_usage };`
- `sub run ($self, @args) { getopt \@args, 'dry-run' => \my $dry_run, ...; ... }`
- Reach the feature through the model helper, not raw DB:
  `my $model = $self->app-><foo>;` — the command instantiates **only the
  top-level model** (consistent with the model-ownership rule; do not wire
  sub-models in by hand).
- End the file with a POD section so `extract_usage` works:
  ```
  =encoding utf8

  =head1 NAME

  Samizdat::Command::<name> - <description>

  =head1 SYNOPSIS

    Usage: bin/samizdat <name> [OPTIONS]

      --dry-run   Show what would change without writing

  =cut
  ```
- Add a Makefile target if it is meant to be run regularly (mirror existing
  targets like `dump:`/`fortnox:` that call `bin/samizdat <name>`).
- Verify it is listed: `bin/samizdat` (command index) and
  `perl -c -Ilib lib/Samizdat/Command/<name>.pm`.

### 5. Templates

Every page template MUST be `templates/<slug>/index.html.ep` with a sibling
`index.js` and an `index.js.ep` symlink. For a second view use a **subdir**:
`templates/<slug>/show/index.*`, `templates/<slug>/edit/index.*` — NEVER
`show.html.ep`/`edit.html.ep` next to `index.html.ep` (breaks OpenResty cache pickup).
JS templates must NOT add their own `DOMContentLoaded` (the layout wraps them).
Run `make eplinks` to regenerate the `index.js.ep` symlinks.

### 6. Config

Add a `manager.<foo>` section to `samizdat.dist.yml` (and note the user should
mirror it in `samizdat.yml`) with at least `dbtype:` and any module-specific keys.
Only the model-specific subtree is passed to the helper.

### 7. Test — `t/NN-<foo>.t`

Add a `Test::Mojo` test following `t/00-basic.t` style: instantiate
`Test::Mojo->new('Samizdat')`, hit the index route, assert status. Use the next
free `NN` prefix.

## Verify

- `perl -c -Ilib lib/Samizdat/Model/<Foo>.pm` (and Controller, Plugin) pass.
- The plugin is registered where other plugins are (check `lib/Samizdat.pm`).
- `make routes` shows the new named routes.
- `make test` (or `prove -lv t/NN-<foo>.t`) passes.

Report each created file and the verification results. Do not edit `samizdat.yml`
(it holds secrets) — only update `samizdat.dist.yml` and tell the user what to add.
