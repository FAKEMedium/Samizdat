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

For API mode, you need to configure:
- `client_id`: OAuth client ID from Teltonika device
- `client_secret`: OAuth client secret from Teltonika device
- `modem`: Modem identifier (e.g., '3-1')

The model automatically handles OAuth token acquisition and caching for API requests.