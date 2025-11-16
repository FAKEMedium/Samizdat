package Samizdat::Plugin::Nets;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Nets;

sub register ($self, $app, $config = {}) {

  my $r = $app->routes;

  # Public routes
  my $nets = $r->home('/nets')->to(controller => 'Nets');
  $nets->post('/checkout')                    ->to('#checkout')             ->name('nets_checkout');
  $nets->get('/success')                      ->to('#success')              ->name('nets_success');
  $nets->get('/cancel')                       ->to('#cancel')               ->name('nets_cancel');
  $nets->post('/webhook')                     ->to('#webhook')              ->name('nets_webhook');
  $nets->get('/payment/:payment_id/status')   ->to('#status')               ->name('nets_status');
  $nets->get('/')                             ->to('#index')                ->name('nets_index');

  # Manager routes
  my $manager = $r->manager('nets')->to(controller => 'Nets');
  $manager->post('/payment/:payment_id/refund')->to('#refund')              ->name('nets_refund');
  $manager->get('/')                          ->to('#list_payments')        ->name('nets_manager_index');


  # Register model helper following the established pattern
  $app->helper(nets => sub ($c) {
    state $model = Samizdat::Model::Nets->new({
      config => $c->config->{manager}->{nets},
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
