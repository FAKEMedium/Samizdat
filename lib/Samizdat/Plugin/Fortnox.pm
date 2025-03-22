package Samizdat::Plugin::Fortnox;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Fortnox;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  my $manager = $r->under($app->config->{managerurl})->to(
    controller => 'Account',
    action     => 'authorize',
    require    => {
      users => $app->config->{account}->{admins}
    }
  );

  $manager->any(sprintf('%s', 'fortnox/auth'))->to('Fortnox#auth')->name('fortnox_auth');
  $manager->any(sprintf('%s', 'fortnox/customers'))->to('Fortnox#customer')->name('fortnox_customer');
  $manager->any(sprintf('%s', 'fortnox/customers/:customerid'))->to('Fortnox#customer');
  $manager->post(sprintf('%s', 'fortnox/invoices'))->to('Fortnox#postinvoice');
  $manager->get(sprintf('%s', 'fortnox/invoices'))->to('Fortnox#listinvoices')->name('fortnox_invoices');
  $manager->any(sprintf('%s', 'fortnox/logout'))->to('Fortnox#logout')->name('fortnox_logout');
  $manager->any(sprintf('%s', 'fortnox'))->to('Fortnox#index')->name('fortnox_index');

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