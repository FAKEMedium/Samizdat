# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Samizdat is a Mojolicious-based Perl web application functioning as a static content hybrid generator.
Inspired by the underground publishing practices of the former Eastern Bloc, it prioritizes performance,
internationalization, and offline capabilities.
The project powers fakenews.com and allows for lightning-fast content delivery even under high traffic loads.

Key features:
- Content in human-readable formats (Markdown, YAML)
- Multi-language support (English, Swedish, Russian, etc.)
- Performance optimization (WebP images, caching, minimization)
- Semantic HTML5 with automatic layouts
- ISO image packaging for offline distribution
- Management system for web hosting providers
- Integration with external services (Fortnox, Realtime Register, Buy Me a Coffee, etc.)

## Architecture

Samizdat follows an MVC architecture:
- Controllers (`lib/Samizdat/Controller/`) - Handle HTTP requests
- Models (`lib/Samizdat/Model/`) - Business logic and data access
- Templates (`templates/`) - View layer using Mojolicious EP templates
- Plugins (`lib/Samizdat/Plugin/`) - Extend functionality

The application integrates:
- PostgreSQL database (via Mojo::Pg)
- Redis for caching and sessions
- Webpack for frontend asset bundling
- Openresty (nginx) for static content (optional)

Speed and performance are prioritized through:
- Static content generation for downstream delivery
- Minification of assets
- Use of WebP images in multiple sizes
- Data served as JSON for dynamic content on RESTful endpoints

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

# Update translation files
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

# Generate static content
make static

# Create ISO image for offline distribution
make iso
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

# Sync invoices
make syncinvoices

# Generate Fortnox integration
make fortnox
```

## File Structure

- `bin/` - Executable scripts
- `lib/Samizdat/` - Perl modules for the application
  - `Command/` - CLI commands that extend the samizdat tool
  - `Controller/` - Request handlers
  - `Model/` - Business logic and data access
  - `Plugin/` - Functionality extensions
- `public/` - Generated content
- `templates/` - Templates, layouts, and smaller chunks
- `src/` - Source files for frontend
  - `js/` - JavaScript files
  - `scss/` - SCSS stylesheets
  - `public/` - Content to be processed
- `migrations/` - Database migration scripts

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
- A .js.ep file is symlinked to the .js file in the templates tree. It's because js and ep files get different treatment in IntelliJ.
- The associated javascript gets rendered into $web->{script} and inserted into bootstrap.html.ep, which wraps it in a DOMContentLoaded handler. JavaScript templates should NOT include their own DOMContentLoaded listeners.
- A similar approach is used for CSS files, where a .css.ep file is symlinked to the .css file in the templates tree. $web->{css} is used to render the CSS files into the head of bootstrap.html.ep.
- Primarily use index.* template names for easier pickup by OpenResty.
- Code is developed in IntelliJ Ultimate for Ubuntu, but intended to run in a FreeBSD jailed environment.
- Most modules exist in all 3 of Model, Controller, and Plugin directories, with the Controller directory being the most important.
- The plugin adds routes and a helper based on the associated model. Some routes are named so the url_for helper can be used to generate URLs.
- Make things configurable via samizdat.yml, which is read by the application at startup. Try make configuration in a structure so only model specific parts are passed to the helper.
. "make i18n" collects strings , generates a .po file, and then compiles it to a .mo file for use in the application.

## Testing

Tests are located in the `t/` directory and use Test::Mojo for endpoint testing:

```bash
# Run all tests
make test

# Run a specific test
prove -l -v t/00-basic.t
```
## Todo List

- Build lua scripts for OpenResty to handle authorization and injecting small bits of data into a cookie. Use redis for data sharing with the application
- Implement a comprehensive admin interface for managing content, users, and settings.
- User registration with personal profiles and content management.
- Discussion forums for community engagement.
- Sitewide installation with multidomain support (source trees and cached generated content).
- Database overlay of markdown files for dynamic content management.
- Image administration interface.

## Experimental Ideas

- Handle some REST routes in OpenResty directly to database, bypassing the application.