package Samizdat::Plugin::Fortnox;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Fortnox;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Configure Fortnox session cookie
  $app->sessions->cookie_name('fortnox');
  $app->sessions->cookie_path('/');
  $app->sessions->default_expiration(7200);  # 2 hours

  # Invoice stuff
  my $manager = $r->manager('fortnox')->to(controller => 'Fortnox');
  $manager->any('customers/:customerid')    ->to('#customers');
  $manager->any('customers')                ->to('#customers')             ->name('fortnox_customer');
  $manager->post('invoices')                ->to('#postinvoice');
  $manager->get('invoices')                 ->to('#invoices')             ->name('fortnox_invoices');
  $manager->get('payments/:number')         ->to('#payments');
  $manager->get('payments')                 ->to('#payments')             ->name('fortnox_payments');
  $manager->any('/')                        ->to('#manager')              ->name('fortnox_manager');

  # Integration stuff
  my $fortnox = $r->home('fortnox')->to(controller => 'Fortnox');
  $fortnox->any('auth')                     ->to('#auth')                 ->name('fortnox_auth');
  $fortnox->any('logout')                   ->to('#logout')               ->name('fortnox_logout');
  $fortnox->any('start')                    ->to('#start')                ->name('fortnox_start');
  $fortnox->any('activate')                 ->to('#activate')             ->name('fortnox_activate');
  $fortnox->any('/')                        ->to('#index')                ->name('fortnox_index');

  # Helper for accessing the Fortnox API model
  $app->helper(fortnox => sub ($c) {
    state $model = Samizdat::Model::Fortnox->new({
      config => $app->config->{manager}->{fortnox},
      cache  => $c->cache,
    });

    return $model;
  });
}

1;