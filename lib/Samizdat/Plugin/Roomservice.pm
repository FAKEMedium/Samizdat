package Samizdat::Plugin::Roomservice;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Invoice;
use Samizdat::Model::Customer;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  my $manager = $r->under($app->config->{managerurl});
=pod
  my $manager = $r->under($app->config->{managerurl})->to(
    controller => 'Account',
    action     => 'authorize',
    require    => {
      users => $app->config->{account}->{admins}
    }
  );
=cut
  $manager->any('/')->to('Roomservice#index');
}

1;