# SCSS source files

Entry points and partials can be installed system-wide via `make installshared` to
`/usr/local/share/samizdat/src/`. Site-specific files remain in the local `src/` directory.

SCSS `loadPaths` includes both shared and site directories.

## Entry points

* samizdat.scss - main styles for all users (imports Bootstrap)
* authenticated.scss - additional styles for logged-in users

## Partials

* _editor.scss - TipTap editor styles
* _icon-list.scss - icon list styles
* _rtl.scss - right-to-left language support

## Site-specific

* local.scss - site customizations (gitignored), imported by samizdat.scss
