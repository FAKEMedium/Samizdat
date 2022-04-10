package Samizdat::Controller::Markdown;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub geturi ($self) {
  my $docpath = $self->stash('docpath');
  my $web = {};
  $self->stash(web => $web);
  $web->{main} = $docpath;
  $self->render();
}

1;
