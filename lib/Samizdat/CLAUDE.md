# CLAUDE.md, Samizdat main lib

A recipe for rapid development and try-out of new features

- Set up common stuff in Samizdat.pm
- Add routes and helpers in plugins
- Corresponding models and controllers
- Aim for a single model helper per sub-application
- Try to keep logic in the model to avoid abundance of helpers
- Most tasks should be possible to perform from command line too

The last included plugin, Web, catches non-matched routes and tries them against the database and the
markdown files in src/public.

## Core vs. plugin dists

This `lib/Samizdat/` tree is the **core** distribution: `Samizdat.pm` (shared wiring) and the
core models/controllers/plugins (Web, Account, Cache, Public, Settings — see
`Model/CLAUDE.md`). Most sub-applications now live in their **own dists** (`samizdat-<name>`,
published to CPAN/pkg) rather than in this tree; each ships its trio plus its own
`resources/` (settings schema, migrations, templates, locale), which core's resolver unions
from every `Samizdat/resources` on `@INC`.

- **New sub-application** → scaffold a dist with `samizdat-plugin-template`
  (`new-plugin.sh`) or the `/new-module` skill; develop it as a sibling on `PERL5LIB`. Put
  module-specific defaults in its own `resources/settings/<module>/schema.yml`, not in core.
- **Cross-module calls are optional/guarded**: reach another module via
  `$app->renderer->helpers->{<helper>} ? $app-><helper>->… : …` so core (and other plugins)
  degrade gracefully when a dist is not installed.
- **Backends are optional at boot**: PostgreSQL (`dsn.pg`) and Redis (`manager.cache.redis`)
  may be absent — core skips pg/Minion and falls back to an in-process cache so the app boots
  for first-run setup. Keep new code tolerant of this.

See `MIGRATION.md` for the monorepo→polyrepo split and the multi-dist resolver.
