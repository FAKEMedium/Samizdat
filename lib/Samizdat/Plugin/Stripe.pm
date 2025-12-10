package Samizdat::Plugin::Stripe;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Stripe;

sub register ($self, $app, $config = {}) {

  my $r = $app->routes;

  # Public routes
  my $stripe = $r->home('/stripe')->to(controller => 'Stripe');
  $stripe->post('/webhook')               ->to('#webhook')               ->name('stripe_webhook');
  $stripe->get('/success')                ->to('#success')               ->name('stripe_success');
  $stripe->get('/cancel')                 ->to('#cancel')                ->name('stripe_cancel');

  # REST API routes
  $stripe->get('/config')                 ->to('#stripe_config')         ->name('stripe_config');
  $stripe->post('/payment-intents')       ->to('#create_payment_intent') ->name('stripe_create_intent');
  $stripe->post('/checkout-sessions')     ->to('#create_checkout_session')->name('stripe_create_session');
  $stripe->get('/payments/:id')           ->to('#get_payment')           ->name('stripe_get_payment');
  $stripe->post('/refunds')               ->to('#create_refund')         ->name('stripe_create_refund');

  # Manager routes
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
