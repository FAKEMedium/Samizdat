package Samizdat::Controller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub welcome ($self) {

  $self->render(msg => 'Some content');
}

1;
