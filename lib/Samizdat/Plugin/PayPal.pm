 package Samizdat::Plugin::PayPal;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::PayPal;

sub register ($self, $app, $config = {}) {

  my $r = $app->routes;

  # Public routes
  my $paypal = $r->home('/paypal')->to(controller => 'PayPal');
  $paypal->post('/ipn')                   ->to('#ipn')                  ->name('paypal_ipn');
  $paypal->get('/success')                ->to('#success')              ->name('paypal_success');
  $paypal->get('/cancel')                 ->to('#cancel')               ->name('paypal_cancel');

  # REST API routes
  $paypal->get('/config')                 ->to('#paypal_config')        ->name('paypal_config');
  $paypal->post('/orders/create')         ->to('#create_order')         ->name('paypal_create_order');
  $paypal->post('/orders/:id/capture')    ->to('#capture_order')        ->name('paypal_capture_order');

  # Manager routes
  my $manager = $r->manager('paypal')->to(controller => 'PayPal');
  $manager->get('/')                      ->to('#index')                ->name('paypal_index');


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
