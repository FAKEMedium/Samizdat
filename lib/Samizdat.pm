package Samizdat;
use Mojo::Base 'Mojolicious', -signatures;

sub startup ($self) {

  my $config = $self->plugin('NotYAMLConfig');

  $self->secrets($config->{secrets});

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('#index');
}

1;
