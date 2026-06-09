package Samizdat::Controller::Icons;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::Home;
use Data::Dumper;

sub icons ($self) {
  my $icons = [];
  $self->app->sharedir('icons', 'icons')->list->each( sub {
    my $icon = shift;
    push @{ $icons }, $icon->basename('.svg') if ($icon =~ /\.svg$/);
  });

  my $accept = $self->req->headers->accept // '';
  if ($accept =~ /json/) {
    return $self->render(json => { icons => $icons }, status => 200);
  }

  $self->stash(icons => $icons);
  $self->stash(docpath => 'project/icons/index.html');
  my $web = {};
  $self->stash('status', 200);
  my $title = $self->app->__('Bootstrap icons helper');
  $self->stash(title => $title);
  $self->render(web => $web, template => 'project/icons');
}

1;