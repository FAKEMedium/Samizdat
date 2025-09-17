package Samizdat::Plugin::Domain;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Domain;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('domain')->to(controller => 'Domain');
  $manager->get('/')                                           ->to('#index')                    ->name('domain_index');

  my $customers = $r->manager('customers/:customerid/domainss')->to(controller => 'Domain');
  $customers->get('open')                                      ->to('#edit');
  $customers->put('open')                                      ->to('#update');
  $customers->post('open')                                     ->to('#create');
  $customers->get('/:domainid')                                ->to('#get');
  $customers->get('Y')                                         ->to('#index');

  $app->helper(domain => sub ($self) {
    state $domain = Samizdat::Model::Domain->new({
      config => $self->config->{manager}->{domain},
      pg     => $self->pg,
      mysql  => $self->mysql,
    });
    return $domain;
  });
}

1;