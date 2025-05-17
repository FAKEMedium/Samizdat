# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Samizdat is a Mojolicious-based Perl web application functioning as a static content hybrid generator. Inspired by the underground publishing practices of the former Eastern Bloc, it prioritizes performance, internationalization, and offline capabilities. The project powers fakenews.com and allows for lightning-fast content delivery even under high traffic loads.

Key features:
- Content in human-readable formats (Markdown, YAML)
- Multi-language support (English, Swedish, Russian)
- Performance optimization (WebP images, caching, minimization)
- Semantic HTML5 with automatic layouts
- ISO image packaging for offline distribution
- Invoice and customer management system
- Domain/DNS administration

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
- Nginx for static content (optional)

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
- `public/` - Static files and generated content
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
- JavaScript for interactivity

Webpack commands:
```bash
# Install dependencies
npm install

# Build assets
npm run build
```

## Testing

Tests are located in the `t/` directory and use Test::Mojo for endpoint testing:

```bash
# Run all tests
make test

# Run a specific test
prove -l -v t/00-basic.t
```