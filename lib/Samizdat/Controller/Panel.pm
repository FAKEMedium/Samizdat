package Samizdat::Controller::Panel;

use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::JSON qw(j);
use Mojo::Util qw(b64_encode);
use Data::Dumper;

sub index ($self) {
  $self->stash(template => 'index');
  $self->stash('status', 200);
  my $title = $self->app->__('Personal panel');
  my $web = {
      url         => 'panel',
      docpath     => 'panel',
      title       => $title,
      main        => '',
      children    => [],
      subdocs     => [],
      description => undef,
      keywords    => [],
      language    => $self->app->language,
    };

  $self->stash(web => $web);
  $self->stash(title => $title);
  $self->render();
}


1;