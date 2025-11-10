# Samizdat models

## SMS

We use a Teltonika device (RUTXR1) to send and receive SMS messages. We also use sms to http
gateway forwarding messages. SMS functions include a form and controller for sending messages,
as well as automated outgoing message for stuff like account verification codes.

There is developer documentation for Teltonika at https://developers.rms.teltonika-networks.com/,
including OAuth info and API docs.

### Authentication

The SMS model supports two authentication methods:

1. **CGI Mode** (`api_type: cgi` - default): Uses username/password authentication with the legacy CGI endpoints
2. **API Mode** (`api_type: api`): Uses OAuth 2.0 client credentials flow with the modern REST API

Configuration is under `manager.sms` with OAuth2 settings in `manager.sms.oauth2`.
The OAuth2 provider is automatically registered as 'sms' by Samizdat.pm.

For API mode, the oauth2 section needs:
- `key`: OAuth client ID from Teltonika device
- `secret`: OAuth client secret from Teltonika device
- `token_url_template`: Token endpoint with {protocol} and {host} placeholders

The model automatically handles OAuth token acquisition and caching for API requests.


## Fortnox

Fortnox is a Swedish cloud-based accounting and invoicing service. The Fortnox model
provides integration with the Fortnox API for managing customers, invoices, accounting and payments.
The Samizdat application has own models for customers and invoices, which can be synchronized
with Fortnox. To have proper accounting without sharing personal data with a third party, like Fortnox,
is a selling point for Samizdat. We can also display anonymized accounting data publicly.

Fortnox has a restful API with OAuth2 authorization.
API documentation is available at https://developer.fortnox.se/documentation/.

### OAuth Configuration

The redirect_uri must exactly match what's registered in the Fortnox developer portal:
- Development: https://example.com:3443/fortnox/auth
- Production: https://yourdomain.com:443/fortnox/auth (standard HTTPS)

Configure the redirect_uri in samizdat.yml under manager.fortnox.oauth2.redirect_uri
to match your Fortnox app registration.

## RealtimeRegister

The RealtimeRegister model provides integration with the Realtime Register domain registrar API.
It allows managing domain registrations, DNS records, and other domain-related operations
through the Realtime Register service. Certificate management is also supported via integration
with the Realtime Register API.

### API Documentation

API documentation is available at https://dm.realtimeregister.com/docs/api/.
Samizdat uses the RESTful endpoints defined for production and testing environments.

### Authentication

The RealtimeRegister model uses API key authentication.
The API key must be configured in samizdat.yml under manager.realtimeregister.api_key.

## EPP

The EPP (Extensible Provisioning Protocol) model provides domain registration and management using the standard EPP protocol (RFC 5730-5734). It supports domain operations, DNSSEC, contact management, and nameserver configuration.

**Note:** Detailed implementation documentation is in `EPP-PRIVATE.md` (not tracked in git).

## SE Registry API

An API for liisting domains we are managing at the IIS registry, and our invoices. Documentation at

https://api.registry.se/docs/index.html