package Samizdat::Plugin::Fortnox;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Fortnox;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # Invoice stuff
  my $manager = $r->manager('fortnox')->to(controller => 'Fortnox');
  $manager->any('customers')                ->to('#customers')             ->name('fortnox_customer');
  $manager->any('customers/:customerid')    ->to('#customers');
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

  # Helper for accessing the Fortnox API model.
  $app->helper(fortnox => sub {
    state $fortnox = Samizdat::Model::Fortnox->new({
      config      => $app->config->{manager}->{fortnox},
    });
    return $fortnox;
  });
}

1;