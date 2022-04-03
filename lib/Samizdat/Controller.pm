package Samizdat::Controller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {

  $self->render(msg => 'Some content');
}

1;
