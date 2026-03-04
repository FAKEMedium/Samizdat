package Samizdat::Plugin::Stripe;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Stripe;
use Mojo::Loader qw(data_section);

sub register ($self, $app, $config = {}) {
  return if (!(exists($app->config->{manager}->{stripe})));

  my $r = $app->routes;

  # Store OpenAPI fragment (parsed centrally in _load_openapi)
  my $openapi_yaml = data_section(__PACKAGE__, 'openapi.yaml');
  $app->config->{openapi_fragments}{Stripe} = $openapi_yaml if $openapi_yaml;

  # API routes (webhook, success, cancel) defined in OpenAPI spec (__DATA__ section)

  # Manager routes (HTML page only - API via OpenAPI)
  my $manager = $r->manager('stripe')->to(controller => 'Stripe');
  $manager->get('/')                      ->to('#index')                 ->name('stripe_index');


  # Register model helper
  $app->helper(stripe => sub ($c) {
    state $model;
    return $model if $model;

    eval {
      $model = Samizdat::Model::Stripe->new(
        config => $c->app->config->{manager}->{stripe},
        redis  => $c->app->redis,
        pg     => $c->app->pg,
      );
    };
    if ($@) {
      $c->app->log->error("Failed to create Stripe model: $@");
    }
    return $model;
  });


  # Register stripebutton helper for generating payment button container
  $app->helper(stripebutton => sub ($c, %params) {
    return $c->render_to_string(
      template => 'stripe/chunks/stripebutton',
      format => 'html',
      params => \%params
    );
  });

  # Register helper for Stripe button JavaScript
  $app->helper(stripebutton_script => sub ($c) {
    return $c->render_to_string(
      template => 'stripe/chunks/stripebutton',
      format => 'js'
    );
  });

}


1;

=head1 NAME

Samizdat::Plugin::Stripe - Stripe payment integration plugin

=head1 SYNOPSIS

  # In your application
  $app->plugin('Stripe');

  # Use the model helper
  my $stripe = $c->stripe;

  # In a template - generate payment button container
  <%== stripebutton %>

  # In page JavaScript - initialize Stripe button
  <% $web->{script} = stripebutton_script(); %>

  # Or use REST API directly
  my $intent = $c->stripe->create_payment_intent(
    amount => 10000,
    currency => 'SEK',
  );

=head1 DESCRIPTION

This plugin integrates Stripe payment functionality into Samizdat, including:

=over 4

=item * Embedded Payment Element components

=item * Checkout Session redirect flow

=item * Webhook handling for payment status updates

=item * Refund support

=item * Helper for accessing the Stripe model

=item * Helpers for generating payment button HTML and JavaScript

=back

=head1 ROUTES

The plugin registers the following routes:

=head2 Public Routes

=over 4

=item * POST /stripe/webhook - Webhook endpoint for Stripe events

=item * GET /stripe/success - Success return URL

=item * GET /stripe/cancel - Cancel return URL

=item * GET /stripe/config - Get client configuration (JSON)

=item * POST /stripe/payment-intents - Create PaymentIntent (JSON)

=item * POST /stripe/checkout-sessions - Create Checkout Session (JSON)

=item * GET /stripe/payments/:id - Get payment status (JSON)

=item * POST /stripe/refunds - Create refund (JSON)

=back

=head2 Manager Routes

=over 4

=item * GET /manager/stripe - Stripe payments panel

=back

=head1 HELPERS

=head2 stripe

Returns the L<Samizdat::Model::Stripe> instance.

  my $stripe = $c->stripe;
  my $intent = $stripe->create_payment_intent(amount => 10000);

=head2 stripebutton

Generates an HTML container for the Stripe payment button.

  my $button_html = $c->stripebutton(
    amount => 10000,
    description => 'Order #123',
  );

=head2 stripebutton_script

Returns JavaScript code for initializing the Stripe payment button.

  $web->{script} = $c->stripebutton_script();

=head1 CONFIGURATION

Configure in samizdat.yml under manager.stripe:

  stripe:
    cardnumber: 19
    dbtype: postgresql
    currency: SEK
    default_env: test
    webhook_secret: whsec_xxx
    env:
      test:
        publishable_key: pk_test_xxx
        secret_key: sk_test_xxx
      production:
        publishable_key: pk_live_xxx
        secret_key: sk_live_xxx

=head1 PAYMENT FLOWS

=head2 Embedded Payment Element

1. POST to /stripe/payment-intents to create PaymentIntent
2. Response includes client_secret
3. Initialize Stripe.js with publishable_key from /stripe/config
4. Mount Payment Element in your form
5. User fills payment details and submits
6. Stripe.js confirms payment
7. Webhook receives payment_intent.succeeded
8. Redirect to success page

=head2 Checkout Session (Redirect)

1. POST to /stripe/checkout-sessions
2. Response includes session URL
3. Redirect customer to Stripe-hosted checkout
4. Customer completes payment
5. Webhook receives checkout.session.completed
6. Stripe redirects to success_url

=head1 WEBHOOK SETUP

1. Go to Stripe Dashboard > Developers > Webhooks
2. Add endpoint: https://yoursite.com/stripe/webhook
3. Select events: payment_intent.succeeded, payment_intent.payment_failed,
   checkout.session.completed
4. Copy the webhook signing secret to config

=head1 SEE ALSO

L<Samizdat::Model::Stripe>, L<Samizdat::Controller::Stripe>

Stripe Documentation: L<https://docs.stripe.com>

=cut

__DATA__

@@ openapi.yaml
# OpenAPI 3.0 fragment for Stripe API
paths:
  /stripe/config:
    get:
      operationId: Stripe.config
      x-mojo-to: Stripe#stripe_config
      summary: Get Stripe client configuration
      tags: [Stripe]
      responses:
        '200':
          description: Stripe configuration
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Stripe_ConfigResponse'

  /stripe/payment-intents:
    post:
      operationId: Stripe.paymentIntents.create
      x-mojo-to: Stripe#create_payment_intent
      summary: Create PaymentIntent
      tags: [Stripe]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Stripe_PaymentIntentInput'
      responses:
        '200':
          description: PaymentIntent created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Stripe_PaymentIntentResponse'

  /stripe/checkout-sessions:
    post:
      operationId: Stripe.checkoutSessions.create
      x-mojo-to: Stripe#create_checkout_session
      summary: Create Checkout Session
      tags: [Stripe]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Stripe_CheckoutSessionInput'
      responses:
        '200':
          description: Checkout session created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Stripe_CheckoutSessionResponse'

  /stripe/payments/{id}:
    get:
      operationId: Stripe.payments.get
      x-mojo-to: Stripe#get_payment
      summary: Get payment status
      tags: [Stripe]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Payment details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Stripe_Payment'

  /stripe/refunds:
    post:
      operationId: Stripe.refunds.create
      x-mojo-to: Stripe#create_refund
      summary: Create refund
      tags: [Stripe]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Stripe_RefundInput'
      responses:
        '200':
          description: Refund created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Stripe_RefundResponse'

  /stripe/payments:
    get:
      operationId: Stripe.payments.list
      x-mojo-to: Stripe#index
      summary: List recent payments
      tags: [Stripe]
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
            default: 50
      responses:
        '200':
          description: List of payments
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Stripe_PaymentsResponse'

  /stripe/webhook:
    post:
      operationId: Stripe.webhook
      x-mojo-to: Stripe#webhook
      summary: Stripe webhook endpoint
      description: Receives webhook events from Stripe
      tags: [Stripe]
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

  /stripe/success:
    get:
      operationId: Stripe.success
      x-mojo-to: Stripe#success
      summary: Payment success return URL
      tags: [Stripe]
      parameters:
        - name: session_id
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

  /stripe/cancel:
    get:
      operationId: Stripe.cancel
      x-mojo-to: Stripe#cancel
      summary: Payment cancel return URL
      tags: [Stripe]
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

components:
  schemas:
    Stripe_ConfigResponse:
      type: object
      properties:
        publishable_key:
          type: string
        currency:
          type: string
        env:
          type: string
    Stripe_PaymentIntentInput:
      type: object
      properties:
        amount:
          type: integer
          description: Amount in smallest currency unit
        currency:
          type: string
          default: SEK
        description:
          type: string
        customer_email:
          type: string
        metadata:
          type: object
      required:
        - amount
    Stripe_PaymentIntentResponse:
      type: object
      properties:
        success:
          type: boolean
        payment_intent_id:
          type: string
        client_secret:
          type: string
        error:
          type: boolean
        error_message:
          type: string
    Stripe_CheckoutSessionInput:
      type: object
      properties:
        amount:
          type: integer
        currency:
          type: string
        description:
          type: string
        customer_email:
          type: string
        success_url:
          type: string
        cancel_url:
          type: string
        metadata:
          type: object
      required:
        - amount
    Stripe_CheckoutSessionResponse:
      type: object
      properties:
        success:
          type: boolean
        session_id:
          type: string
        url:
          type: string
        error:
          type: boolean
        error_message:
          type: string
    Stripe_Payment:
      type: object
      properties:
        payment_intent_id:
          type: string
        checkout_session_id:
          type: string
        status:
          type: string
        amount:
          type: integer
        currency:
          type: string
        description:
          type: string
        customer_email:
          type: string
        payment_method_type:
          type: string
        created_at:
          type: string
    Stripe_RefundInput:
      type: object
      properties:
        payment_intent_id:
          type: string
        amount:
          type: integer
        reason:
          type: string
      required:
        - payment_intent_id
    Stripe_RefundResponse:
      type: object
      properties:
        success:
          type: boolean
        refund_id:
          type: string
        amount:
          type: integer
        status:
          type: string
        error:
          type: boolean
        error_message:
          type: string
    Stripe_Stats:
      type: object
      properties:
        balance:
          type: number
        total_succeeded:
          type: number
        count_succeeded:
          type: integer
        total_pending:
          type: number
        count_pending:
          type: integer
        total_failed:
          type: number
        count_failed:
          type: integer
        total_refunded:
          type: number
        count_refunded:
          type: integer
    Stripe_PaymentsResponse:
      type: object
      properties:
        success:
          type: boolean
        payments:
          type: array
          items:
            $ref: '#/components/schemas/Stripe_Payment'
        stats:
          $ref: '#/components/schemas/Stripe_Stats'
