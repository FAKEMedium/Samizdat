package Samizdat::Plugin::Email;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Email;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->manager('email')->to(controller => 'Email');
  $manager->get('/')->to('#index')->name('email_index');

  my $customers = $r->manager('customers/:customerid/email')->to(controller => 'Email');
  $customers->get('/')->to('#index');


  $app->helper(email => sub ($self) {
    state $email = Samizdat::Model::Email->new({
      config => $self->config->{manager}->{email},
      pg     => $self->pg,
      mysql  => $self->mysql,
    });
    return $email;
  });
}

1;