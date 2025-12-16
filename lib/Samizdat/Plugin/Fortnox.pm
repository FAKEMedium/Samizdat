package Samizdat::Plugin::Fortnox;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Cache;
use Samizdat::Model::Fortnox;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  # For service accounts, use a dedicated Fortnox session cookie
  my $fortnox_config = $app->config->{manager}->{fortnox} // {};
  my $is_service = ($fortnox_config->{account_type} // '') eq 'service';
  if ($is_service) {
    $app->sessions->cookie_name('fortnox');
    $app->sessions->cookie_path('/');
    $app->sessions->default_expiration(7200);  # 2 hours
  }

  # Invoice stuff
  my $manager = $r->manager('fortnox')->to(controller => 'Fortnox');
  $manager->any('customers/:customerid')    ->to('#customers');
  $manager->any('customers')                ->to('#customers')             ->name('fortnox_customer');
  $manager->get('invoices/:invoiceid/:to')  ->to('#invoicenav')            ->name('fortnox_invoice_nav');
  $manager->get('invoices/:invoiceid')      ->to('#invoices');
  $manager->post('invoices')                ->to('#postinvoice');
  $manager->get('invoices')                 ->to('#invoices')             ->name('fortnox_invoices');
  $manager->get('payments/:number')         ->to('#payments');
  $manager->get('payments')                 ->to('#payments')             ->name('fortnox_payments');
  $manager->any('/')                        ->to('#manager')              ->name('fortnox_manager');

  # Integration stuff (for Fortnox marketplace etc.)
  my $fortnox = $r->home('fortnox')->to(controller => 'Fortnox');
  $fortnox->any('auth')                     ->to('#auth')                 ->name('fortnox_auth');
  $fortnox->any('logout')                   ->to('#logout')               ->name('fortnox_logout');
  $fortnox->any('start')                    ->to('#start')                ->name('fortnox_start');
  $fortnox->any('activate')                 ->to('#activate')             ->name('fortnox_activate');
  $fortnox->any('/')                        ->to('#index')                ->name('fortnox_index');

  # Helper for accessing the Fortnox API model
  # Always use global cache - OAuth tokens are app-level credentials
  my $global_cache;
  $app->helper(fortnox => sub ($c) {
    $global_cache //= Samizdat::Model::Cache->new({
      redis  => $c->redis,
      config => $app->config->{manager}->{cache},
      # No session = global cache key (fortnox:cache, not fortnox:cache:session:xxx)
    });
    state $model = Samizdat::Model::Fortnox->new({
      config => $fortnox_config,
      cache  => $global_cache,
    });
    return $model;
  });
}

1;