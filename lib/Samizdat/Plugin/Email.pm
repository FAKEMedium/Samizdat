package Samizdat::Plugin::Email;

use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Samizdat::Model::Email;

sub register ($self, $app, $conf) {
  my $r = $app->routes;
  my $manager = $r->under($app->config->{managerurl})->to(
    controller => 'Account',
    action     => 'authorize',
    require    => {
      users => $app->config->{account}->{admins}
    }
  );

  $manager->get('email')->to('Email#index')->name('email_index');

  $app->helper(email => sub ($self) {
    state $email = Samizdat::Model::Email->new({
      config => $self->config->{roomservice}->{email},
      pg     => $self->pg,
      mysql  => $self->mysql,
    });
    return $email;
  });
}

1;