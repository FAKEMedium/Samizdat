# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Samizdat is a Mojolicious-based Perl web application functioning as a static content hybrid generator.
It prioritizes performance, internationalization, and offline capabilities.
The project powers fakenews.com and allows for lightning-fast content delivery even under high traffic loads.

Key features:
- Content in human-readable formats (Markdown, YAML)
- Multi-language support (English, Swedish, Russian, etc.) with support for AI assisted translation
- Performance optimization (WebP images, caching, minimization)
- Semantic HTML5 with automatic layouts
- Management system for web hosting providers
- Integration with external services (Fortnox, Realtime Register, Buy Me a Coffee, etc.)
- Pulls in various data sources and use them in helper functions
- Split CLAUDE.md into multiple files for better organization and context management
- CSP and security best practices for a safe browsing experience

## Architecture

Samizdat follows an MVC architecture:
- Controllers (`lib/Samizdat/Controller/`) - Handle HTTP requests
- Models (`lib/Samizdat/Model/`) - Business logic and data access
- Templates (`templates/`) - View layer using Mojolicious EP templates
- Plugins (`lib/Samizdat/Plugin/`) - Routes and helpers that extend the application functionality

The application integrates:
- PostgreSQL database (via Mojo::Pg) - Primary database for new features
- MariaDB/MySQL database (via Mojo::mysql) - Legacy database, being phased out
- Redis for caching and sessions
- Webpack for frontend asset bundling
- Openresty (nginx) for static content (optional) and load balancing

### Database Migration

The application is currently in a transition phase from MariaDB to PostgreSQL:
- **Legacy System**: An older MariaDB database (`system2.sql`) contains tables used by legacy Perl CGI scripts not present in this application. Some classes still reference this database for backward compatibility.
- **Current Practice**: All new features should use PostgreSQL. When encountering code that uses the MySQL database, consider it legacy code that may eventually be migrated.
- **Database Access**: Models should use `$self->pg` for PostgreSQL and `$self->mysql` for legacy MariaDB access (when absolutely necessary).
- **Configuration**: Each manager section in `samizdat.yml` can specify `dbtype` to control which database the module uses:
  - `postgresql` (default) - PostgreSQL database
  - `mysql` - Legacy MySQL/MariaDB database
  - `redis` - Redis for caching and key-value storage
  - Models should check `$self->config->{dbtype}` to determine the appropriate database connection and table names.

Speed and performance are prioritized through:
- Static content generation for downstream delivery
- Minification of assets
- Use of WebP images in multiple sizes
- Data served as JSON for dynamic content on RESTful endpoints
- Use a serviceworker and Nginx wildcard matches to make smarter use of browser cache.
- Use of OpenAPI for defining RESTful endpoints and generating documentation.
- Use of Redis for caching and session management to reduce database load.

## Development Commands

### Setup
```bash
# Copy configuration template
cp samizdat.dist.yml samizdat.yml

# Set up PostgreSQL database
make database

# Get external resources (bootstrap icons, flags, country data, language data)
make fetchall

# Initialize webpack
make webpackinit
```

### Development
```bash
# Start development server with hot reloading
make debug

# Run test suite
make test

# Update translation files (.po and .mo)
make i18n

# View all routes
make routes

# Build frontend assets
make webpack
```

### Static Content Generation
```bash
# Clean public directory
make clean
```

### Production
```bash
# Start production server with hypnotoad
make server
```

### Utilities
```bash
# Generate icon assets
make icons

# Create favicon
make favicon
```

## File Structure

- `bin/` - Executable scripts
- `lib/Samizdat/` - Perl modules for the application
  - `Command/` - CLI commands that extend the samizdat tool
  - `Controller/` - Request handlers
  - `Model/` - Business logic and data access
  - `Plugin/` - Functionality extensions
- `locale/` - Translation files (.po and .mo)
- `public/` - Generated content (with symlinks for default language)
- `templates/` - Templates, layouts, and smaller chunks
- `schema/` - Some SQL schema files for (experimental) extras
- `src/` - Source files for frontend
  - `js/` - JavaScript files
  - `scss/` - SCSS stylesheets
  - `public/` - Content to be processed (markdown with language suffixes)
- `migrations/` - Database migration scripts

## Markdown File Naming Convention

All markdown files in `src/public/` must include a language suffix:

- `README_en.md` - English content (default language)
- `README_sv.md` - Swedish content
- `README_ru.md` - Russian content
- `01-sidecard_en.md` - English sidecard
- `01-sidecard_sv.md` - Swedish sidecard

This convention applies to:
- Main content files (`README_xx.md`)
- Sidecard files (`NN-name_xx.md`)

After rendering, index.xx.html are created in `public/, as well as an index.html symlink` for the default language:
- `index.html` -> generated from `README_en.md`

The database stores content with language-specific src paths (e.g., `project/README_en.md`).
Title and description are extracted from markdown content (frontmatter or `# heading`).

## Frontend Development

The frontend uses:
- Bootstrap 5 as the CSS framework
- Webpack for asset bundling
- SCSS for styling
- JavaScript for interactivity and adding dynamic data in headless mode

Webpack commands:
```bash
# Install dependencies
npm install

# Build assets
npm run build
```
## Implementation Notes

The codebase is designed to be modular and extensible. Key implementation notes include:

- If a page has javascript in it, it's in its own js file in the templates tree.
- The js files have the same name as the template they are associated with.
- Use index.js for route specific javascript. We run "make eplinks" for index.js.ep generation. It's because js and ep files get different treatment in IntelliJ.
- The associated javascript gets rendered and appended into $web->{script}, and inserted into bootstrap.html.ep layout, which wraps it in a DOMContentLoaded handler. JavaScript templates should NOT include their own DOMContentLoaded listeners.
- A similar approach is used for CSS files, where a .css.ep file is symlinked to the .css file in the templates tree. $web->{css} is used to render the CSS files into the head of bootstrap.html.ep.
- **IMPORTANT — template naming**: every page template MUST be `<dir>/index.html.ep` (with `index.js` + `index.js.ep` symlink). NEVER add a sibling like `show.html.ep` or `edit.html.ep` next to an `index.html.ep`. For a second view, create a new subdir and use `index.*` inside it. Example: `templates/email/admins/index.*` (list) vs `templates/email/admins/admin/index.*` (detail). This pattern is required for OpenResty static-cache pickup.
- Code is developed in IntelliJ Ultimate for Ubuntu, but intended to run in a FreeBSD jailed environment.
- Most modules exist in all 3 of Model, Controller, and Plugin directories, with the Controller directory being the most important.
- The plugin adds routes and a helper based on the associated model. Some routes are named so the url_for helper can be used to generate URLs.
- Make things configurable via samizdat.yml, which is read by the application at startup. Try make configuration in a structure so only model specific parts are passed to the helper.
- Don't stash data in templates. Use fetch, json and javascript.
- Don't query database in controller. Use methods in model (and thus plugin helper too) instea!
- Don't hardcode links. Use route names and url_for helper to generate links.
- Use OpenAPI with operationId as url_for parameter for data handling routes.
- Use config.dsn.pg settings from samizdat.yml when calling psql for database management.

## Testing

Tests are located in the `t/` directory and use Test::Mojo for endpoint testing:

```bash
# Run all tests
make test

# Run a specific test
prove -l -v t/00-basic.t
```
## Claude Code Automations

Team-shared Claude Code config lives in `.claude/` (committed; only
`.claude/settings.local.json` is personal/git-ignored):

- **Hooks** (`.claude/settings.json` + `.claude/hooks/`):
  - `block-secrets.pl` (PreToolUse) — refuses Edit/Write/Read of secret files
    (`*.key`, `*.p12`, `samizdat.yml`, `*.rc`, `*_dump.sql`, etc.). Pull a value
    out of `samizdat.yml` with `grep` via Bash instead of reading the file.
  - `perl-syntax-check.pl` (PostToolUse) — runs `perl -c -Ilib` on edited
    `.pm`/`.pl`/`.t` files.
- **Subagents** (`.claude/agents/`): `samizdat-conventions-reviewer` (MVC
  layering, model ownership, template/route naming, dbtype, i18n) and
  `payments-security-reviewer` (Stripe/PayPal/Swish/Nets/Fortnox/EPP, certs).
- **Skills** (`.claude/skills/`): `/new-module` scaffolds the
  Model+Controller+Plugin trio (+ optional CLI command); `/create-migration`
  creates the next `migrations/pg/<N>/` up/down pair.

## Todo List

- Build lua scripts for OpenResty to handle authorization and injecting small bits of data into a cookie. Use redis for data sharing with the application
- Implement a comprehensive admin interface for managing content, users, and settings.
- Implement a content approval workflow for user-generated content.
- Implement acceess control lists (ACLs) for fine-grained permissions on content and user actions.
- User registration with personal profiles and content management.
- Discussion forums for community engagement.
- Messaging between users with real-time notifications.
- Sitewide installation with multidomain support (source trees and cached generated content).
- Image administration interface.
- Handle some REST routes in OpenResty directly to database, bypassing the application.
- msgpack for some REST endpoints to speed up data transfer.