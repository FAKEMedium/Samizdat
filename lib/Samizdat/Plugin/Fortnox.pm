package Samizdat::Plugin::Fortnox;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Fortnox;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

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


  # Helper for accessing the Fortnox API model.
  $app->helper(fortnox => sub ($c = undef) {
    # Determine if we're in a CLI context (no controller)
    my $is_cli = !defined($c) || !ref($c) || ref($c) eq 'Mojolicious';

    if ($is_cli) {
      # CLI context: create instance without session (uses unencrypted fallback)
      state $cli_fortnox = Samizdat::Model::Fortnox->new({
        config => $app->config->{manager}->{fortnox},
        redis  => $app->redis,
      });
      return $cli_fortnox;
    } else {
      # Web context: use session-based encryption
      state $fortnox = Samizdat::Model::Fortnox->new({
        config => $app->config->{manager}->{fortnox},
        redis  => $c->redis,
      });

      # Update session reference on each request (for encryption key)
      $fortnox->session($c->session);

      return $fortnox;
    }
  });
}

1;