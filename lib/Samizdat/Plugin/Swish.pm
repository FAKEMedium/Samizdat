package Samizdat::Plugin::Swish;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Swish;

sub register ($self, $app, $config = {}) {

  my $r = $app->routes;

  # Public routes
  my $swish = $r->home('/swish')->to(controller => 'Swish');
  $swish->post('/callback')             ->to('#callback')             ->name('swish_callback');
  $swish->get('/success')               ->to('#success')              ->name('swish_success');
  $swish->get('/cancel')                ->to('#cancel')               ->name('swish_cancel');

  # REST API routes
  $swish->get('/config')                ->to('#swish_config')         ->name('swish_config');
  $swish->post('/payments/create')      ->to('#create_payment')       ->name('swish_create_payment');
  $swish->get('/payments/:id')          ->to('#get_payment')          ->name('swish_get_payment');
  $swish->post('/refunds/create')       ->to('#create_refund')        ->name('swish_create_refund');

  # Manager routes
  my $manager = $r->manager('swish')->to(controller => 'Swish');
  $manager->get('/')                    ->to('#index')                ->name('swish_index');


  # Register model helper following the established pattern
  $app->helper(swish => sub ($c) {
    state $model;
    return $model if $model;

    eval {
      $model = Samizdat::Model::Swish->new(
        config => $c->app->config->{manager}->{swish},
        redis  => $c->app->redis,
        pg     => $c->app->pg,
      );
    };
    if ($@) {
      $c->app->log->error("Failed to create Swish model: $@");
    }
    return $model;
  });


  # Register swishbutton helper for generating payment button
  $app->helper(swishbutton => sub ($c, %params) {
    return $c->render_to_string(
      template => 'swish/chunks/swishbutton',
      format => 'html',
      params => \%params
    );
  });

  # Register helper for Swish button JavaScript
  $app->helper(swishbutton_script => sub ($c) {
    return $c->render_to_string(
      template => 'swish/chunks/swishbutton',
      format => 'js'
    );
  });

  # Register helper for QR code generation
  $app->helper(swish_qr_url => sub ($c, $token) {
    # Generate QR code URL using Swish app scheme
    return "swish://paymentrequest?token=$token";
  });

}


1;

=head1 NAME

Samizdat::Plugin::Swish - Swish mobile payment integration plugin

=head1 SYNOPSIS

  # In your application
  $app->plugin('Swish');

  # Use the model helper
  my $swish = $c->swish;

  # In a template - generate payment button container
  <%== swishbutton %>

  # In page JavaScript - initialize Swish button
  <% $web->{script} = swishbutton_script(); %>

  # Or use REST API directly in Perl
  my $payment = $c->swish->create_payment(
    amount => 10000,
    payer_alias => '46701234567',
    message => 'Order #123',
    callback_url => $c->url_for('swish_callback')->to_abs,
  );

=head1 DESCRIPTION

This plugin integrates Swish mobile payment functionality into Samizdat, including:

=over 4

=item * mTLS certificate authentication

=item * E-commerce flow (phone number push notification)

=item * M-commerce flow (QR code / app link)

=item * Callback handling for payment status updates

=item * Refund support

=item * Helper for accessing the Swish model

=item * Helpers for generating payment button HTML and JavaScript

=back

=head1 ROUTES

The plugin registers the following routes:

=head2 Public Routes

=over 4

=item * POST /swish/callback - Callback endpoint for Swish notifications

=item * GET /swish/success - Success return URL

=item * GET /swish/cancel - Cancel return URL

=item * GET /swish/config - Get client configuration (JSON)

=item * POST /swish/payments/create - Create payment request (JSON)

=item * GET /swish/payments/:id - Get payment status (JSON)

=item * POST /swish/refunds/create - Create refund request (JSON)

=back

=head2 Manager Routes

=over 4

=item * GET /manager/swish - Swish payments panel

=back

=head1 HELPERS

=head2 swish

Returns the L<Samizdat::Model::Swish> instance.

  my $swish = $c->swish;
  my $payment = $swish->create_payment(amount => 10000);

=head2 swishbutton

Generates an HTML container for the Swish payment button.

  my $button_html = $c->swishbutton(
    amount => 10000,
    message => 'Order #123',
  );

=head2 swishbutton_script

Returns JavaScript code for initializing the Swish payment button.

  $web->{script} = $c->swishbutton_script();

=head2 swish_qr_url

Generate a Swish app URL from a payment token.

  my $url = $c->swish_qr_url($token);

=head1 CONFIGURATION

Configure in samizdat.yml under manager.swish:

  swish:
    cardnumber: 18
    dbtype: postgresql
    currency: SEK
    default_env: test
    payee_alias: '1231181189'
    cert:
      client_cert: /path/to/swish_client.pem
      client_key: /path/to/swish_client.key
      ca_cert: /path/to/swish_ca.pem
    env:
      test:
        api: https://mss.cpc.getswish.net/swish-cpcapi/api/v2
      production:
        api: https://cpc.getswish.net/swish-cpcapi/api/v2

=head1 PAYMENT FLOWS

=head2 E-commerce

1. User enters phone number
2. POST to /swish/payments/create with payer_alias
3. Swish sends push notification to user's phone
4. User opens Swish app and confirms payment
5. Swish sends callback to /swish/callback
6. Payment status updated

=head2 M-commerce

1. POST to /swish/payments/create without payer_alias
2. Response includes payment_request_token
3. Display QR code or redirect to Swish app
4. User scans QR or opens app link
5. User confirms payment in Swish app
6. Swish sends callback to /swish/callback
7. Payment status updated

=head1 SEE ALSO

L<Samizdat::Model::Swish>, L<Samizdat::Controller::Swish>

Swish Developer Documentation: L<https://developer.swish.nu/>

=cut
