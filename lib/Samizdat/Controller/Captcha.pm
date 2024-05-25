package Samizdat::Controller::Captcha;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  $self->render( data => $self->create_captcha, format => 'png' );
}

1;