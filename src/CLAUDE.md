# Samizdat third party sources and more

These are fetched in root Makefile and are then used by helper functions

- countries-data-json
- flag-icons
- fonts
- i18n-iso-languages
- icons

Webpack builds and optimizes main assets with entries in js/.

public/ holds markdown files and other static assets that are procesed and copied to the final build output,
that also gets stored in public/ of the root project.

Markdown files can come in many language variants with name schema somefile_xx.md,
where xx is the language code, e.g. en, de, fr, etc.

README.md is intended for main content in the resulting index.html file.
If additional markdown files are present, they will be sorted alphabetically
and rendered as cards inside a sidecolumn in index.html.

## Goal

- Install the application system wide with all dependencies,
but with per customer/site configuration and src/public/ content