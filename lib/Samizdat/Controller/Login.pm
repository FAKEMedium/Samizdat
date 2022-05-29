package Samizdat::Controller::Login;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $username = $self->param('username') || '';
  my $password = $self->param('password') || '';
  return $self->render unless $self->account->check($username, $password);

  $self->session(username => $username);
  $self->redirect_to('panel');
}


sub logout ($self) {
  $self->session(expires => 1);
  $self->redirect_to('index');
}

1;