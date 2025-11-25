# JS source files

Entry points and utilities can be installed system-wide via `make installshared` to
`/usr/local/share/samizdat/src/`. Site-specific files remain in the local `src/` directory.

Webpack resolves `@shared` and `@site` aliases to the appropriate paths.

## Entry points

* samizdat.js - main entry point for all users
* authenticated.js - additional JS for logged-in users
* simple-editor.js - content editor
* sw.js - service worker

## Utilities

* apidom.js - DOM utilities and fetch wrappers
* user.js - user session handling
* sortby.js - table sorting
* tablesorter.js - table sorting utilities
* serviceworker.js - service worker registration
* language.js - language utilities

## Site-specific

* local.js - site customizations (gitignored)