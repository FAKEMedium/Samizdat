package Samizdat::Controller::Markdown;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub geturi ($self) {
  my $docpath = $self->stash('docpath');
  my $html = $self->app->__x("The page {docpath} wasn't found.", docpath => '/' . $docpath);
  my $title = $self->app->__('404: Missing document');

  my $docs = $self->app->markdown->list($docpath, {
    language => $self->app->language,
    languages => $self->app->{config}->{locale}->{languages},
  });
  my $path = sprintf("%s%s", $docpath, 'index.html');
  $self->stash(template => 'index');

  if (!exists($docs->{$path})) {
    $path = '404.html';
    $self->stash('status', 404);
    $docs->{'404.html'} = {
      url         => $docpath,
      docpath     => '404.html',
      title       => $title,
      main        => $html,
      children    => [],
      subdocs     => [],
      description => undef,
      keywords    => [],
    };
  } else {
    if ($#{$docs->{$path}->{subdocs}} > -1) {
      my $sidebar = '';
      for my $subdoc (@{$docs->{$path}->{subdocs}}) {
        $sidebar .= $self->render_to_string(template => 'chunks/sidecard', card => $subdoc);
      }
      $docs->{$path}->{sidebar} = $sidebar;
      $self->stash(template => 'twocolumn');
    }
  }
  $self->stash(web => $docs->{$path});
  $self->stash(title => $docs->{$path}->{title} // $title);
  $self->render();
}

1;
