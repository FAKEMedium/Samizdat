use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Samizdat');

# Test that the app has PayPal configuration
ok($t->app->config->{manager}->{paypal}, 'PayPal configuration exists');

# Test that the PayPal helper is available
ok($t->app->can('paypal'), 'paypal helper is registered');
my $paypal = eval { $t->app->build_controller->paypal };
ok($paypal, 'paypal helper returns an object');

# Test that the model has required methods (legacy and REST API)
can_ok($paypal, qw(button verify_ipn process_ipn store_ipn_event get_transaction get_env_config get_access_token create_order capture_order get_order));

# Test paypalbutton helpers
ok($t->app->can('paypalbutton'), 'paypalbutton helper is registered');
ok($t->app->can('paypalbutton_script'), 'paypalbutton_script helper is registered');

# Test PayPal routes are accessible
$t->get_ok('/paypal/success')->status_is(200);
$t->get_ok('/paypal/cancel')->status_is(200);

# Test that success page fetches JSON data
$t->get_ok('/paypal/success' => {Accept => 'application/json'})
  ->status_is(200)
  ->json_has('/success');

# Test that cancel page fetches JSON data
$t->get_ok('/paypal/cancel' => {Accept => 'application/json'})
  ->status_is(200)
  ->json_has('/cancelled');

# Test REST API routes
$t->get_ok('/paypal/config')
  ->status_is(200)
  ->json_has('/client_id')
  ->json_has('/currency')
  ->json_has('/env');

# Test create order endpoint (will fail without valid credentials, but route should exist)
$t->post_ok('/paypal/orders/create' => json => {amount => 10.00, description => 'Test'})
  ->status_is([200, 500]);  # May fail with 500 if credentials not configured

done_testing();

__END__

# Integration tests (disabled by default, run manually)
# These tests would require actual PayPal sandbox credentials and mock IPN requests

# Test IPN endpoint
# $t->post_ok('/paypal/ipn' => form => {
#   payment_status => 'Completed',
#   txn_id => 'TEST123',
#   receiver_email => 'test@example.com',
#   mc_gross => '99.00',
#   mc_currency => 'USD',
# })->status_is(200);
