# Samizdat models

## SMS

We use a Teltonika device (RUTXR1) to send and receive SMS messages. We also use sms to http
gateway forwarding messages. SMS functions include a form and controller for sending messages,
as well as automated outgoing message for stuff like account verification codes.

Teltonika documentation: https://developers.rms.teltonika-networks.com/

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


## PayPal

The PayPal model provides integration with PayPal's payment processing system using the modern **REST API v2** with OAuth 2.0 authentication. It supports payment buttons with the JavaScript SDK and server-side order management.

### Features

- OAuth 2.0 client credentials authentication
- REST API v2 order creation and capture
- JavaScript SDK payment button integration
- Transaction logging and audit trail
- Support for sandbox and production environments
- Configurable currency and environment settings
- Manager panel for viewing payment history and statistics
- Balance tracking with completed/pending/refunded amounts
- Legacy IPN support (for backward compatibility)

### Configuration

Configure PayPal in samizdat.yml under `manager.paypal` using environment-based structure:

```yaml
paypal:
  cardnumber: 16
  dbtype: postgresql
  currency: USD                             # Default currency code (USD, EUR, SEK, etc)
  default_env: sandbox                      # sandbox or production
  oauth2:
    # OAuth2 client credentials flow (not authorization code flow)
    # Uses different credentials per environment (sandbox/production)
    token_url_template: '{api}/v1/oauth2/token'  # Template using {api} placeholder
    # client_id and secret are environment-specific (see env section below)
  env:
    sandbox:
      api: https://api-m.sandbox.paypal.com
      client_id: your-sandbox-client-id
      secret: your-sandbox-secret
    production:
      api: https://api-m.paypal.com
      client_id: your-production-client-id
      secret: your-production-secret
```

**Note:** PayPal uses OAuth 2.0 client credentials flow (machine-to-machine), not authorization
code flow (user authorization). The oauth2 section is for consistency with other OAuth2-enabled
modules and will be auto-registered by Samizdat.pm, though PayPal handles token management
internally via the model.

### Getting PayPal Credentials

1. Go to https://developer.paypal.com/dashboard/
2. Create a new app or select an existing app
3. Copy the Client ID and Secret for your environment (sandbox or live)
4. Add the credentials to your `samizdat.yml` configuration

### Usage

#### In Templates (with JavaScript SDK)

```html
<!-- Include the PayPal button container -->
<%== paypalbutton %>

<!-- Include the JavaScript in your page script -->
<% $web->{script} = paypalbutton_script(); %>
```

#### In Perl Code (REST API)

```perl
# Create an order
my $order = $c->paypal->create_order(
  amount => 99.00,
  currency => 'USD',
  description => 'Premium Membership',
  return_url => 'https://example.com/paypal/success',
  cancel_url => 'https://example.com/paypal/cancel',
);

# Capture an order after approval
my $result = $c->paypal->capture_order($order_id);

# Get order details
my $order_details = $c->paypal->get_order($order_id);
```

### REST API Endpoints

The plugin provides the following JSON endpoints:

- `GET /paypal/config` - Get client configuration (client_id, currency, env)
- `POST /paypal/orders/create` - Create a new payment order
- `POST /paypal/orders/:id/capture` - Capture an approved order
- `GET /paypal/success` - Success return URL
- `GET /paypal/cancel` - Cancel return URL

### Database Schema

The model requires a `paypal_ipn_log` table for transaction logging:

```sql
CREATE TABLE paypal_ipn_log (
  id SERIAL PRIMARY KEY,
  txn_id VARCHAR(255) UNIQUE,
  txn_type VARCHAR(100),
  payment_status VARCHAR(50),
  payer_email VARCHAR(255),
  receiver_email VARCHAR(255),
  amount DECIMAL(10,2),
  currency VARCHAR(10),
  item_number VARCHAR(255),
  custom TEXT,
  raw_data JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_paypal_txn_id ON paypal_ipn_log(txn_id);
CREATE INDEX idx_paypal_status ON paypal_ipn_log(payment_status);
CREATE INDEX idx_paypal_created ON paypal_ipn_log(created_at);
```

### API Documentation

- PayPal REST API: https://developer.paypal.com/api/rest/
- PayPal Orders API v2: https://developer.paypal.com/docs/api/orders/v2/
- PayPal JavaScript SDK: https://developer.paypal.com/sdk/js/
- PayPal OAuth 2.0: https://developer.paypal.com/api/rest/authentication/


## SWISH

SWISH is a Swedish service for mobile payments.

Documentation at https://developer.swish.nu/


## BIS (Based in Sweden)

Based in Sweden (https://basedinsweden.se/) is an initiative to highlight the consequences of having data under foreign
legislation. Its main concern is the Cloud Act, meaning US intelligence can access data in US-owned clouds, even if the
servers are located in Sweden.

The Samizdat BIS module tracks Swedish organizations' hosting compliance to promote data sovereignty and Swedish hosting.

### Features

- **DNS record checking**: A, AAAA, MX, and NS records
- **IP geolocation**: Country-level geolocation for all IPs
- **ASN lookup**: Identifies hosting providers via Autonomous System information
- **Provider database**: Maintains database of Swedish vs foreign providers
- **Compliance scoring**: 0-100% scores with BIS badge for 100% compliant
- **Sector analysis**: Statistics broken down by healthcare, government, education, etc.
- **Cloud Act tracking**: Identifies domains under US Cloud Act jurisdiction
- **Historical trends**: Track improvements/regressions over time
- **Public dashboard**: Name-and-shame/hall-of-fame approach to create pressure
- **Caching**: Redis caching of IP lookups to avoid redundant API calls

### Compliance Criteria

To qualify for the BIS badge (100% score), ALL infrastructure must be Swedish:

* All A/AAAA records resolve to Swedish IPs
* All MX mail servers in Swedish datacenters
* All NS nameservers in Swedish datacenters
* Hosted by Swedish companies or on Swedish infrastructure

### Configuration

Configure in samizdat.yml under `manager.bis`:

### Database Setup

Run the schema creation:

```bash
psql -U samizdat samizdat < schema/bis.sql
```

This creates:
- Domain tracking tables with tagging
- Check run tables for periodic audits
- DNS check results with geolocation
- Compliance scores and statistics
- Provider identification database
- Historical trend data

### Usage

#### Add Domains to Track

```perl
# In application code
my $domain_id = $c->bis->add_domain(
  domain => 'regeringen.se',
  title => 'Swedish Government',
  description => 'Main government website',
  tags => ['government']
);
```

Or via the manager interface at `/manager/bis/domains`.

#### Run Compliance Checks

```bash
# From command line (run via cron every 6 hours)
./samizdat bischeck

# Or manually via manager interface
curl -X POST http://localhost:3000/manager/bis/runs/start
curl -X POST http://localhost:3000/manager/bis/runs/1/check
```

#### View Results

- Public dashboard: `/bis`
- By sector: `/bis/sector/healthcare`
- By domain: `/bis/domain/example.se`
- Provider stats: `/bis/providers`
- Historical trends: `/bis/trends`
- Manager panel: `/manager/bis`

### Provider Identification

The system identifies hosting providers by matching:

1. ASN (Autonomous System Number)
2. AS Name patterns (e.g., "BAHNHOF", "AMAZON-AES")
3. IP ranges (CIDR blocks)

### Scoring System

- **100%**: All records Swedish → **BIS BADGE** ✓
- **75-99%**: Mostly Swedish (some foreign records)
- **50-74%**: Mixed Swedish/foreign
- **25-49%**: Mostly foreign
- **0-24%**: Almost all foreign (high risk)

### API Endpoints

All endpoints support JSON responses with `Accept: application/json` header:

**Public:**
- `GET /bis` - Dashboard with all domains
- `GET /bis/domain/:domain` - Specific domain details
- `GET /bis/sector/:sector` - Filter by sector
- `GET /bis/providers` - Provider statistics
- `GET /bis/trends?days=90` - Historical trends

**Manager:**
- `GET /manager/bis/domains` - List domains
- `POST /manager/bis/domains` - Add domain
- `PUT /manager/bis/domains/:id` - Update domain
- `DELETE /manager/bis/domains/:id` - Delete domain
- `GET /manager/bis/tags` - List tags
- `POST /manager/bis/tags` - Add tag
- `GET /manager/bis/runs` - List check runs
- `POST /manager/bis/runs/start` - Start new run
- `POST /manager/bis/runs/:id/check` - Check all domains
- `GET /manager/bis/providers` - Manage providers
- `POST /manager/bis/providers` - Add provider

### Cron Job Setup

Add to crontab to run every 6 hours:

```bash
0 */6 * * * cd /path/to/samizdat && ./samizdat bischeck >> /var/log/bis-check.log 2>&1
```

### External API Usage

The system uses ip-api.com (free tier: 45 requests/minute) for IP geolocation and ASN data.
Rate limiting is built-in (1.5s between requests) to stay within free tier limits.

For production use with many domains, consider:
- IP-API.com pro subscription (higher rate limits)
- Self-hosted MaxMind GeoIP2 database
- Caching IP results in Redis (already implemented)

### Future Enhancements

Potential additions:
- SSL certificate authority tracking (Swedish vs foreign CAs)
- Third-party service detection (Google Analytics, Facebook Pixel)
- CDN usage analysis
- Estimated hosting costs and Swedish alternatives
- Automated reporting to media/politicians
- Integration with GDPR compliance tracking

### Documentation

- Based in Sweden: https://basedinsweden.se/
- Cloud Act info: https://en.wikipedia.org/wiki/CLOUD_Act
- IP-API documentation: https://ip-api.com/docs/


## Nets

Integrate payments with Nets. We wish to custmoize and keep on-site as much as possible.
A customer is supposed to order a service, pay for it, and the service will be performed when our webhook
is called. Some services though, might be scheduled many days later, and often not performed at all.
If possible, don't let our users fetch script from dibspayment.

- Documentation: https://developer.nexigroup.com/nexi-checkout/en-EU/docs/
- API Reference: https://developer.nexigroup.com/nexi-checkout/en-EU/api/