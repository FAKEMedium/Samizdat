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
  $manager->any(sprintf('%s', '/customers'))
    ->to(controller => 'Fortnox', action => 'customer')
    ->name('fortnox_customer');
  $manager->any(sprintf('%s', '/customers/:customerid'))
    ->to(controller => 'Fortnox', action => 'customer', template => 'fortnox/manager/customer');
  $manager->post(sprintf('%s', '/invoices'))
    ->to(controller => 'Fortnox', action => 'postinvoice');
  $manager->get(sprintf('%s', '/invoices'))
    ->to(controller => 'Fortnox', action => 'listinvoices', template => 'fortnox/manager/getinvoices')
    ->name('fortnox_invoices');
  $manager->any(sprintf('%s', '/logout'))
    ->to(controller => 'Fortnox', action => 'logout')
    ->name('fortnox_logout');
  $manager->any(sprintf('%s', '/'))
    ->to(controller => 'Fortnox', action => 'manager')->name('fortnox_manager');


  # Integration stuff
  $fortnox->any(sprintf('%s', '/auth'))
    ->to(controller => 'Fortnox', action => 'auth')
    ->name('fortnox_auth');
  $fortnox->any(sprintf('%s', '/start'))
    ->to(controller => 'Fortnox', action => 'start', docpath => '/fortnox/index/start.html')
    ->name('fortnox_start');
  $fortnox->any(sprintf('%s', '/activate'))
    ->to(controller => 'Fortnox', action => 'activate', docpath => '/fortnox/index/activate.html')
    ->name('fortnox_activate');
  $fortnox->any(sprintf('%s', '/'))
    ->to(controller => 'Fortnox', action => 'index', docpath => '/fortnox/index.html')
    ->name('fortnox_index');


  $app->helper(fortnox => sub {
    state $fortnox = Samizdat::Model::Fortnox->new({
      config      => $app->config->{roomservice}->{fortnox},
      application => $app->config->{roomservice}->{fortnox}->{selectedapp},
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