package Samizdat::Plugin::PayPal;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::PayPal;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $config = {}) {

  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{PayPal} = $openapi_yaml if $openapi_yaml;

  # API routes (ipn, success, cancel) defined in OpenAPI spec (__DATA__ section)

  # Manager routes
  my $manager = $r->manager('paypal')->to(controller => 'PayPal');
  $manager->get('/')                      ->to('#index')                ->name('paypal_index');
  $manager->get('/transactions')          ->to('#transactions')         ->name('paypal_transactions');


  # Register model helper following the established pattern
  $app->helper(paypal => sub ($c) {
    state $model;
    return $model if $model;

    eval {
      $model = Samizdat::Model::PayPal->new(
        config => $c->app->config->{manager}->{paypal},
        redis  => $c->app->redis,
        pg     => $c->app->pg,
      );
    };
    if ($@) {
      $c->app->log->error("Failed to create PayPal model: $@");
    }
    return $model;
  });


  # Register paypalbutton helper for generating payment button container
  $app->helper(paypalbutton => sub ($c, %params) {
    # Return HTML container for the PayPal button (data fetched via JavaScript)
    return $c->render_to_string(
      template => 'paypal/chunks/paypalbutton',
      format => 'html'
    );
  });

  # Register helper for PayPal button JavaScript
  $app->helper(paypalbutton_script => sub ($c) {
    # Return JavaScript for PayPal button initialization
    return $c->render_to_string(
      template => 'paypal/chunks/paypalbutton',
      format => 'js'
    );
  });

}


1;

=head1 NAME

Samizdat::Plugin::PayPal - PayPal REST API v2 integration plugin

=head1 SYNOPSIS

  # In your application
  $app->plugin('PayPal');

  # Use the model helper
  my $paypal = $c->paypal;

  # In a template - generate payment button container
  <%== paypalbutton %>

  # In page JavaScript - initialize PayPal SDK
  <% $web->{script} = paypalbutton_script(); %>

  # Or use REST API directly in Perl
  my $order = $c->paypal->create_order(
    amount => 99.00,
    currency => 'USD',
    description => 'Premium Membership',
  );

=head1 DESCRIPTION

This plugin integrates PayPal REST API v2 functionality into Samizdat, including:

=over 4

=item * OAuth 2.0 client credentials authentication

=item * REST API v2 order creation and capture

=item * JavaScript SDK payment button integration

=item * Success and cancel return URLs

=item * Helper for accessing the PayPal model

=item * Helpers for generating payment button HTML and JavaScript

=item * Legacy IPN support for backward compatibility

=back

=head1 ROUTES

The plugin registers the following routes:

=head2 Public Routes

=over 4

=item * POST /paypal/ipn - IPN notification endpoint (legacy)

=item * GET /paypal/success - Success return URL

=item * GET /paypal/cancel - Cancel return URL

=item * GET /paypal/config - Get client configuration (JSON)

=item * POST /paypal/orders/create - Create payment order (JSON)

=item * POST /paypal/orders/:id/capture - Capture order (JSON)

=back

=head2 Manager Routes

=over 4

=item * GET /manager/paypal - PayPal payments panel

=item * GET /manager/paypal/transactions - Fetch live transactions from PayPal

=back

=head1 HELPERS

=head2 paypal

Returns the L<Samizdat::Model::PayPal> instance.

  my $paypal = $c->paypal;
  my $order = $paypal->create_order(amount => 99.00);

=head2 paypalbutton

Generates an HTML container for the PayPal payment button.
The actual button is initialized via JavaScript using the PayPal SDK.

  my $button_html = $c->paypalbutton();

Returns a div container that will be populated by the JavaScript SDK.

=head2 paypalbutton_script

Returns JavaScript code for initializing the PayPal SDK button.
This should be included in the page's script section.

  $web->{script} = $c->paypalbutton_script();

The JavaScript fetches configuration from /paypal/config and initializes
the PayPal SDK with proper order creation and capture handlers.

=head1 CONFIGURATION

Configure in samizdat.yml under manager.paypal:

  paypal:
    cardnumber: 16
    dbtype: postgresql
    currency: USD
    default_env: sandbox  # or production
    oauth2:
      # OAuth2 client credentials flow
      token_url_template: '{api}/v1/oauth2/token'
    env:
      sandbox:
        api: https://api-m.sandbox.paypal.com
        client_id: your-sandbox-client-id
        secret: your-sandbox-secret
      production:
        api: https://api-m.paypal.com
        client_id: your-production-client-id
        secret: your-production-secret

The oauth2 section enables automatic provider registration by Samizdat.pm
for consistency with other OAuth2-enabled modules (SMS, Fortnox).
PayPal uses client credentials flow (machine-to-machine), not authorization
code flow (user authorization).

=head1 SEE ALSO

L<Samizdat::Model::PayPal>, L<Samizdat::Controller::PayPal>

PayPal REST API documentation: L<https://developer.paypal.com/api/rest/>

=cut

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for PayPal API
paths:
  /paypal:
    get:
      operationId: PayPal.index
      x-mojo-to: PayPal#index
      summary: PayPal payments panel
      tags: [PayPal]
      responses:
        '200':
          description: Payment statistics and recent payments
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PayPal_IndexResponse'

  /paypal/config:
    get:
      operationId: PayPal.config
      x-mojo-to: PayPal#paypal_config
      summary: Get PayPal client configuration
      tags: [PayPal]
      responses:
        '200':
          description: PayPal SDK configuration
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PayPal_ConfigResponse'

  /paypal/orders/create:
    post:
      operationId: PayPal.orders.create
      x-mojo-to: PayPal#create_order
      summary: Create payment order
      tags: [PayPal]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/PayPal_OrderInput'
      responses:
        '200':
          description: Order created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PayPal_Order'

  /paypal/orders/{id}/capture:
    post:
      operationId: PayPal.orders.capture
      x-mojo-to: PayPal#capture_order
      summary: Capture payment order
      tags: [PayPal]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Order captured
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PayPal_CaptureResponse'

  /paypal/success:
    get:
      operationId: PayPal.success
      x-mojo-to: PayPal#success
      summary: Payment success return URL
      tags: [PayPal]
      parameters:
        - name: tx
          in: query
          schema:
            type: string
        - name: item_number
          in: query
          schema:
            type: string
        - name: amt
          in: query
          schema:
            type: string
      responses:
        '200':
          description: Payment successful
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PayPal_SuccessResponse'

  /paypal/cancel:
    get:
      operationId: PayPal.cancel
      x-mojo-to: PayPal#cancel
      summary: Payment cancel return URL
      tags: [PayPal]
      responses:
        '200':
          description: Payment cancelled
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PayPal_CancelResponse'

  /paypal/ipn:
    post:
      operationId: PayPal.ipn
      x-mojo-to: PayPal#ipn
      summary: IPN notification endpoint (legacy)
      tags: [PayPal]
      requestBody:
        content:
          application/x-www-form-urlencoded:
            schema:
              type: object
      responses:
        '200':
          description: IPN processed
          content:
            text/plain:
              schema:
                type: string

  /paypal/transactions:
    get:
      operationId: PayPal.transactions
      x-mojo-to: PayPal#transactions
      summary: Fetch live transactions from PayPal Transaction Search API
      tags: [PayPal]
      parameters:
        - name: start_date
          in: query
          description: Start date in ISO 8601 format (e.g., 2024-01-01T00:00:00Z)
          schema:
            type: string
        - name: end_date
          in: query
          description: End date in ISO 8601 format (e.g., 2024-12-31T23:59:59Z)
          schema:
            type: string
      responses:
        '200':
          description: Transaction list from PayPal
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PayPal_TransactionsResponse'

components:
  schemas:
    PayPal_ConfigResponse:
      type: object
      properties:
        client_id:
          type: string
        currency:
          type: string
        env:
          type: string
    PayPal_OrderInput:
      type: object
      properties:
        amount:
          type: number
        currency:
          type: string
        description:
          type: string
      required:
        - amount
    PayPal_Order:
      type: object
      properties:
        id:
          type: string
        status:
          type: string
        links:
          type: array
          items:
            type: object
    PayPal_CaptureResponse:
      type: object
      properties:
        id:
          type: string
        status:
          type: string
        purchase_units:
          type: array
          items:
            type: object
        payer:
          type: object
    PayPal_SuccessResponse:
      type: object
      properties:
        success:
          type: boolean
        txn_id:
          type: string
        item_number:
          type: string
        amount:
          type: string
    PayPal_CancelResponse:
      type: object
      properties:
        cancelled:
          type: boolean
    PayPal_Payment:
      type: object
      properties:
        txn_id:
          type: string
        payment_status:
          type: string
        payer_email:
          type: string
        amount:
          type: number
        currency:
          type: string
        item_number:
          type: string
        created_at:
          type: string
    PayPal_Stats:
      type: object
      properties:
        balance:
          type: number
        total_completed:
          type: number
        count_completed:
          type: integer
        total_pending:
          type: number
        count_pending:
          type: integer
        total_refunded:
          type: number
        count_refunded:
          type: integer
        count_failed:
          type: integer
    PayPal_IndexResponse:
      type: object
      properties:
        success:
          type: boolean
        payments:
          type: array
          items:
            $ref: '#/components/schemas/PayPal_Payment'
        stats:
          $ref: '#/components/schemas/PayPal_Stats'
    PayPal_TransactionsResponse:
      type: object
      properties:
        success:
          type: boolean
        transactions:
          type: array
          items:
            $ref: '#/components/schemas/PayPal_Transaction'
        total_items:
          type: integer
        total_pages:
          type: integer
        error:
          type: string
    PayPal_Transaction:
      type: object
      properties:
        transaction_id:
          type: string
        transaction_status:
          type: string
        transaction_subject:
          type: string
        transaction_amount:
          type: object
          properties:
            value:
              type: string
            currency_code:
              type: string
        transaction_updated_date:
          type: string
        payer_info:
          type: object
