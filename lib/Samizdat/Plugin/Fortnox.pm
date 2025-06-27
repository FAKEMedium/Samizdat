package Samizdat::Plugin::Fortnox;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Fortnox;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $fortnox = $r->under('/fortnox');
  my $manager = $fortnox->under('/manager')->to(
    controller => 'Account',
    action     => 'authorize',
    level      => 'admin',
  );


  # Invoice stuff
  if (1) {
    $manager->any(sprintf('%s', '/customers'))->name('fortnox_customer')->to(
      controller => 'Fortnox',
      action => 'customers',
      docpath => '/fortnox/manager/customers/index.html',
    );
    $manager->any(sprintf('%s', '/customers/:customerid'))->to(
      controller => 'Fortnox',
      action => 'customers',
      docpath => '/fortnox/manager/customers/single/index.html',
    );
    $manager->post(sprintf('%s', '/invoices'))->to(
      controller => 'Fortnox',
      action => 'postinvoice',
    );
    $manager->get(sprintf('%s', '/invoices'))->name('fortnox_invoices')->to(
      controller => 'Fortnox',
      action => 'invoices',
      docpath => '/fortnox/manager/invoices/index.html',
    );
    $manager->get(sprintf('%s', '/payments'))->name('fortnox_payments')->to(
      controller => 'Fortnox',
      action => 'payments',
      docpath => '/fortnox/manager/payments/index.html',
    );
    $manager->get(sprintf('%s', '/payments/:number'))->to(
      controller => 'Fortnox',
      action => 'payments',
      docpath => '/fortnox/manager/payments/single/index.html',
    );
    $manager->any(sprintf('%s', '/'))->name('fortnox_manager')->to(
      controller => 'Fortnox',
      action => 'manager',
      docpath => '/fortnox/manager/index.html',
    );
  }

  # Integration stuff
  $fortnox->any(sprintf('%s', '/auth'))->name('fortnox_auth')->to(
    controller => 'Fortnox',
    action => 'auth',
  );
  $fortnox->any(sprintf('%s', '/logout'))->name('fortnox_logout')->to(
    controller => 'Fortnox',
    action => 'logout',
  );
  $fortnox->any(sprintf('%s', '/start'))->name('fortnox_start')->to(
    controller => 'Fortnox',
    action => 'start',
    docpath => '/fortnox/start/index.html'
  );
  $fortnox->any(sprintf('%s', '/activate'))->name('fortnox_activate')->to(
    controller => 'Fortnox',
    action => 'activate',
    docpath => '/fortnox/activate/index.html',
  );
  $fortnox->any(sprintf('%s', '/'))->name('fortnox_index')->to(
    controller => 'Fortnox',
    action => 'index',
    docpath => '/fortnox/index.html',
  );


  $app->helper(fortnox => sub {
    state $fortnox = Samizdat::Model::Fortnox->new({
      config      => $app->config->{roomservice}->{fortnox},
    });
    return $fortnox;
  });

  $app->helper(
    metaInfo => sub($self, $metainfo, $title = '') {
      $self->render_to_string('chunks/metainfo', metainfo => $metainfo, title => $title);
    }
  );

}


1;