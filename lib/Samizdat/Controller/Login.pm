package Samizdat::Controller::Login;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $username = $self->param('username') || '';
  my $password = $self->param('password') || '';
  return $self->render unless $self->user->check($username, $password);

  $self->session(username => $username);
  $self->redirect_to('panel');
}

sub logged_in ($self) {
  return 1 if $self->session('user');
  $self->redirect_to('index');
  return undef;
}

sub logout ($self) {
  $self->session(expires => 1);
  $self->redirect_to('index');
}

1;