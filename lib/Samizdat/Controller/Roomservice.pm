package Samizdat::Controller::Roomservice;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $title = $self->app->__('Roomservice');
  my $web = { title => $title, docpath => sprintf('%sindex.html', $self->config->{managerurl}) };
  $self->render(template => 'roomservice/index', web => $web, title => $title);
}

1;

