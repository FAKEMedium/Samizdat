package Samizdat::Plugin::Domain;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Domain;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  my $manager = $r->under($app->config->{managerurl})->to(
    controller => 'Account',
    action     => 'authorize',
    require    => {
      users => $app->config->{account}->{admins}
    }
  );

  $manager->get('customers/:customerid/domains/open')->to('Domain#edit');
  $manager->put('customers/:customerid/domains/open')->to('Domain#update');
  $manager->post('customers/:customerid/domains/open')->to('Domain#create');
  $manager->get('customers/:customerid/domains/:domainid')->to('Domain#get');
  $manager->get('customers/:customerid/domains')->to('Domain#index');
  $manager->get('domains')->to('Domain#index');

  $app->helper(domain => sub ($self) {
    state $domain = Samizdat::Model::Domain->new({
      config => $self->config->{roomservice}->{domain},
      pg     => $self->pg,
      mysql  => $self->mysql,
    });
    return $domain;
  });
}

1;