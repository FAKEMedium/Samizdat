package Samizdat::Controller::Icons;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::Home;
use Data::Dumper;

sub icons ($self) {
  my $icons = [];
  Mojo::Home->new('src/icons/icons/')->list->each( sub {
    my $icon = shift;
    push @{ $icons }, $icon->basename('.svg') if ($icon =~ /\.svg$/);
  });
  $self->stash(icons => $icons);
  my $web = {
    docpath => 'project/icons/index.html'
  };
  $self->stash('status', 200);
  my $title = $self->app->__('Bootstrap icons helper');
  $self->stash(title => $title);
  $self->render(web => $web, template => 'project/icons');
}

1;