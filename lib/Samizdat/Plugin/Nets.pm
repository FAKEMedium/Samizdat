package Samizdat::Plugin::Nets;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Nets;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $config = {}) {
  return if (!(exists($app->config->{manager}->{nets}->{env})));
  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Nets} = $openapi_yaml if $openapi_yaml;

  # API routes (webhook, success, cancel, index) defined in OpenAPI spec (__DATA__ section)

  # Manager routes (HTML pages only - API via OpenAPI)
  my $manager = $r->manager('nets')->to(controller => 'Nets');
  $manager->get('/')                          ->to('#payments_index')       ->name('nets_payments_index');


  # Register model helper following the established pattern
  $app->helper(nets => sub ($c) {
    state $model = Samizdat::Model::Nets->new({
      config => $c->settings->resolve('nets'),
      redis  => $c->app->redis,
      pg     => $c->app->pg,
    });
    return $model;
  });


  # Helper to get Nets checkout JavaScript URL
  $app->helper(nets_checkout_js => sub ($c) {
    my $env_config = $c->nets->get_env_config();
    return $env_config->{checkoutjs};
  });

  # Helper to format amount (smallest unit to decimal)
  $app->helper(nets_format_amount => sub ($c, $amount, $currency = 'SEK') {
    return unless defined $amount;

    # SEK/NOK/DKK use øre (100 øre = 1 kr)
    # EUR uses cents (100 cents = 1 euro)
    my $divisor = 100;

    my $formatted = sprintf('%.2f', $amount / $divisor);
    return "$formatted $currency";
  });

  # Helper to convert decimal amount to smallest unit
  $app->helper(nets_to_smallest_unit => sub ($c, $amount, $currency = 'SEK') {
    return unless defined $amount;

    # SEK/NOK/DKK use øre, EUR uses cents
    my $multiplier = 100;

    return int($amount * $multiplier);
  });

}


1;

=head1 NAME

Samizdat::Plugin::Nets - Nets Easy Checkout integration plugin

=head1 SYNOPSIS

  # In your application
  $app->plugin('Nets');

  # Use the model helper
  my $nets = $c->nets;

  # In controller
  my $payment = $c->nets->create_payment(
    amount => 10000,
    currency => 'SEK',
    items => \@items,
    return_url => $url
  );

=head1 DESCRIPTION

This plugin integrates Nets Easy Checkout functionality into Samizdat, including:

=over 4

=item * REST API v1 payment creation and management

=item * Hosted payment page integration

=item * Webhook handling with IP verification

=item * Charge and refund operations

=item * Payment status tracking

=item * Helper for accessing the Nets model

=item * Helpers for amount formatting and conversion

=back

=head1 ROUTES

The plugin registers the following routes:

=head2 Public Routes

=over 4

=item * GET /nets - Payment form page

=item * POST /nets/checkout - Create payment and redirect to checkout

=item * GET /nets/success - Success return URL

=item * GET /nets/cancel - Cancel return URL

=item * POST /nets/webhook - Webhook notification endpoint

=item * GET /nets/payment/:payment_id/status - Get payment status (JSON)

=back

=head2 Manager Routes

=over 4

=item * GET /manager/nets - Nets payments panel

=item * POST /manager/nets/payment/:payment_id/refund - Create refund (JSON)

=back

=head1 HELPERS

=head2 nets

Returns the L<Samizdat::Model::Nets> instance.

  my $nets = $c->nets;
  my $payment = $nets->create_payment(amount => 10000);

=head2 nets_checkout_js

Returns the URL to the Nets checkout JavaScript file for the current environment.

  my $js_url = $c->nets_checkout_js;

=head2 nets_format_amount

Format amount from smallest unit to decimal with currency.

  my $formatted = $c->nets_format_amount(10000, 'SEK');
  # Returns: "100.00 SEK"

=head2 nets_to_smallest_unit

Convert decimal amount to smallest currency unit (øre/cents).

  my $ore = $c->nets_to_smallest_unit(100.50, 'SEK');
  # Returns: 10050

=head1 CONFIGURATION

Configure in samizdat.yml under manager.nets:

  nets:
    currency: SEK
    default_env: test  # or production
    env:
      production:
        api: https://api.dibspayment.eu/
        api_key: your-production-api-key
        checkoutjs: https://checkout.dibspayment.eu/v1/checkout.js?v=1
        webhook:
          origin: 20.103.218.104/30
      test:
        api: https://test.api.dibspayment.eu/
        api_key: your-test-api-key
        checkoutjs: https://test.checkout.dibspayment.eu/v1/checkout.js?v=1
        webhook:
          origin: 20.31.57.60/30

=head1 SEE ALSO

L<Samizdat::Model::Nets>, L<Samizdat::Controller::Nets>

Nets Easy documentation: L<https://developer.nexigroup.com/nexi-checkout/en-EU/docs/>

=cut

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Nets API
paths:
  /nets/checkout:
    post:
      operationId: Nets.checkout
      x-mojo-to: Nets#checkout
      summary: Create payment and get checkout URL
      tags: [Nets]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Nets_CheckoutInput'
      responses:
        '200':
          description: Payment created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Nets_CheckoutResponse'

  /nets/payment/{payment_id}/status:
    get:
      operationId: Nets.payment.status
      x-mojo-to: Nets#status
      summary: Get payment status
      tags: [Nets]
      parameters:
        - name: payment_id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Payment status
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Nets_PaymentStatus'

  /nets/payments:
    get:
      operationId: Nets.payments.index
      x-mojo-to: Nets#payments_index
      summary: List recent payments
      tags: [Nets]
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
            default: 50
        - name: offset
          in: query
          schema:
            type: integer
            default: 0
      responses:
        '200':
          description: List of payments
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Nets_PaymentsResponse'

  /nets/payment/{payment_id}/refund:
    post:
      operationId: Nets.payment.refund
      x-mojo-to: Nets#refund
      summary: Create refund for payment
      tags: [Nets]
      parameters:
        - name: payment_id
          in: path
          required: true
          schema:
            type: string
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Nets_RefundInput'
      responses:
        '200':
          description: Refund created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Nets_RefundResponse'

  /nets/webhook:
    post:
      operationId: Nets.webhook
      x-mojo-to: Nets#webhook
      summary: Nets webhook endpoint
      description: Receives webhook events from Nets Easy Checkout
      tags: [Nets]
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        '200':
          description: Webhook processed
          content:
            text/plain:
              schema:
                type: string

  /nets/success:
    get:
      operationId: Nets.success
      x-mojo-to: Nets#success
      summary: Payment success return URL
      tags: [Nets]
      parameters:
        - name: paymentId
          in: query
          schema:
            type: string
      responses:
        '200':
          description: Payment successful
          content:
            application/json:
              schema:
                type: object
                properties:
                  success:
                    type: boolean

  /nets/cancel:
    get:
      operationId: Nets.cancel
      x-mojo-to: Nets#cancel
      summary: Payment cancel return URL
      tags: [Nets]
      responses:
        '200':
          description: Payment cancelled
          content:
            application/json:
              schema:
                type: object
                properties:
                  cancelled:
                    type: boolean

  /nets:
    get:
      operationId: Nets.index
      x-mojo-to: Nets#index
      summary: Nets payment page
      tags: [Nets]
      responses:
        '200':
          description: Nets payment page
          content:
            application/json:
              schema:
                type: object

components:
  schemas:
    Nets_CheckoutInput:
      type: object
      properties:
        amount:
          type: integer
          description: Amount in smallest currency unit (ore)
        currency:
          type: string
          default: SEK
        reference:
          type: string
        items:
          type: array
          items:
            $ref: '#/components/schemas/Nets_OrderItem'
        return_url:
          type: string
        custom_data:
          type: object
      required:
        - amount
        - items
    Nets_OrderItem:
      type: object
      properties:
        reference:
          type: string
        name:
          type: string
        quantity:
          type: integer
        unit:
          type: string
        unitPrice:
          type: integer
        taxRate:
          type: integer
        taxAmount:
          type: integer
        grossTotalAmount:
          type: integer
        netTotalAmount:
          type: integer
    Nets_CheckoutResponse:
      type: object
      properties:
        success:
          type: boolean
        payment_id:
          type: string
        checkout_url:
          type: string
    Nets_PaymentStatus:
      type: object
      properties:
        success:
          type: boolean
        payment_id:
          type: string
        status:
          type: string
        amount:
          type: integer
        currency:
          type: string
        reference:
          type: string
        charged_amount:
          type: integer
        refunded_amount:
          type: integer
    Nets_RefundInput:
      type: object
      properties:
        amount:
          type: integer
          description: Refund amount in smallest currency unit
        reason:
          type: string
      required:
        - amount
    Nets_RefundResponse:
      type: object
      properties:
        success:
          type: boolean
        refund_id:
          type: string
        amount:
          type: integer
        payment_id:
          type: string
    Nets_PaymentsResponse:
      type: object
      properties:
        success:
          type: boolean
        payments:
          type: array
          items:
            $ref: '#/components/schemas/Nets_PaymentStatus'
        statistics:
          type: object
