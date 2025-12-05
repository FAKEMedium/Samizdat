# Samizdat

Read more about the [project](./public/project/) in the public directory.
The documentation is part of the generated site.
[Fakenews.com](https://fakenews.com/) runs on the code and content in this repository.
You can use this as a simple publishing tool with
<a href="https://pagespeed.web.dev/report?url=https%3A%2F%2Ffakenews.com%2F" target="_blank">lightning fast results</a>.

Speed is accomplished by using server-side rendering with caching, minimal JavaScript and optimized images.
Data is stored in PostgreSQL, cached in Redis and served as json via a FastCGI interface using Nginx. No third
party CDN:s, includes or cookies are used.


## Hosting panel

Samizdat is also growing into a fullly fledged hosting panel, with many plugins to choose from. This functionality
is used on [rymdweb.com](https://rymdweb.com/).


### Users

A user management system with support for multiple user roles and permissions.

- User registration with captcha and email verification
- Password reset via email
- User profiles with editable information
- Admin dashboard for managing users and roles


### Invoicing

A complete invoicing system with support for multiple currencies and tax rates.

- Create, edit and credit invoices
- PDF generation with LATEX for precise typography and paginated multipage
- Email sending of invoices and reminders
- Payment tracking and reporting
- Support for different payment methods (e.g., PayPal, IBAN)
- Provisioning functionality for other Samizdat modules
- Admin dashboard for managing invoices and payments


### Accounting

A basic connection to Swedish online accounting system Fortnox via their API.

- Sync customers and invoices with Fortnox
- Automatic bookkeeping of invoices
- Reading payment status from Fortnox
- Admin dashboard for managing Fortnox and generating reports
- Support for Swedish accounting standards


### Zones

A frontend to PowerDNS Authoritative Server, using API with optional extra support for PostgreSQL backends.

- Create, edit and delete zones
- Create, edit and delete records
- Import and export zones in BIND format
- Support for DNSSEC signing and key management
- Template sets for easy creation of common zones (not yet implemented)
- Different access levels for users (customers) and admins


### Email

A frontend to Postfix mail server, using Dovecot for IMAP/POP3 access and PostgreSQL backend.
This module is still under development. It's intended to be a drop-in replacement for Postfixadmin.


### Domains

A module for interaction with Realtime Register domain registrar via their API is included.
There also exist a module for .SE/.NU domains via EPP, but it's not included in the main repository


### Web content

A module for managing web content.

- Edit static pages with extended GFM flavored markdown support using Toast-UI editor
- Managing different menus
- Multi language support
- Storage as files or in database
- Image upload and optimization
- Meta tags and SEO support
- Admin dashboard for managing content and menus
- Access control for different user roles
- Versioning and history tracking of content by Git (not yet implemented)
- Shared editing with multiple users (not yet implemented)


### SMS

Utilities for sending and receiving SMS with a Teltonika GSM modem via its' HTTP API.
When enabled, other modules can use this for sending SMS notifications, 2FA codes, phone verifications, etc.


### Payments

- Swish payments via API (for Swedish market, not yet implemented)
- PayPal payments via API (not fully implemented)
- Nets payments via API (not yet implemented)


### Other features

- Matomo snippet integration for privacy friendly analytics
- BuyMeACoffee snippet integration for donations
- Icon helper for including SVG icons into symbol defs
- Importing of flags, language names and country data from public sources, and providing them as helper functions
- Wrapping img tags with picture tags for responsive images and WebP support in multiple sizes
- Cache management (session encrypted or not) with Redis
- Configuration in yaml file
- Makefile for building, minimizing (Webpack, PurgeCSS) and deploying the site
- FreeBSD and Ubuntu support with installation documentation and startup scripts
- Proper handcrafted indentation as procrastination therapy
- Unit tests with Mojolicious::Test


### Technologies used

- [Mojolicious](https://mojolicious.org/) modern web framework for Perl
- JavaScript (ES6) for client-side interactivity
- CSS3
- HTML5
- Git for version control
- [Bootstrap 5](https://getbootstrap.com/) for UI components and layout
- PostgreSQL for data storage
- Redis for caching
- [OpenResty](https://openresty.org/) (Nginx) for web server and FastCGI interface
- Lua for OpenResty/Nginx scripting
- Makefile for build automation
- LATEX for PDF generation
- Webpack for JavaScript and CSS bundling and minimization
- [Toast-UI](https://ui.toast.com/) editor for markdown editing
- CLAUDE.md in many directories for AI assisted development


### Plans for future development

- [OpenAPI/Swagger](https://github.com/jhthorsen/mojolicious-plugin-openapi) endpoints/documentation for the API
- ActivityPub support for decentralized publishing
- More payment gateways
- Additional hosting modules (e.g., FTP, Certificates, Databases)
- Improved user interface and user experience (Tailwind CSS, Flowbite?)