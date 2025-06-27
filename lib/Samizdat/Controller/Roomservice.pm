package Samizdat::Controller::Roomservice;

use Mojo::Base 'Mojolicious::Controller', -signatures;

sub index ($self) {
  my $title = $self->app->__('Roomservice');
  my $web = { title => $title };

  my $accept = $self->req->headers->{headers}->{accept}->[0];
  if ($accept !~ /json/) {
    $web->{script} .= $self->render_to_string(format => 'js', template => 'roomservice/index');
    $self->render(web => $web, title => $title, template => 'roomservice/index');
  }
}

1;

